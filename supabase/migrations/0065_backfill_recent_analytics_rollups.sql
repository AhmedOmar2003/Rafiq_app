-- =============================================================================
-- 0065  Backfill the analytics window served by provider/admin dashboards
-- -----------------------------------------------------------------------------
-- The public analytics RPC clamps reads to 365 days. Backfill that same window
-- in one grouped scan so existing events are available immediately after the
-- rollup read path is enabled.
-- =============================================================================

begin;

insert into public.analytics_daily_rollups (
  place_id,
  provider_id,
  day,
  kind,
  event_count,
  unique_users,
  unique_sessions
)
select
  e.place_id,
  coalesce(
    e.provider_id,
    (select pl.provider_id from public.places pl where pl.id = e.place_id)
  ) as provider_id,
  e.occurred_at::date as day,
  e.kind,
  count(*)::bigint as event_count,
  count(distinct e.user_id)::int as unique_users,
  count(distinct e.session_id)::int as unique_sessions
from public.analytics_events e
where e.is_filtered = false
  and e.place_id is not null
  and e.occurred_at >= current_date - 365
group by
  e.place_id,
  provider_id,
  e.occurred_at::date,
  e.kind
on conflict (place_id, day, kind) do update
  set provider_id = excluded.provider_id,
      event_count = excluded.event_count,
      unique_users = excluded.unique_users,
      unique_sessions = excluded.unique_sessions;

commit;
