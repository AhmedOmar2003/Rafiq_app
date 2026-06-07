-- =============================================================================
-- 0049  Approved-place edit requests and safe provider resubmission
-- -----------------------------------------------------------------------------
-- Providers may edit pending places directly. Approved places stay live and
-- immutable until an admin approves an edit request. Once the provider saves
-- the approved edit, the place returns to moderation and disappears from the
-- public catalogue until it is approved again.
-- =============================================================================

begin;

alter table public.places
  add column if not exists edit_request_status text not null default 'none'
    check (edit_request_status in ('none', 'pending', 'approved', 'rejected', 'submitted')),
  add column if not exists edit_request_note text,
  add column if not exists edit_request_response text,
  add column if not exists edit_request_requested_at timestamptz,
  add column if not exists edit_request_reviewed_at timestamptz,
  add column if not exists edit_submitted_at timestamptz;

create index if not exists places_edit_request_queue_idx
  on public.places (edit_request_status, edit_request_requested_at desc)
  where edit_request_status in ('pending', 'submitted');

comment on column public.places.edit_request_status is
  'Approved-place edit workflow: none, pending admin decision, approved for editing, rejected, or submitted for re-review.';

-- Direct owner updates are intentionally limited to places that are not live.
-- Approved-place changes must go through update_provider_place(), which checks
-- the approved request and atomically sends the listing back to moderation.
drop policy if exists places_update_owner on public.places;
create policy places_update_owner
  on public.places for update
  to authenticated
  using (
    exists (
      select 1
      from public.providers p
      where p.id = places.provider_id
        and p.owner_id = auth.uid()
        and p.deleted_at is null
    )
    and (
      status in ('pending', 'under_review')
      or (status = 'rejected' and edit_allowed)
    )
  )
  with check (
    exists (
      select 1
      from public.providers p
      where p.id = places.provider_id
        and p.owner_id = auth.uid()
        and p.deleted_at is null
    )
  );

create or replace function public.request_place_edit(
  _place_id uuid,
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

  if _provider_id is null then
    raise exception 'provider account not found';
  end if;

  update public.places pl
     set edit_request_status = 'pending',
         edit_request_note = nullif(trim(_note), ''),
         edit_request_response = null,
         edit_request_requested_at = now(),
         edit_request_reviewed_at = null,
         edit_submitted_at = null,
         edit_allowed = false,
         updated_at = now()
   where pl.id = _place_id
     and pl.provider_id = _provider_id
     and pl.deleted_at is null
     and pl.status = 'approved'
     and coalesce(pl.edit_request_status, 'none') <> 'pending'
  returning pl.id into _place_id;

  if _place_id is null then
    raise exception 'place edit request is not available';
  end if;

  return _place_id;
end;
$$;

revoke all on function public.request_place_edit(uuid, text) from public;
grant execute on function public.request_place_edit(uuid, text) to authenticated;

create or replace function public.update_provider_place(
  _place_id uuid,
  _place_name text,
  _activity_name text,
  _budget text,
  _price_range text,
  _address text,
  _city_name text,
  _description text,
  _image_path text default null,
  _rating numeric default null
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
  _next_status public.moderation_status;
  _approved_resubmission boolean := false;
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

  if _place.status in ('pending', 'under_review') then
    _next_status := _place.status;
  elsif _place.status = 'rejected' and coalesce(_place.edit_allowed, false) then
    _next_status := 'pending';
  elsif _place.status = 'approved'
    and coalesce(_place.edit_allowed, false)
    and coalesce(_place.edit_request_status, 'none') = 'approved'
  then
    _next_status := 'pending';
    _approved_resubmission := true;
  else
    raise exception 'place editing is not open';
  end if;

  update public.places pl
     set place_name = trim(_place_name),
         activity_name = trim(_activity_name),
         budget = trim(_budget),
         price_range = coalesce(nullif(trim(_price_range), ''), trim(_budget)),
         place_address = trim(_address),
         city_name = trim(_city_name),
         description = trim(_description),
         image_path = coalesce(nullif(trim(_image_path), ''), pl.image_path),
         rating = coalesce(_rating, pl.rating),
         status = _next_status,
         rejection_reason = case when _next_status = 'pending' then null else pl.rejection_reason end,
         edit_allowed = false,
         edit_request_status = case
           when _approved_resubmission then 'submitted'
           when _place.status = 'rejected' then 'none'
           else pl.edit_request_status
         end,
         edit_request_response = case
           when _approved_resubmission then null
           when _place.status = 'rejected' then null
           else pl.edit_request_response
         end,
         edit_submitted_at = case
           when _approved_resubmission then now()
           else pl.edit_submitted_at
         end,
         updated_at = now()
   where pl.id = _place_id;

  return _place_id;
end;
$$;

revoke all on function public.update_provider_place(
  uuid, text, text, text, text, text, text, text, text, numeric
) from public;
grant execute on function public.update_provider_place(
  uuid, text, text, text, text, text, text, text, text, numeric
) to authenticated;

create or replace function public.provider_campaign_clicks_live(
  _place_id uuid default null,
  _days int default 30
)
returns bigint
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  _provider_id uuid;
  _safe_days int := greatest(1, least(coalesce(_days, 30), 365));
  _result bigint;
begin
  select p.id
    into _provider_id
  from public.providers p
  where p.owner_id = auth.uid()
    and p.deleted_at is null
  limit 1;

  if _provider_id is null then
    raise exception 'provider account not found';
  end if;

  select count(*)
    into _result
  from public.campaign_metric_events e
  where e.provider_id = _provider_id
    and e.metric = 'click'
    and (_place_id is null or e.place_id = _place_id)
    and e.occurred_at >= now() - make_interval(days => _safe_days);

  return coalesce(_result, 0);
end;
$$;

revoke all on function public.provider_campaign_clicks_live(uuid, int) from public;
grant execute on function public.provider_campaign_clicks_live(uuid, int)
  to authenticated;

create or replace function public.browse_ranked_places(
  _city_name text default null,
  _budget text default null,
  _activity_name text default null,
  _limit int default 100
)
returns setof public.places
language sql
stable
security definer
set search_path = ''
as $$
  select pl.*
  from public.places pl
  left join public.provider_current_plan plan
    on plan.provider_id = pl.provider_id
  where pl.status = 'approved'
    and pl.deleted_at is null
    and (_city_name is null or pl.city_name = _city_name)
    and (_budget is null or pl.budget = _budget)
    and (_activity_name is null or pl.activity_name = _activity_name)
  order by
    (
      (
        0.65 * least(1.0, greatest(0.0, coalesce(pl.rating_avg, pl.rating, 0) / 5.0))
        + 0.20 * least(
          1.0,
          ln(1 + greatest(coalesce(pl.rating_count, 0), 0)) / ln(1001.0)
        )
        + 0.15 * exp(
          -greatest(
            0.0,
            extract(epoch from (now() - coalesce(pl.created_at, now()))) / 86400.0
          ) / 60.0
        )
      )
      * (
        1.0
        + least(0.25, greatest(0.0, coalesce(plan.ranking_boost, 1.0) - 1.0) * 0.25)
      )
    ) desc,
    coalesce(pl.rating_avg, pl.rating, 0) desc,
    pl.created_at desc
  limit greatest(1, least(coalesce(_limit, 100), 250));
$$;

comment on function public.browse_ranked_places(text, text, text, int) is
  'Approved public feed ranked primarily by quality and engagement, with a capped plan boost that cannot dominate relevance.';

revoke all on function public.browse_ranked_places(text, text, text, int)
  from public;
grant execute on function public.browse_ranked_places(text, text, text, int)
  to anon, authenticated;

commit;
