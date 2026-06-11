-- =============================================================================
-- 0016  Delete-account RPC
-- -----------------------------------------------------------------------------
-- The mobile/dashboard "Delete account" action needs to atomically:
--   1. Cancel any active subscription   (provider_subscriptions row)
--   2. Soft-delete or hard-delete every provider row that belongs to the
--      caller (places, reviews, favourites... all cascade via FKs)
--   3. Delete the public.profiles row
--   4. Delete the auth.users row (account itself)
--
-- Doing this from the client requires service_role, which the client must
-- not have. The standard Supabase pattern is to expose a SECURITY DEFINER
-- function that the client calls with `auth.uid()` as its only input. Owner
-- check inside the function prevents one user from deleting another.
--
-- Compatibility:
--   • All public.* tables we touch already have ON DELETE CASCADE wired to
--     auth.users(id) or providers(id), so the actual data wipe is one
--     `delete from auth.users` call. We still explicitly remove the
--     provider row first so we get a clear audit trail (billing event).
-- =============================================================================

begin;

do $$ begin
  create type public.plan_tier as enum ('free', 'pro', 'max');
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- account_deletions  —  audit ledger
--
-- Every successful call to delete_my_account() appends here. It's the only
-- record left after deletion, so admin can see "yes user X deleted on Y".
-- ----------------------------------------------------------------------------
create table if not exists public.account_deletions (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null,                    -- copy, not FK
  email         extensions.citext,
  had_provider  boolean     not null,
  had_paid_plan boolean     not null,
  tier_at_delete public.plan_tier,
  deleted_at    timestamptz not null default now(),
  reason        text                              -- optional user-supplied
);

create index if not exists account_deletions_user_idx
  on public.account_deletions (user_id);
create index if not exists account_deletions_when_idx
  on public.account_deletions (deleted_at desc);

alter table public.account_deletions enable row level security;

-- Only admins can read the ledger.
drop policy if exists account_deletions_admin_read on public.account_deletions;
create policy account_deletions_admin_read
  on public.account_deletions
  for select
  using (public.is_admin());

-- No client-side inserts; only the SECURITY DEFINER function below writes.

-- ----------------------------------------------------------------------------
-- delete_my_account(reason)
--
-- Returns a small JSON describing what was removed, then deletes the user.
-- The caller's session becomes invalid immediately after this returns; the
-- client should call supabase.auth.signOut() right after.
-- ----------------------------------------------------------------------------
create or replace function public.delete_my_account(_reason text default null)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid          uuid := auth.uid();
  _email        extensions.citext;
  _provider     public.providers%rowtype;
  _had_provider boolean := false;
  _had_paid     boolean := false;
  _tier         public.plan_tier;
begin
  if _uid is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- Snapshot state BEFORE we cascade so the audit row is meaningful.
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

    -- Mark any active subscription as canceled. We keep the row for
    -- accounting, but the deletion of providers below would cascade
    -- regardless — this just makes the state transition explicit.
    update public.provider_subscriptions
       set status       = 'canceled',
           canceled_at  = now()
     where provider_id = _provider.id
       and status in ('trialing', 'active', 'past_due');

    -- Cascades to places, place_images, provider_documents,
    -- provider_requests, promotional_campaigns, etc.
    delete from public.providers where id = _provider.id;
  end if;

  -- Append the ledger entry (no FK back to auth.users — it survives delete).
  insert into public.account_deletions
    (user_id, email, had_provider, had_paid_plan, tier_at_delete, reason)
  values
    (_uid, _email, _had_provider, _had_paid, _tier, _reason);

  -- Wipe the profile row + auth user. profiles has ON DELETE CASCADE on
  -- auth.users(id), so the explicit delete on auth.users covers both.
  delete from auth.users where id = _uid;

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
  'Atomically deletes the caller''s account: cancels active subscription, '
  'removes provider + cascaded data, removes auth.users row, appends an '
  'audit entry to account_deletions.';

commit;
