-- =============================================================================
-- 0052  Safe published-place edit submissions, comparison and appeals
-- -----------------------------------------------------------------------------
-- An approved place stays public with its current data while proposed edits
-- are reviewed for up to 6 hours. Only an admin approval applies the draft.
-- =============================================================================

begin;

create table if not exists public.place_edit_submissions (
  id                    uuid primary key default gen_random_uuid(),
  place_id              uuid not null references public.places(id) on delete cascade,
  provider_id           uuid not null references public.providers(id) on delete cascade,
  status                text not null default 'pending'
                          check (status in ('pending', 'approved', 'rejected', 'appealed', 'cancelled')),
  previous_data         jsonb not null,
  proposed_data         jsonb not null,
  proposed_image_paths  text[] not null default '{}',
  provider_note         text,
  rejection_reason      text,
  submitted_at          timestamptz not null default now(),
  review_due_at         timestamptz not null default (now() + interval '6 hours'),
  reviewed_at           timestamptz,
  reviewed_by           uuid references auth.users(id) on delete set null,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now()
);

create unique index if not exists place_edit_submissions_open_uidx
  on public.place_edit_submissions (place_id)
  where status in ('pending', 'appealed');

create index if not exists place_edit_submissions_queue_idx
  on public.place_edit_submissions (status, submitted_at desc);

alter table public.place_edit_submissions enable row level security;

drop policy if exists place_edit_submissions_owner_read
  on public.place_edit_submissions;
create policy place_edit_submissions_owner_read
  on public.place_edit_submissions for select
  to authenticated
  using (
    exists (
      select 1
      from public.providers p
      where p.id = place_edit_submissions.provider_id
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists place_edit_submissions_admin_read
  on public.place_edit_submissions;
create policy place_edit_submissions_admin_read
  on public.place_edit_submissions for select
  to authenticated
  using (public.is_moderator_or_above());

alter table public.place_appeals
  add column if not exists appeal_type text not null default 'place_rejection'
    check (appeal_type in ('place_rejection', 'place_edit_rejection')),
  add column if not exists edit_submission_id uuid
    references public.place_edit_submissions(id) on delete set null;

create index if not exists place_appeals_edit_submission_idx
  on public.place_appeals (edit_submission_id)
  where edit_submission_id is not null;

create or replace function public.submit_provider_place_edit(
  _place_id uuid,
  _place_name text,
  _activity_name text,
  _budget text,
  _price_range text,
  _address text,
  _city_name text,
  _description text,
  _rating numeric default null,
  _image_storage_paths text[] default '{}',
  _note text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _provider_id uuid;
  _place public.places%rowtype;
  _path text;
  _submission_id uuid;
begin
  if _uid is null then
    raise exception 'authentication required';
  end if;

  select p.id
    into _provider_id
  from public.providers p
  where p.owner_id = _uid
    and p.deleted_at is null
  limit 1;

  select *
    into _place
  from public.places pl
  where pl.id = _place_id
    and pl.provider_id = _provider_id
    and pl.deleted_at is null
  limit 1;

  if _place.id is null then
    raise exception 'place not found';
  end if;

  if _place.status <> 'approved'
     or not coalesce(_place.edit_allowed, false)
     or coalesce(_place.edit_request_status, 'none') <> 'approved' then
    raise exception 'place editing is not open';
  end if;

  if exists (
    select 1
    from public.place_edit_submissions s
    where s.place_id = _place_id
      and s.status in ('pending', 'appealed')
  ) then
    raise exception 'an edit is already under review';
  end if;

  if coalesce(cardinality(_image_storage_paths), 0) > 10 then
    raise exception 'too many images';
  end if;

  foreach _path in array coalesce(_image_storage_paths, '{}') loop
    if _path !~ ('^' || _provider_id::text || '/' || _place_id::text || '/')
       or not exists (
         select 1
         from storage.objects obj
         where obj.bucket_id = 'place-images'
           and obj.name = _path
       ) then
      raise exception 'invalid place image';
    end if;
  end loop;

  insert into public.place_edit_submissions (
    place_id,
    provider_id,
    previous_data,
    proposed_data,
    proposed_image_paths,
    provider_note
  )
  values (
    _place_id,
    _provider_id,
    jsonb_build_object(
      'place_name', _place.place_name,
      'activity_name', _place.activity_name,
      'budget', _place.budget,
      'price_range', _place.price_range,
      'place_address', _place.place_address,
      'city_name', _place.city_name,
      'description', _place.description,
      'rating', _place.rating,
      'image_path', _place.image_path
    ),
    jsonb_build_object(
      'place_name', trim(_place_name),
      'activity_name', trim(_activity_name),
      'budget', trim(_budget),
      'price_range', coalesce(nullif(trim(_price_range), ''), trim(_budget)),
      'place_address', trim(_address),
      'city_name', trim(_city_name),
      'description', trim(_description),
      'rating', coalesce(_rating, _place.rating),
      'image_path', case
        when cardinality(coalesce(_image_storage_paths, '{}')) > 0
          then 'place-images://' || _image_storage_paths[1]
        else _place.image_path
      end
    ),
    coalesce(_image_storage_paths, '{}'),
    nullif(trim(_note), '')
  )
  returning id into _submission_id;

  update public.places
     set edit_request_status = 'submitted',
         edit_request_response = null,
         edit_submitted_at = now(),
         edit_request_reviewed_at = null,
         edit_allowed = false,
         updated_at = now()
   where id = _place_id;

  return _submission_id;
end;
$$;

revoke all on function public.submit_provider_place_edit(
  uuid, text, text, text, text, text, text, text, numeric, text[], text
) from public;
grant execute on function public.submit_provider_place_edit(
  uuid, text, text, text, text, text, text, text, numeric, text[], text
) to authenticated;

create or replace function public.admin_review_place_edit_submission(
  _submission_id uuid,
  _decision text,
  _reason text default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _is_admin boolean :=
    current_user in ('service_role', 'postgres')
    or public.is_moderator_or_above();
  _submission public.place_edit_submissions%rowtype;
  _proposed jsonb;
  _path text;
  _index int := 0;
begin
  if not _is_admin then
    raise exception 'admin access required';
  end if;

  if _decision not in ('approved', 'rejected') then
    raise exception 'invalid decision';
  end if;

  select *
    into _submission
  from public.place_edit_submissions s
  where s.id = _submission_id
    and s.status in ('pending', 'appealed')
  for update;

  if _submission.id is null then
    raise exception 'edit submission is not available';
  end if;

  _proposed := _submission.proposed_data;

  if _decision = 'approved' then
    update public.places pl
       set place_name = _proposed->>'place_name',
           activity_name = _proposed->>'activity_name',
           budget = _proposed->>'budget',
           price_range = _proposed->>'price_range',
           place_address = _proposed->>'place_address',
           city_name = _proposed->>'city_name',
           description = _proposed->>'description',
           rating = coalesce((_proposed->>'rating')::numeric, pl.rating),
           image_path = coalesce(nullif(_proposed->>'image_path', ''), pl.image_path),
           status = 'approved',
           edit_request_status = 'none',
           edit_request_response = 'تم اعتماد التعديل ونشره.',
           edit_request_reviewed_at = now(),
           edit_allowed = false,
           updated_at = now()
     where pl.id = _submission.place_id;

    if cardinality(_submission.proposed_image_paths) > 0 then
      delete from public.place_images
       where place_id = _submission.place_id;

      foreach _path in array _submission.proposed_image_paths loop
        insert into public.place_images (
          place_id, storage_path, is_cover, alt_text, sort_order
        )
        values (
          _submission.place_id,
          _path,
          _index = 0,
          _proposed->>'place_name',
          _index
        )
        on conflict (storage_path) do update
          set place_id = excluded.place_id,
              is_cover = excluded.is_cover,
              alt_text = excluded.alt_text,
              sort_order = excluded.sort_order;
        _index := _index + 1;
      end loop;
    end if;
  else
    if nullif(trim(_reason), '') is null then
      raise exception 'rejection reason is required';
    end if;

    update public.places
       set edit_request_status = 'rejected',
           edit_request_response = trim(_reason),
           edit_request_reviewed_at = now(),
           edit_allowed = false,
           updated_at = now()
     where id = _submission.place_id;
  end if;

  update public.place_edit_submissions
     set status = _decision,
         rejection_reason = case when _decision = 'rejected' then trim(_reason) else null end,
         reviewed_at = now(),
         reviewed_by = auth.uid(),
         updated_at = now()
   where id = _submission_id;

  return _submission.place_id;
end;
$$;

revoke all on function public.admin_review_place_edit_submission(uuid, text, text)
  from public;
grant execute on function public.admin_review_place_edit_submission(uuid, text, text)
  to service_role, authenticated;

create or replace function public.submit_place_edit_appeal(
  _place_id uuid,
  _contact_name text,
  _contact_phone text,
  _message text
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _email text;
  _provider_id uuid;
  _legacy_place_id bigint;
  _submission_id uuid;
  _appeal_id uuid;
begin
  if _uid is null then
    raise exception 'unauthenticated';
  end if;

  select p.id, pl.place_id
    into _provider_id, _legacy_place_id
  from public.providers p
  join public.places pl on pl.provider_id = p.id
  where p.owner_id = _uid
    and pl.id = _place_id
    and pl.status = 'approved'
    and coalesce(pl.edit_request_status, 'none') = 'rejected'
  limit 1;

  if _provider_id is null then
    raise exception 'rejected edit submission not found';
  end if;

  select s.id
    into _submission_id
  from public.place_edit_submissions s
  where s.place_id = _place_id
    and s.provider_id = _provider_id
    and s.status = 'rejected'
  order by s.submitted_at desc
  limit 1;

  if _submission_id is null then
    raise exception 'rejected edit submission not found';
  end if;

  if exists (
    select 1 from public.place_appeals a
    where a.edit_submission_id = _submission_id
      and a.status in ('pending', 'reviewing')
  ) then
    raise exception 'appeal already submitted';
  end if;

  select email into _email from auth.users where id = _uid;

  insert into public.place_appeals (
    place_id,
    provider_id,
    contact_name,
    contact_phone,
    contact_email,
    message,
    appeal_type,
    edit_submission_id
  )
  values (
    _legacy_place_id,
    _provider_id,
    trim(_contact_name),
    trim(_contact_phone),
    _email,
    trim(_message),
    'place_edit_rejection',
    _submission_id
  )
  returning id into _appeal_id;

  update public.place_edit_submissions
     set status = 'appealed',
         updated_at = now()
   where id = _submission_id;

  return _appeal_id;
end;
$$;

revoke all on function public.submit_place_edit_appeal(uuid, text, text, text)
  from public;
grant execute on function public.submit_place_edit_appeal(uuid, text, text, text)
  to authenticated;

-- A normal place-rejection appeal may change the place moderation state.
-- An edit-rejection appeal must not hide or mutate the already-published place.
create or replace function public.sync_appeal_with_place()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.appeal_type = 'place_edit_rejection' then
    return new;
  end if;

  if new.status is distinct from old.status then
    if new.status = 'resolved' then
      update public.places
         set status = 'approved',
             rejection_reason = null,
             approved_at = now(),
             updated_at = now()
       where place_id = new.place_id;
    elsif new.status = 'reviewing' then
      update public.places
         set status = 'under_review',
             updated_at = now()
       where place_id = new.place_id;
    elsif new.status = 'rejected' then
      update public.places
         set status = 'rejected',
             updated_at = now()
       where place_id = new.place_id;
    end if;
  end if;
  return new;
end;
$$;

comment on table public.place_edit_submissions is
  'Immutable before/after snapshots for approved place edits. Published data stays live until admin approval.';

-- One-time bridge for submissions created by the previous workflow. That
-- workflow overwrote the row before review and did not retain a before
-- snapshot, so we preserve the current payload, flag the limitation for the
-- admin, and restore catalogue visibility instead of leaving the place hidden.
insert into public.place_edit_submissions (
  place_id,
  provider_id,
  previous_data,
  proposed_data,
  provider_note,
  submitted_at,
  review_due_at
)
select
  pl.id,
  pl.provider_id,
  jsonb_build_object(
    'place_name', pl.place_name,
    'activity_name', pl.activity_name,
    'budget', pl.budget,
    'price_range', pl.price_range,
    'place_address', pl.place_address,
    'city_name', pl.city_name,
    'description', pl.description,
    'rating', pl.rating,
    'image_path', pl.image_path,
    'legacy_snapshot_unavailable', true
  ),
  jsonb_build_object(
    'place_name', pl.place_name,
    'activity_name', pl.activity_name,
    'budget', pl.budget,
    'price_range', pl.price_range,
    'place_address', pl.place_address,
    'city_name', pl.city_name,
    'description', pl.description,
    'rating', pl.rating,
    'image_path', pl.image_path,
    'legacy_snapshot_unavailable', true
  ),
  'طلب قديم نُقل للنظام الجديد؛ النظام السابق لم يكن يحتفظ بنسخة ما قبل التعديل.',
  coalesce(pl.edit_submitted_at, now()),
  coalesce(pl.edit_submitted_at, now()) + interval '6 hours'
from public.places pl
where coalesce(pl.edit_request_status, 'none') = 'submitted'
  and not exists (
    select 1 from public.place_edit_submissions s
    where s.place_id = pl.id
      and s.status in ('pending', 'appealed')
  );

update public.places
   set status = 'approved',
       approved_at = coalesce(approved_at, now()),
       updated_at = now()
 where coalesce(edit_request_status, 'none') = 'submitted'
   and status <> 'approved';

commit;
