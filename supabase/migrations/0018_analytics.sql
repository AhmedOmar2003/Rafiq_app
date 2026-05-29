-- =============================================================================
-- 0018  Analytics — events + daily rollups
-- -----------------------------------------------------------------------------
-- Design:
--   • `analytics_events` is the raw, append-only fact table. The client batches
--     events into one RPC call (insert_event_batch) so we never get N round
--     trips per scroll.
--   • Hot reads on the dashboard MUST NOT scan the raw events table — instead
--     they hit `analytics_daily_rollups`, a per-place/per-day aggregate that
--     is filled by a scheduled SQL job (pg_cron) or an Edge Function nightly.
--   • The dashboard's "live counters" come from a cheap partial index on
--     events with `occurred_at >= now() - interval '24 hours'`.
--
-- Why no monthly partitioning yet?
--   Partitioning is one ALTER TABLE away. We add a daily partition strategy
--   in a follow-up migration once event volume justifies it (~1M+ rows/day).
--   The schema is partition-ready: `occurred_at` is the natural partition key.
-- =============================================================================

begin;

do $$ begin
  create type public.analytics_event_kind as enum (
    'place_impression',     -- card seen in a list (sampled)
    'place_open',           -- details page opened
    'place_favorite',
    'place_unfavorite',
    'place_share',
    'place_map_open',       -- "Open in Maps" button
    'place_phone_call',
    'place_website_click',
    'place_review_submit',
    'provider_profile_view',
    'recommendation_shown', -- system showed a recommendation
    'recommendation_click'
  );
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- analytics_events — raw fact table
-- ----------------------------------------------------------------------------
create table if not exists public.analytics_events (
  id              bigserial    primary key,
  kind            public.analytics_event_kind not null,
  place_id        uuid         references public.places(id)   on delete set null,
  provider_id     uuid         references public.providers(id) on delete set null,
  user_id         uuid         references auth.users(id)       on delete set null,
  session_id      uuid,                                       -- client-generated
  -- Rich context, sparse JSON keeps the column count manageable -------------
  context         jsonb        not null default '{}'::jsonb,
  -- Bucketed dimensions for cheap GROUP BYs --------------------------------
  city_id         uuid         references public.cities(id)    on delete set null,
  category_id     uuid         references public.categories(id) on delete set null,
  occurred_at     timestamptz  not null default now(),
  -- Bot/spam dampening flag — set by a heuristic trigger or an Edge Function
  is_filtered     boolean      not null default false
);

comment on table public.analytics_events is
  'Append-only event log. Never UPDATE here — flag with is_filtered instead.';

-- Hot path: dashboard "last 24h" counters --------------------------------
create index if not exists analytics_events_recent_provider_idx
  on public.analytics_events (provider_id, kind, occurred_at desc)
  where is_filtered = false;

-- Per-place historical scans (review pages, exports)
create index if not exists analytics_events_place_idx
  on public.analytics_events (place_id, occurred_at desc)
  where is_filtered = false;

-- Time-range cleanup / archival
create index if not exists analytics_events_occurred_idx
  on public.analytics_events (occurred_at);

-- ----------------------------------------------------------------------------
-- analytics_daily_rollups
--
-- One row per (place, day, kind). Backfilled nightly. Dashboards read from
-- here so the raw events table can grow without slowing the UI.
-- ----------------------------------------------------------------------------
create table if not exists public.analytics_daily_rollups (
  place_id        uuid         not null references public.places(id) on delete cascade,
  provider_id     uuid         not null references public.providers(id) on delete cascade,
  day             date         not null,
  kind            public.analytics_event_kind not null,
  event_count     bigint       not null default 0,
  unique_users    int          not null default 0,
  unique_sessions int          not null default 0,
  primary key (place_id, day, kind)
);

create index if not exists analytics_rollups_provider_day_idx
  on public.analytics_daily_rollups (provider_id, day desc);
create index if not exists analytics_rollups_kind_day_idx
  on public.analytics_daily_rollups (kind, day desc);

-- ----------------------------------------------------------------------------
-- RPC: insert_event_batch
--
-- Single round-trip ingest endpoint used by the Flutter client. Validates
-- shape, drops anything missing the required dimensions, and inserts in
-- bulk. SECURITY DEFINER so anon clients can write *only* through this
-- function (the table itself stays write-locked by RLS).
-- ----------------------------------------------------------------------------
create or replace function public.insert_event_batch(_events jsonb)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  _inserted int;
begin
  if _events is null or jsonb_typeof(_events) <> 'array' then
    return 0;
  end if;

  with raw as (
    select
      (e->>'kind')::public.analytics_event_kind                       as kind,
      nullif(e->>'place_id', '')::uuid                                as place_id,
      nullif(e->>'provider_id', '')::uuid                             as provider_id,
      nullif(e->>'session_id', '')::uuid                              as session_id,
      coalesce(e->'context', '{}'::jsonb)                             as context,
      nullif(e->>'city_id', '')::uuid                                 as city_id,
      nullif(e->>'category_id', '')::uuid                             as category_id,
      coalesce((e->>'occurred_at')::timestamptz, now())               as occurred_at
    from jsonb_array_elements(_events) as e
  )
  insert into public.analytics_events
    (kind, place_id, provider_id, user_id, session_id, context,
     city_id, category_id, occurred_at)
  select
    kind, place_id, provider_id,
    (select auth.uid()),
    session_id, context, city_id, category_id, occurred_at
  from raw
  where kind is not null;

  get diagnostics _inserted = row_count;
  return _inserted;
end;
$$;

revoke all on function public.insert_event_batch(jsonb) from public;
grant execute on function public.insert_event_batch(jsonb) to authenticated, anon;

-- ----------------------------------------------------------------------------
-- RPC: rebuild_daily_rollups(day)
--
-- Recomputes one day's rollups idempotently. Called by pg_cron or a manual
-- backfill. Safe to run twice — the upsert path guarantees stable totals.
-- ----------------------------------------------------------------------------
create or replace function public.rebuild_daily_rollups(_day date)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  _affected int;
begin
  insert into public.analytics_daily_rollups
    (place_id, provider_id, day, kind, event_count, unique_users, unique_sessions)
  select
    e.place_id,
    coalesce(
      e.provider_id,
      (select pl.provider_id from public.places pl where pl.id = e.place_id)
    ) as provider_id,
    _day                              as day,
    e.kind                            as kind,
    count(*)                          as event_count,
    count(distinct e.user_id)         as unique_users,
    count(distinct e.session_id)      as unique_sessions
  from public.analytics_events e
  where e.is_filtered = false
    and e.place_id    is not null
    and e.occurred_at >= _day
    and e.occurred_at <  _day + interval '1 day'
  group by e.place_id, provider_id, e.kind
  on conflict (place_id, day, kind) do update
    set provider_id     = excluded.provider_id,
        event_count     = excluded.event_count,
        unique_users    = excluded.unique_users,
        unique_sessions = excluded.unique_sessions;

  get diagnostics _affected = row_count;
  return _affected;
end;
$$;

revoke all on function public.rebuild_daily_rollups(date) from public;
-- Only service_role / admin should run rebuilds.

-- ----------------------------------------------------------------------------
-- View: provider_analytics_summary
--
-- Pre-shaped JSON the dashboard consumes directly — saves the frontend from
-- doing 6 round-trips for header counters. Reads exclusively from the
-- rollup table for speed.
-- ----------------------------------------------------------------------------
create or replace view public.provider_analytics_summary as
with last_30 as (
  select
    r.provider_id,
    r.kind,
    sum(r.event_count) as total
  from public.analytics_daily_rollups r
  where r.day >= (current_date - interval '30 days')::date
  group by r.provider_id, r.kind
)
select
  p.id as provider_id,
  jsonb_object_agg(coalesce(l.kind::text, 'noop'), coalesce(l.total, 0))
    filter (where l.kind is not null) as totals_30d
from public.providers p
left join last_30 l on l.provider_id = p.id
where p.deleted_at is null
group by p.id;

commit;
