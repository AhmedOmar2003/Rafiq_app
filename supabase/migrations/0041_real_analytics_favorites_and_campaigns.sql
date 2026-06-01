-- =============================================================================
-- 0041  Real analytics, favorites re-enable, and campaign workflow hardening
-- -----------------------------------------------------------------------------
-- Goals:
--   • Re-enable favorites for authenticated users.
--   • Add plan-based campaign limits (`max_campaigns`).
--   • Expose a live provider analytics RPC so dashboards see real usage
--     immediately instead of waiting for nightly rollups.
--   • Add a guarded provider campaign creation RPC.
--   • Add a tiny public-safe metric recorder for campaign impressions/clicks.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- Plans: number of campaigns / offers each tier can keep live or pending.
-- -----------------------------------------------------------------------------
alter table public.subscription_plans
  add column if not exists max_campaigns int not null default 0
  check (max_campaigns >= 0);

update public.subscription_plans
set max_campaigns = case tier
  when 'free' then 0
  when 'pro' then 3
  when 'max' then 10
  else max_campaigns
end;

create or replace view public.provider_current_plan as
select
  p.id                              as provider_id,
  coalesce(ps.tier, 'free'::public.plan_tier) as tier,
  coalesce(ps.status, 'active'::public.subscription_status) as status,
  ps.period_start,
  ps.period_end,
  ps.trial_ends_at,
  ps.grace_period_ends_at,
  ps.cancel_at_period_end,
  ps.scheduled_tier,
  sp.max_places,
  sp.max_gallery_images,
  sp.max_videos,
  sp.max_cover_images,
  sp.ranking_boost,
  sp.is_verified,
  sp.has_analytics_basic,
  sp.has_analytics_pro,
  sp.has_promotions,
  sp.has_featured_slot,
  sp.has_push_campaigns,
  sp.has_homepage_spotlight,
  sp.has_priority_support,
  sp.has_priority_moderation,
  sp.badge_label,
  sp.accent_color_hex,
  sp.max_campaigns
from public.providers p
left join public.provider_subscriptions ps
       on ps.provider_id = p.id
      and ps.status in ('trialing', 'active', 'past_due')
left join public.subscription_plans sp
       on sp.tier = coalesce(ps.tier, 'free'::public.plan_tier)
where p.deleted_at is null;

comment on view public.provider_current_plan is
  'Effective plan resolution including campaign limits. Clients enforce limits by reading this view.';

-- -----------------------------------------------------------------------------
-- Re-enable favorites for authenticated users.
-- -----------------------------------------------------------------------------
alter table public.favorites enable row level security;

drop policy if exists favorites_select_self on public.favorites;
create policy favorites_select_self
  on public.favorites for select
  to authenticated
  using (user_id = auth.uid());

drop policy if exists favorites_write_self on public.favorites;
create policy favorites_write_self
  on public.favorites for all
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- -----------------------------------------------------------------------------
-- Live analytics summary for the provider dashboard.
--
-- Reads directly from analytics_events and aggregates on the fly so counters
-- move as soon as users interact with the place.
-- -----------------------------------------------------------------------------
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
    return;
  end if;

  return query
  select
    e.place_id,
    e.occurred_at::date as day,
    e.kind,
    count(*)::bigint as event_count,
    count(distinct e.user_id)::int as unique_users,
    count(distinct e.session_id)::int as unique_sessions
  from public.analytics_events e
  where e.is_filtered = false
    and coalesce(
      e.provider_id,
      (select pl.provider_id from public.places pl where pl.id = e.place_id)
    ) = _provider_id
    and e.occurred_at >= now() - make_interval(days => greatest(_days, 1))
    and (_place_id is null or e.place_id = _place_id)
  group by e.place_id, e.occurred_at::date, e.kind
  order by day desc;
end;
$$;

revoke all on function public.provider_place_analytics_live(uuid, int) from public;
grant execute on function public.provider_place_analytics_live(uuid, int) to authenticated;

-- -----------------------------------------------------------------------------
-- Provider campaign creation with hard backend checks.
-- -----------------------------------------------------------------------------
create or replace function public.create_provider_campaign(
  _place_id uuid,
  _kind public.campaign_kind,
  _title text,
  _body text default null,
  _image_path text default null,
  _cta_label text default null,
  _starts_at timestamptz default null,
  _ends_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  _uid uuid := auth.uid();
  _provider_id uuid;
  _ent public.provider_current_plan%rowtype;
  _active_count int := 0;
  _campaign_id uuid;
  _starts timestamptz := coalesce(_starts_at, now());
begin
  if _uid is null then
    raise exception 'authentication required';
  end if;

  if _place_id is null then
    raise exception 'place is required';
  end if;

  if _ends_at is null or _ends_at <= _starts then
    raise exception 'campaign end must be after start';
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

  perform 1
  from public.places pl
  where pl.id = _place_id
    and pl.provider_id = _provider_id
    and pl.deleted_at is null
    and pl.status = 'approved';

  if not found then
    raise exception 'place not eligible for campaigns';
  end if;

  select *
    into _ent
  from public.provider_current_plan
  where provider_id = _provider_id;

  if not coalesce(_ent.has_promotions, false) then
    raise exception 'current plan does not allow promotions';
  end if;

  if coalesce(_ent.max_campaigns, 0) <= 0 then
    raise exception 'campaign limit reached for current plan';
  end if;

  if _kind = 'featured' and not coalesce(_ent.has_featured_slot, false) then
    raise exception 'featured campaigns require a higher plan';
  end if;

  if _kind = 'push_notification' and not coalesce(_ent.has_push_campaigns, false) then
    raise exception 'push campaigns require a higher plan';
  end if;

  if _kind = 'spotlight' and not coalesce(_ent.has_homepage_spotlight, false) then
    raise exception 'spotlight campaigns require a higher plan';
  end if;

  select count(*)
    into _active_count
  from public.promotional_campaigns c
  where c.provider_id = _provider_id
    and c.status in ('draft', 'pending_review', 'active', 'paused')
    and (c.ends_at >= now() or c.status in ('draft', 'pending_review', 'paused'));

  if _active_count >= coalesce(_ent.max_campaigns, 0) then
    raise exception 'campaign limit reached for current plan';
  end if;

  insert into public.promotional_campaigns (
    provider_id,
    place_id,
    kind,
    status,
    title,
    body,
    image_path,
    cta_label,
    starts_at,
    ends_at
  ) values (
    _provider_id,
    _place_id,
    _kind,
    'pending_review',
    _title,
    _body,
    nullif(_image_path, ''),
    nullif(_cta_label, ''),
    _starts,
    _ends_at
  )
  returning id into _campaign_id;

  return _campaign_id;
end;
$$;

revoke all on function public.create_provider_campaign(
  uuid,
  public.campaign_kind,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) from public;
grant execute on function public.create_provider_campaign(
  uuid,
  public.campaign_kind,
  text,
  text,
  text,
  text,
  timestamptz,
  timestamptz
) to authenticated;

-- -----------------------------------------------------------------------------
-- Public-safe campaign metric recorder for banner impressions / clicks.
-- -----------------------------------------------------------------------------
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
  if _campaign_id is null or _metric is null then
    return;
  end if;

  if _metric = 'impression' then
    update public.promotional_campaigns
       set impressions = impressions + 1,
           updated_at = now()
     where id = _campaign_id
       and status = 'active'
       and now() between starts_at and ends_at;
  elsif _metric = 'click' then
    update public.promotional_campaigns
       set clicks = clicks + 1,
           updated_at = now()
     where id = _campaign_id
       and status = 'active'
       and now() between starts_at and ends_at;
  end if;
end;
$$;

revoke all on function public.record_campaign_metric(uuid, text) from public;
grant execute on function public.record_campaign_metric(uuid, text) to anon, authenticated;

commit;
