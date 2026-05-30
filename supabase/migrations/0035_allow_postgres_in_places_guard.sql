-- =============================================================================
-- 0035  Allow the postgres function owner through the places guard
-- -----------------------------------------------------------------------------
-- 0034 added sync_appeal_with_place — a SECURITY DEFINER trigger on
-- place_appeals that updates places.status when the admin resolves/rejects
-- an appeal. Inside that function `current_user = postgres` (the function
-- owner), not `service_role`. The places guard from 0030 only lets
-- `service_role` OR moderator-or-above through, so the inner UPDATE blows
-- up with "only moderators can change moderation columns" and the whole
-- appeal-status change rolls back.
--
-- Fix: also accept `current_user = postgres`. postgres is the owner of all
-- our SECURITY DEFINER functions (sync_appeal_with_place, apply_demo_*, etc).
-- Anything reaching this layer with current_user=postgres came through one
-- of our own RPCs/triggers, which already enforce their own auth (the
-- dashboard's service_role check on the appeal table, RLS on the RPC, etc).
-- =============================================================================

begin;

create or replace function public.guard_place_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_mod boolean := public.is_moderator_or_above();
  _is_service boolean := current_user in ('service_role', 'postgres');
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

commit;
