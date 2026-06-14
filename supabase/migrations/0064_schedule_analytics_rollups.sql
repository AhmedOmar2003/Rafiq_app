-- =============================================================================
-- 0064  Keep analytics daily rollups current
-- -----------------------------------------------------------------------------
-- Provider/admin analytics read historical days from analytics_daily_rollups.
-- Rebuild today and yesterday hourly so midnight boundaries cannot make recent
-- analytics disappear while raw events remain the source of truth.
-- =============================================================================

begin;

create extension if not exists "pg_cron" with schema extensions;

do $$
declare
  _job_id bigint;
begin
  for _job_id in
    select jobid
    from cron.job
    where jobname = 'rafiq-rebuild-analytics-rollups'
  loop
    perform cron.unschedule(_job_id);
  end loop;

  perform cron.schedule(
    'rafiq-rebuild-analytics-rollups',
    '7 * * * *',
    $job$
      select public.rebuild_daily_rollups(current_date);
      select public.rebuild_daily_rollups(current_date - 1);
    $job$
  );
end;
$$;

commit;
