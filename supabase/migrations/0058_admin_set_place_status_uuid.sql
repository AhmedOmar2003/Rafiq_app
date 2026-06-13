-- =============================================================================
-- 0058  Canonical UUID overload for admin_set_place_status
-- -----------------------------------------------------------------------------
-- The authoritative schema keys places by UUID (`places.id`). Some older admin
-- code still passes the legacy numeric `place_id`, but fresh environments may
-- not have that compatibility column at all.
--
-- Add a UUID overload so staging tests, k6, and future dashboard work can use
-- the canonical identifier immediately.
-- =============================================================================

begin;

create or replace function public.admin_set_place_status(
  _place_uuid uuid,
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
  where id = _place_uuid
  for update;

  if _place.id is null then
    raise exception 'place not found (id=%)', _place_uuid;
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
   where id = _place_uuid;

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
  uuid,
  public.moderation_status,
  text,
  boolean
) from public;

grant execute on function public.admin_set_place_status(
  uuid,
  public.moderation_status,
  text,
  boolean
) to service_role;

comment on function public.admin_set_place_status(
  uuid,
  public.moderation_status,
  text,
  boolean
) is
  'Canonical UUID overload for admin place moderation. Prefer this over the '
  'legacy bigint place_id signature in new code.';

commit;
