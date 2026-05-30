-- =============================================================================
-- 0037  Abuse-report submission RPC + RLS for the moderation_reports table
-- -----------------------------------------------------------------------------
-- The moderation_reports table already exists (0008) but had no client-side
-- entry point. This migration:
--   * Adds the submit_abuse_report RPC so any authenticated user can flag
--     a place / review / provider with a reason code + optional details.
--   * RLS lets reporters read their own reports (for "بلاغاتي" UI later)
--     and admins read every report.
--   * resolve_abuse_report RPC for admins to close a report with a note.
-- =============================================================================

begin;

alter table public.moderation_reports enable row level security;

drop policy if exists moderation_reports_owner_read on public.moderation_reports;
create policy moderation_reports_owner_read
  on public.moderation_reports for select
  to authenticated
  using (reporter_id = auth.uid() or public.is_moderator_or_above());

drop policy if exists moderation_reports_admin_write on public.moderation_reports;
create policy moderation_reports_admin_write
  on public.moderation_reports for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

-- Direct INSERT is blocked. All inserts go through the RPC so we control
-- the reason_code whitelist and never end up with unsanitized rows.

-- ----------------------------------------------------------------------------
-- submit_abuse_report
-- ----------------------------------------------------------------------------
create or replace function public.submit_abuse_report(
  _target_type public.report_target,
  _target_id   uuid,
  _reason_code text,
  _details     text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _id  uuid;
begin
  if _uid is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;
  if _reason_code not in
     ('spam','offensive','off_topic','fake','illegal','harassment','other')
  then
    raise exception 'invalid reason_code' using errcode = '22023';
  end if;

  insert into public.moderation_reports
    (reporter_id, target_type, target_id, reason_code, details)
  values
    (_uid, _target_type, _target_id, _reason_code, _details)
  returning id into _id;

  return _id;
end;
$$;

revoke all on function public.submit_abuse_report(public.report_target, uuid, text, text) from public;
grant execute on function public.submit_abuse_report(public.report_target, uuid, text, text) to authenticated;

-- ----------------------------------------------------------------------------
-- resolve_abuse_report — admin-only
-- ----------------------------------------------------------------------------
create or replace function public.resolve_abuse_report(
  _report_id  uuid,
  _new_status public.report_status,
  _note       text default null
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_mod boolean := public.is_moderator_or_above();
  _is_service boolean := current_user in ('service_role', 'postgres');
begin
  if not (_is_mod or _is_service) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  update public.moderation_reports
     set status          = _new_status,
         resolved_by     = auth.uid(),
         resolved_at     = case when _new_status = 'open' then null else now() end,
         resolution_note = _note
   where id = _report_id;
end;
$$;

revoke all on function public.resolve_abuse_report(uuid, public.report_status, text) from public;
grant execute on function public.resolve_abuse_report(uuid, public.report_status, text) to authenticated;
grant execute on function public.resolve_abuse_report(uuid, public.report_status, text) to service_role;

commit;
