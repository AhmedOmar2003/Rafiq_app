-- =============================================================================
-- 0044  Harden analytics ingestion and campaign metrics integrity
-- -----------------------------------------------------------------------------
-- Goals:
--   • Make raw analytics writes authenticated and server-validated.
--   • Deduplicate / throttle the hottest event kinds on the server, not only
--     in the client.
--   • Prevent campaign impression/click inflation by recording a per-user
--     audit event and rate-limiting accepted metrics.
-- =============================================================================

begin;

create table if not exists public.campaign_metric_events (
  id            bigserial primary key,
  campaign_id   uuid not null references public.promotional_campaigns(id) on delete cascade,
  place_id      uuid references public.places(id) on delete set null,
  provider_id   uuid references public.providers(id) on delete set null,
  user_id       uuid references auth.users(id) on delete set null,
  metric        text not null check (metric in ('impression', 'click')),
  occurred_at   timestamptz not null default now()
);

comment on table public.campaign_metric_events is
  'Accepted campaign banner metrics after server-side validation + throttling.';

create index if not exists campaign_metric_events_campaign_idx
  on public.campaign_metric_events (campaign_id, occurred_at desc);

create index if not exists campaign_metric_events_user_metric_idx
  on public.campaign_metric_events (user_id, metric, occurred_at desc);

create or replace function public.insert_event_batch(_events jsonb)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _inserted int := 0;
begin
  if _uid is null then
    return 0;
  end if;

  if _events is null or jsonb_typeof(_events) <> 'array' then
    return 0;
  end if;

  with raw as (
    select
      row_number() over ()                                              as seq,
      (e->>'kind')::public.analytics_event_kind                         as kind,
      nullif(trim(e->>'place_id'), '')::uuid                            as place_id,
      nullif(trim(e->>'provider_id'), '')::uuid                         as requested_provider_id,
      nullif(trim(e->>'session_id'), '')::uuid                          as session_id,
      coalesce(e->'context', '{}'::jsonb)                               as context,
      nullif(trim(e->>'city_id'), '')::uuid                             as city_id,
      nullif(trim(e->>'category_id'), '')::uuid                         as category_id,
      coalesce((e->>'occurred_at')::timestamptz, now())                 as occurred_at
    from jsonb_array_elements(_events) as e
  ),
  hydrated as (
    select
      r.seq,
      r.kind,
      r.place_id,
      r.requested_provider_id,
      r.session_id,
      r.context,
      r.city_id,
      r.category_id,
      r.occurred_at,
      pl.provider_id                                                  as derived_provider_id,
      pl.status                                                       as place_status,
      pl.deleted_at                                                   as place_deleted_at,
      pl.city_id                                                      as derived_city_id,
      pl.category_id                                                  as derived_category_id
    from raw r
    left join public.places pl on pl.id = r.place_id
    where r.kind is not null
  ),
  validated as (
    select
      h.seq,
      h.kind,
      h.place_id,
      coalesce(h.derived_provider_id, h.requested_provider_id)         as provider_id,
      h.session_id,
      h.context,
      coalesce(h.city_id, h.derived_city_id)                           as city_id,
      coalesce(h.category_id, h.derived_category_id)                   as category_id,
      least(h.occurred_at, now())                                      as occurred_at,
      case
        when h.place_id is not null and h.derived_provider_id is null then false
        when h.place_id is not null and h.place_deleted_at is not null then false
        when h.place_id is not null
             and h.kind in (
               'place_impression',
               'place_open',
               'place_favorite',
               'place_unfavorite',
               'place_share',
               'place_map_open',
               'place_phone_call',
               'place_website_click',
               'place_review_submit',
               'recommendation_shown',
               'recommendation_click'
             )
             and h.place_status <> 'approved' then false
        when h.place_id is not null
             and h.requested_provider_id is not null
             and h.requested_provider_id <> h.derived_provider_id then false
        else true
      end as is_valid
    from hydrated h
  ),
  accepted as (
    select *
    from validated v
    where v.is_valid
      and public.consume_rate_limit(
        'analytics:' || v.kind::text,
        coalesce(
          _uid::text || ':' || coalesce(v.place_id::text, 'global') || ':' || coalesce(v.session_id::text, 'nosession'),
          _uid::text
        ),
        case
          when v.kind = 'place_open' then 1
          when v.kind = 'place_map_open' then 2
          when v.kind in ('place_favorite', 'place_unfavorite') then 4
          when v.kind in ('place_share', 'place_phone_call', 'place_website_click') then 4
          when v.kind in ('place_impression', 'recommendation_shown') then 10
          else 6
        end,
        case
          when v.kind = 'place_open' then interval '2 minutes'
          when v.kind = 'place_map_open' then interval '1 minute'
          when v.kind in ('place_favorite', 'place_unfavorite') then interval '1 minute'
          when v.kind in ('place_share', 'place_phone_call', 'place_website_click') then interval '2 minutes'
          when v.kind in ('place_impression', 'recommendation_shown') then interval '5 minutes'
          else interval '2 minutes'
        end
      )
  )
  insert into public.analytics_events (
    kind,
    place_id,
    provider_id,
    user_id,
    session_id,
    context,
    city_id,
    category_id,
    occurred_at
  )
  select
    a.kind,
    a.place_id,
    a.provider_id,
    _uid,
    a.session_id,
    a.context,
    a.city_id,
    a.category_id,
    a.occurred_at
  from accepted a;

  get diagnostics _inserted = row_count;
  return _inserted;
end;
$$;

revoke all on function public.insert_event_batch(jsonb) from public;
grant execute on function public.insert_event_batch(jsonb) to authenticated;

create or replace function public.record_campaign_metric(
  _campaign_id uuid,
  _metric text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _campaign record;
  _accepted boolean := false;
begin
  if _uid is null then
    return;
  end if;

  if _campaign_id is null or _metric not in ('impression', 'click') then
    return;
  end if;

  select
    c.id,
    c.place_id,
    c.provider_id,
    c.starts_at,
    c.ends_at,
    c.status
  into _campaign
  from public.promotional_campaigns c
  where c.id = _campaign_id
    and c.status = 'active'
    and now() between c.starts_at and c.ends_at
  limit 1;

  if _campaign.id is null then
    return;
  end if;

  _accepted := public.consume_rate_limit(
    'campaign:' || _metric,
    _uid::text || ':' || _campaign_id::text,
    case when _metric = 'impression' then 1 else 3 end,
    case when _metric = 'impression' then interval '30 minutes' else interval '5 minutes' end
  );

  if not _accepted then
    return;
  end if;

  insert into public.campaign_metric_events (
    campaign_id,
    place_id,
    provider_id,
    user_id,
    metric
  ) values (
    _campaign.id,
    _campaign.place_id,
    _campaign.provider_id,
    _uid,
    _metric
  );

  if _metric = 'impression' then
    update public.promotional_campaigns
       set impressions = impressions + 1,
           updated_at = now()
     where id = _campaign.id;
  else
    update public.promotional_campaigns
       set clicks = clicks + 1,
           updated_at = now()
     where id = _campaign.id;
  end if;
end;
$$;

revoke all on function public.record_campaign_metric(uuid, text) from public;
grant execute on function public.record_campaign_metric(uuid, text) to authenticated;

commit;
