-- =============================================================================
-- 0053  Atomic appeal decisions
-- -----------------------------------------------------------------------------
-- The appeal status and its linked edit-submission decision must commit or
-- roll back together.
-- =============================================================================

begin;

create or replace function public.admin_set_place_appeal_status(
  _appeal_id uuid,
  _status public.appeal_status,
  _note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_admin boolean :=
    current_user in ('service_role', 'postgres')
    or auth.role() = 'service_role'
    or public.is_moderator_or_above();
  _appeal public.place_appeals%rowtype;
begin
  if not _is_admin then
    raise exception 'admin access required';
  end if;

  select *
    into _appeal
  from public.place_appeals a
  where a.id = _appeal_id
  for update;

  if _appeal.id is null then
    raise exception 'appeal not found';
  end if;

  if _appeal.appeal_type = 'place_edit_rejection'
     and _appeal.edit_submission_id is not null then
    if _status = 'resolved' then
      perform public.admin_review_place_edit_submission(
        _appeal.edit_submission_id,
        'approved',
        nullif(trim(_note), '')
      );
    elsif _status = 'rejected' then
      update public.place_edit_submissions
         set status = 'rejected',
             reviewed_at = now(),
             updated_at = now()
       where id = _appeal.edit_submission_id
         and status = 'appealed';
    end if;
  end if;

  update public.place_appeals
     set status = _status,
         reviewed_at = case when _status = 'pending' then null else now() end,
         reviewer_note = nullif(trim(_note), ''),
         reviewer_id = auth.uid(),
         updated_at = now()
   where id = _appeal_id;

  return _appeal_id;
end;
$$;

revoke all on function public.admin_set_place_appeal_status(
  uuid, public.appeal_status, text
) from public;
grant execute on function public.admin_set_place_appeal_status(
  uuid, public.appeal_status, text
) to service_role, authenticated;

commit;
