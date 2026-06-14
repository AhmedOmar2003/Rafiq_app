-- =============================================================================
-- 0066  Make daily analytics rebuilds exact
-- -----------------------------------------------------------------------------
-- Events can be marked is_filtered after an earlier rollup. Replacing the
-- requested day prevents stale rows from surviving an idempotent rebuild.
-- =============================================================================

begin;

create or replace function public.rebuild_daily_rollups(_day date)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  _affected int;
begin
  delete from public.analytics_daily_rollups
  where day = _day;

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
    _day,
    e.kind,
    count(*)::bigint,
    count(distinct e.user_id)::int,
    count(distinct e.session_id)::int
  from public.analytics_events e
  where e.is_filtered = false
    and e.place_id is not null
    and e.occurred_at >= _day
    and e.occurred_at < _day + interval '1 day'
  group by e.place_id, provider_id, e.kind;

  get diagnostics _affected = row_count;
  return _affected;
end;
$$;

revoke all on function public.rebuild_daily_rollups(date) from public;

commit;
