-- =============================================================================
-- 0030  Relax the places moderation guard to also allow service_role
-- -----------------------------------------------------------------------------
-- Why the previous attempts failed
--   * 0029 wrote a SECURITY DEFINER RPC that tried to bypass the trigger via
--     `set_config('session_replication_role', 'replica', true)`. That
--     setting is restricted to superuser, and Supabase's `postgres` role —
--     which owns the function — does NOT have that privilege at runtime.
--     The migration applied successfully, but every call to the RPC failed
--     with "permission denied to set parameter session_replication_role",
--     which surfaced as a 500 in the dashboard.
--
-- The correct fix
--   * Modify the trigger itself to accept the Next.js admin client as a
--     legitimate moderator. The dashboard hits Postgres via the
--     service_role key, which is itself an admin-issued credential — the
--     proof-of-admin is at the connection layer, before any SQL runs.
--   * After this migration:
--       1. `service_role` (Vercel dashboard) → no auth.uid() needed,
--          trigger lets the write through.
--       2. Any authenticated user with the moderator/admin/super_admin
--          role  →  trigger lets the write through (unchanged behavior).
--       3. Anyone else (provider, regular user, anon) → trigger blocks
--          the write with the original error message (unchanged).
--
-- This also makes the RPC from 0029 unnecessary; we drop it.
-- =============================================================================

begin;

drop function if exists public.admin_set_place_status(bigint, public.moderation_status, text);

create or replace function public.guard_place_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_mod boolean := public.is_moderator_or_above();
  -- The Supabase admin client connects as `service_role`. We treat that as
  -- a legitimate moderator because the service_role key is, by definition,
  -- only held by code we control (the Vercel dashboard).
  _is_service boolean := current_user = 'service_role';
begin
  if not (_is_mod or _is_service) then
    if new.status        is distinct from old.status
       or new.approved_at is distinct from old.approved_at
       or new.approved_by is distinct from old.approved_by
       or new.suspended_at is distinct from old.suspended_at
       or new.rejection_reason is distinct from old.rejection_reason
    then
      raise exception 'only moderators can change moderation columns';
    end if;
  else
    if new.status is distinct from old.status then
      insert into public.moderation_history
        (target_type, target_id, action, from_status, to_status, actor_id, reason)
      values
        ('place', new.id,
         case new.status
           when 'approved'    then 'approve'
           when 'rejected'    then 'reject'
           when 'suspended'   then 'suspend'
           when 'pending'     then 'reinstate'
           when 'under_review' then 'start_review'
         end,
         old.status, new.status, auth.uid(), new.rejection_reason);
    end if;
  end if;
  return new;
end;
$$;

-- Trigger itself stays bound to the function — `create or replace` above is
-- enough; no need to drop/recreate the trigger.

commit;
