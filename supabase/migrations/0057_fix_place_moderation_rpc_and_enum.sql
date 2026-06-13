-- =============================================================================
-- 0057  Fix place moderation enum logging + restore canonical admin RPC
-- -----------------------------------------------------------------------------
-- Problem
--   * 0035 rewrote guard_place_moderation() and accidentally removed the
--     explicit cast to public.moderation_action.
--   * The admin dashboard still updates places.status directly, so any status
--     change can fail when the trigger inserts moderation_history.action.
--
-- Fix
--   * Restore the enum cast inside guard_place_moderation().
--   * Re-introduce admin_set_place_status() as the canonical moderation RPC.
--     It does NOT disable triggers; it updates the place normally so:
--       - guard_place_moderation() enforces moderator/service-only writes
--       - moderation_history stays authoritative
--   * The RPC is locked to service_role only.
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
    if new.status is distinct from old.status
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
        (
          'place',
          new.id,
          (
            case new.status
              when 'approved' then 'approve'
              when 'rejected' then 'reject'
              when 'suspended' then 'suspend'
              when 'pending' then 'reinstate'
              when 'under_review' then 'start_review'
            end
          )::public.moderation_action,
          old.status,
          new.status,
          auth.uid(),
          new.rejection_reason
        );
    end if;
  end if;

  return new;
end;
$$;

create or replace function public.admin_set_place_status(
  _place_id bigint,
  _status public.moderation_status,
  _rejection_reason text default null,
  _allow_edit boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  _place public.places%rowtype;
  _clean_reason text := nullif(trim(_rejection_reason), '');
begin
  select *
    into _place
  from public.places
  where place_id = _place_id
  for update;

  if _place.id is null then
    raise exception 'place not found (place_id=%)', _place_id;
  end if;

  if _status = 'rejected' and _clean_reason is null then
    raise exception 'rejection reason is required';
  end if;

  update public.places
     set status = _status,
         rejection_reason = case
           when _status = 'rejected' then _clean_reason
           else null
         end,
         edit_allowed = case
           when _status = 'rejected' then coalesce(_allow_edit, false)
           else false
         end,
         edit_request_status = case
           when _status = 'approved' then 'none'
           when _status = 'rejected'
             and coalesce(_place.edit_request_status, 'none') = 'submitted'
             then 'rejected'
           else coalesce(_place.edit_request_status, 'none')
         end,
         edit_request_response = case
           when _status = 'rejected'
             and coalesce(_place.edit_request_status, 'none') = 'submitted'
             then _clean_reason
           when _status = 'approved' then null
           else _place.edit_request_response
         end,
         edit_request_reviewed_at = case
           when _status = 'rejected'
             and coalesce(_place.edit_request_status, 'none') = 'submitted'
             then now()
           when _status = 'approved' then null
           else _place.edit_request_reviewed_at
         end,
         approved_at = case
           when _status = 'approved' then now()
           else _place.approved_at
         end,
         suspended_at = case
           when _status = 'suspended' then now()
           else _place.suspended_at
         end,
         updated_at = now()
   where place_id = _place_id;

  return jsonb_build_object(
    'place_id', _place.place_id,
    'place_uuid', _place.id,
    'old_status', _place.status,
    'new_status', _status,
    'edit_request_status', case
      when _status = 'approved' then 'none'
      when _status = 'rejected'
        and coalesce(_place.edit_request_status, 'none') = 'submitted'
        then 'rejected'
      else coalesce(_place.edit_request_status, 'none')
    end
  );
end;
$$;

revoke all on function public.admin_set_place_status(
  bigint,
  public.moderation_status,
  text,
  boolean
) from public;

grant execute on function public.admin_set_place_status(
  bigint,
  public.moderation_status,
  text,
  boolean
) to service_role;

comment on function public.admin_set_place_status(
  bigint,
  public.moderation_status,
  text,
  boolean
) is
  'Canonical admin moderation RPC for places. Updates status safely, preserves '
  'trigger-based moderation_history, and keeps edit-request flags consistent.';

commit;
