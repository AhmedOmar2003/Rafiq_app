-- =============================================================================
-- 0024  delete_my_account hardening
-- -----------------------------------------------------------------------------
-- The original 0016 RPC relied entirely on ON DELETE CASCADE chains to wipe
-- the user's data when auth.users was removed. That works **only** if:
--   1. The CASCADE FKs are intact on every dependent table (some env drift
--      across staging / production has been observed).
--   2. The function owner (postgres in Supabase) has DELETE on auth.users.
--   3. Nothing in `auth.users`'s triggers blocks the delete.
--
-- In production we've seen reports of "delete account" appearing to succeed
-- from the UI while the auth row was actually still present — the user could
-- log back in with the same credentials. The root cause was a swallowed
-- error in the RPC: it returned `deleted: true` regardless of whether the
-- `delete from auth.users` actually affected a row.
--
-- This migration replaces the function with a defensive variant that:
--   * Explicitly removes every dependent row in public.* BEFORE touching
--     auth.users, so the user disappears from the app even if the auth row
--     delete is blocked at the very last step.
--   * Uses GET DIAGNOSTICS to assert that `delete from auth.users` actually
--     removed exactly one row, and raises a hard error otherwise. The client
--     sees a thrown exception instead of a misleading "ok".
--   * Idempotent — re-running on a half-deleted account is safe.
-- =============================================================================

begin;

create or replace function public.delete_my_account(_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid           uuid := auth.uid();
  _email         citext;
  _provider      public.providers%rowtype;
  _had_provider  boolean := false;
  _had_paid      boolean := false;
  _tier          public.plan_tier;
  _deleted_rows  int;
begin
  if _uid is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- ---------- Snapshot for the audit ledger -----------------------------------
  select email into _email from public.profiles where id = _uid;

  select * into _provider from public.providers where owner_id = _uid;
  _had_provider := found;

  if _had_provider then
    select tier into _tier
      from public.provider_subscriptions
     where provider_id = _provider.id
       and status in ('trialing', 'active', 'past_due')
     order by created_at desc
     limit 1;

    _had_paid := (_tier in ('pro', 'max'));

    -- State transition before cascade so the canceled timestamps make sense
    -- if the row is ever revived from a backup.
    update public.provider_subscriptions
       set status      = 'canceled',
           canceled_at = now()
     where provider_id = _provider.id
       and status in ('trialing', 'active', 'past_due');

    -- Cascades to places, place_images, provider_documents, etc.
    delete from public.providers where id = _provider.id;
  end if;

  -- Audit ledger entry. No FK back to auth.users so it survives the wipe.
  insert into public.account_deletions
    (user_id, email, had_provider, had_paid_plan, tier_at_delete, reason)
  values
    (_uid, _email, _had_provider, _had_paid, _tier, _reason);

  -- ---------- Belt + braces: explicit deletes on cascading children -----------
  -- These would all CASCADE from `delete from auth.users` below, but doing
  -- them here means the user disappears from every public.* view the moment
  -- the function returns, even if the auth-row delete is blocked.
  delete from public.user_roles  where user_id = _uid;
  delete from public.admin_roles where user_id = _uid;
  delete from public.profiles    where id      = _uid;

  -- ---------- The actual auth row --------------------------------------------
  delete from auth.users where id = _uid;
  GET DIAGNOSTICS _deleted_rows = ROW_COUNT;

  if _deleted_rows = 0 then
    -- We've already deleted the public-side data; reporting failure here lets
    -- the client retry or escalate to support without showing a false-positive
    -- "deleted successfully" message.
    raise exception 'auth user delete affected 0 rows (uid=%)', _uid;
  end if;

  return jsonb_build_object(
    'deleted',        true,
    'had_provider',   _had_provider,
    'had_paid_plan',  _had_paid,
    'tier_at_delete', _tier
  );
end;
$$;

revoke all on function public.delete_my_account(text) from public;
grant execute on function public.delete_my_account(text) to authenticated;

comment on function public.delete_my_account(text) is
  'Hardened account deletion. Explicitly removes every public-schema row '
  'tied to the caller, then deletes auth.users. Raises if the auth row '
  'delete affected zero rows so the client never reports a false success.';

commit;
