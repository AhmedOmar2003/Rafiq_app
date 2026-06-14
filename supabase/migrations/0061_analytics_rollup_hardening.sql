-- =============================================================================
-- 0061  Analytics rollup hardening for provider/admin reads
-- -----------------------------------------------------------------------------
-- Goals:
--   • Keep raw analytics events as the source of truth.
--   • Stop provider analytics from scanning raw event history for whole ranges.
--   • Add campaign metric daily rollups so click summaries stop scanning the
--     full campaign_metric_events table.
--   • Preserve near-real-time provider analytics by reading today's tail from
--     raw events and historical days from rollups.
-- =============================================================================

begin;

create table if not exists public.campaign_metric_daily_rollups (
  campaign_id  uuid not null references public.promotional_campaigns(id) on delete cascade,
  place_id     uuid references public.places(id) on delete set null,
  provider_id  uuid references public.providers(id) on delete set null,
  day          date not null,
  metric       text not null check (metric in ('impression', 'click')),
  event_count  bigint not null default 0,
  primary key (campaign_id, day, metric)
);

create index if not exists campaign_metric_rollups_provider_day_idx
  on public.campaign_metric_daily_rollups (provider_id, day desc);

create index if not exists campaign_metric_rollups_place_day_idx
  on public.campaign_metric_daily_rollups (place_id, day desc);

create index if not exists campaign_metric_rollups_metric_day_idx
  on public.campaign_metric_daily_rollups (metric, day desc);

alter table public.campaign_metric_daily_rollups enable row level security;

drop policy if exists campaign_metric_rollups_owner_read
  on public.campaign_metric_daily_rollups;
create policy campaign_metric_rollups_owner_read
  on public.campaign_metric_daily_rollups
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.providers p
      where p.id = campaign_metric_daily_rollups.provider_id
        and p.owner_id = auth.uid()
    )
    or public.is_moderator_or_above()
  );

insert into public.campaign_metric_daily_rollups (
  campaign_id,
  place_id,
  provider_id,
  day,
  metric,
  event_count
)
select
  e.campaign_id,
  e.place_id,
  e.provider_id,
  e.occurred_at::date as day,
  e.metric,
  count(*)::bigint as event_count
from public.campaign_metric_events e
group by e.campaign_id, e.place_id, e.provider_id, e.occurred_at::date, e.metric
on conflict (campaign_id, day, metric) do update
  set place_id = excluded.place_id,
      provider_id = excluded.provider_id,
      event_count = excluded.event_count;

create or replace function public.provider_place_analytics_live(
  _place_id uuid default null,
  _days int default 30
)
returns table (
  place_id uuid,
  day date,
  kind public.analytics_event_kind,
  event_count bigint,
  unique_users int,
  unique_sessions int
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _provider_id uuid;
  _safe_days int := greatest(1, least(coalesce(_days, 30), 365));
  _today date := current_date;
  _start_day date := current_date - (_safe_days - 1);
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

  return query
  with historical as (
    select
      r.place_id,
      r.day,
      r.kind,
      r.event_count,
      r.unique_users,
      r.unique_sessions
    from public.analytics_daily_rollups r
    where r.provider_id = _provider_id
      and (_place_id is null or r.place_id = _place_id)
      and r.day >= _start_day
      and r.day < _today
  ),
  live_today as (
    select
      e.place_id,
      e.occurred_at::date as day,
      e.kind,
      count(*)::bigint as event_count,
      count(distinct e.user_id)::int as unique_users,
      count(distinct e.session_id)::int as unique_sessions
    from public.analytics_events e
    where e.is_filtered = false
      and e.place_id is not null
      and coalesce(
        e.provider_id,
        (select pl.provider_id from public.places pl where pl.id = e.place_id)
      ) = _provider_id
      and (_place_id is null or e.place_id = _place_id)
      and e.occurred_at >= _today
    group by e.place_id, e.occurred_at::date, e.kind
  )
  select *
  from historical
  union all
  select *
  from live_today
  order by day desc, kind;
end;
$$;

revoke all on function public.provider_place_analytics_live(uuid, int) from public;
grant execute on function public.provider_place_analytics_live(uuid, int) to authenticated;

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

  select coalesce(sum(r.event_count), 0)
    into _result
  from public.campaign_metric_daily_rollups r
  where r.provider_id = _provider_id
    and r.metric = 'click'
    and (_place_id is null or r.place_id = _place_id)
    and r.day >= current_date - (_safe_days - 1);

  return coalesce(_result, 0);
end;
$$;

revoke all on function public.provider_campaign_clicks_live(uuid, int) from public;
grant execute on function public.provider_campaign_clicks_live(uuid, int) to authenticated;

create or replace function public.record_campaign_metric(
  _campaign_id uuid,
  _metric text,
  _session_id uuid default null
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
  _dedupe_key text;
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

  _dedupe_key := _uid::text || ':' || _campaign_id::text || ':' || coalesce(_session_id::text, 'nosession');

  _accepted := public.consume_rate_limit(
    'campaign:' || _metric,
    _dedupe_key,
    1,
    case
      when _metric = 'impression' then interval '60 minutes'
      else interval '24 hours'
    end
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

  insert into public.campaign_metric_daily_rollups (
    campaign_id,
    place_id,
    provider_id,
    day,
    metric,
    event_count
  ) values (
    _campaign.id,
    _campaign.place_id,
    _campaign.provider_id,
    current_date,
    _metric,
    1
  )
  on conflict (campaign_id, day, metric) do update
    set place_id = excluded.place_id,
        provider_id = excluded.provider_id,
        event_count = public.campaign_metric_daily_rollups.event_count + 1;

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

create or replace function public.record_campaign_metric(
  _campaign_id uuid,
  _metric text
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform public.record_campaign_metric(_campaign_id, _metric, null);
end;
$$;

revoke all on function public.record_campaign_metric(uuid, text) from public;
grant execute on function public.record_campaign_metric(uuid, text) to authenticated;

revoke all on function public.record_campaign_metric(uuid, text, uuid) from public;
grant execute on function public.record_campaign_metric(uuid, text, uuid) to authenticated;

commit;
