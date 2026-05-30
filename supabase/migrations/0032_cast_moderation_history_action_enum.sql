-- =============================================================================
-- 0032  Cast moderation_history.action to the enum type
-- -----------------------------------------------------------------------------
-- The moderation guard triggers were writing `case ... end` as plain text into
-- `moderation_history.action`, whose column type is public.moderation_action.
-- PostgreSQL does not auto-cast that expression in this context, so the admin
-- dashboard still failed when changing a place's status.
--
-- This migration keeps the existing moderation behavior, but casts the action
-- expression explicitly to the enum so inserts succeed for both provider and
-- place moderation history rows.
-- =============================================================================

begin;

create or replace function public.guard_provider_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_mod boolean := public.is_moderator_or_above();
  _is_service boolean := auth.role() = 'service_role'
                      or current_user in ('service_role', 'postgres');
begin
  if not (_is_mod or _is_service) then
    if new.status          is distinct from old.status
       or new.approved_at  is distinct from old.approved_at
       or new.approved_by  is distinct from old.approved_by
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
        ('provider', new.id,
         (case new.status
            when 'approved'     then 'approve'
            when 'rejected'     then 'reject'
            when 'suspended'    then 'suspend'
            when 'pending'      then 'reinstate'
            when 'under_review' then 'start_review'
          end)::public.moderation_action,
         old.status, new.status, auth.uid(), new.rejection_reason);
    end if;
  end if;
  return new;
end;
$$;

create or replace function public.guard_place_moderation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_mod boolean := public.is_moderator_or_above();
  _is_service boolean := auth.role() = 'service_role'
                      or current_user in ('service_role', 'postgres');
begin
  if not (_is_mod or _is_service) then
    if new.status          is distinct from old.status
       or new.approved_at  is distinct from old.approved_at
       or new.approved_by  is distinct from old.approved_by
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
         (case new.status
            when 'approved'     then 'approve'
            when 'rejected'     then 'reject'
            when 'suspended'    then 'suspend'
            when 'pending'      then 'reinstate'
            when 'under_review' then 'start_review'
          end)::public.moderation_action,
         old.status, new.status, auth.uid(), new.rejection_reason);
    end if;
  end if;
  return new;
end;
$$;

commit;
