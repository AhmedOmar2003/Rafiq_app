-- =============================================================================
-- 0046  Accept session_id in campaign metric RPC and harden dedup windows
-- -----------------------------------------------------------------------------
-- Problem:
--   Flutter now passes `_session_id` for campaign impression/click tracking,
--   but the SQL RPC still only accepts two parameters. That leaves the
--   session-level dedup story incomplete and can break RPC calls with the new
--   client payload.
--
-- Goal:
--   • Accept `_session_id` explicitly.
--   • Deduplicate on a stable user+session+campaign key.
--   • Use calmer windows: impressions ~60m, clicks ~24h.
--   • Keep a 2-arg compatibility wrapper for any older callers.
-- =============================================================================

begin;

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
