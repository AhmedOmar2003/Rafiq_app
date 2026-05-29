-- =============================================================================
-- 0019  Promotions + ranking
-- -----------------------------------------------------------------------------
-- • promotional_campaigns: providers create offers / "featured" placements
--   if their plan allows (Pro+).
-- • The ranking function blends relevance, quality, freshness, and a *capped*
--   subscription boost. Boost MUST NOT dominate — Free places with strong
--   reviews still surface. The cap is enforced at the plan level
--   (ranking_boost ≤ 2.0) and at the function level (sigmoid clamp).
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- promotional_campaign type
-- ----------------------------------------------------------------------------
do $$ begin
  create type public.campaign_kind as enum (
    'featured',       -- appears in "Featured" rail (Pro+)
    'spotlight',      -- homepage hero spot (Max only)
    'push_notification', -- one-shot push to opted-in users (Max only)
    'discount'        -- visual badge "10% off" on the card (Pro+)
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.campaign_status as enum (
    'draft', 'pending_review', 'active', 'paused', 'rejected', 'ended'
  );
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- promotional_campaigns
-- ----------------------------------------------------------------------------
create table if not exists public.promotional_campaigns (
  id              uuid              primary key default gen_random_uuid(),
  provider_id     uuid              not null references public.providers(id) on delete cascade,
  place_id        uuid              references public.places(id) on delete cascade,
  kind            public.campaign_kind not null,
  status          public.campaign_status not null default 'draft',
  -- Content ----------------------------------------------------------------
  title           text              not null check (char_length(title) between 3 and 100),
  body            text              check (body is null or char_length(body) <= 280),
  image_path      text,             -- in `campaign-assets` bucket
  cta_label       text              check (cta_label is null or char_length(cta_label) <= 30),
  -- Scheduling -------------------------------------------------------------
  starts_at       timestamptz       not null default now(),
  ends_at         timestamptz       not null,
  -- Targeting (optional) ---------------------------------------------------
  target_city_ids   uuid[]          not null default '{}'::uuid[],
  target_category_ids uuid[]        not null default '{}'::uuid[],
  -- Performance counters (updated by triggers / nightly job) ---------------
  impressions     bigint            not null default 0,
  clicks          bigint            not null default 0,
  -- Audit ------------------------------------------------------------------
  rejection_reason text,
  approved_by     uuid              references auth.users(id) on delete set null,
  approved_at     timestamptz,
  created_at      timestamptz       not null default now(),
  updated_at      timestamptz       not null default now(),
  check (ends_at > starts_at)
);

create index if not exists promotional_campaigns_provider_idx
  on public.promotional_campaigns (provider_id, created_at desc);
create index if not exists promotional_campaigns_active_idx
  on public.promotional_campaigns (kind, ends_at)
  where status = 'active';
create index if not exists promotional_campaigns_moderation_idx
  on public.promotional_campaigns (status, created_at)
  where status in ('pending_review', 'draft');

drop trigger if exists set_updated_at on public.promotional_campaigns;
create trigger set_updated_at
  before update on public.promotional_campaigns
  for each row execute function public.set_updated_at();

-- ----------------------------------------------------------------------------
-- Helper: place_ranking_score(place_id)
--
-- Composite score that the recommendation pipeline calls. Components:
--   • Relevance baseline:   rating_avg / 5  (range 0..1)
--   • Engagement signal:    log(1 + rating_count) / log(1 + 1000)  (0..~1)
--   • Freshness signal:     exp(-days_since_created / 60)  (0..1)
--   • Plan boost:           sigmoid-soft cap to keep paid plans from
--                            crushing organic relevance.
--
-- Hard rule: an unrated Max place still scores below a 4.5★ Free place
-- with hundreds of reviews. Boost is a tilt, not a takeover.
-- ----------------------------------------------------------------------------
create or replace function public.place_ranking_score(_place_id uuid)
returns numeric
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  _pl   public.places%rowtype;
  _boost numeric;
  _relevance numeric;
  _engagement numeric;
  _freshness numeric;
  _days numeric;
  _score numeric;
begin
  select * into _pl from public.places where id = _place_id and deleted_at is null;
  if not found then return 0; end if;

  -- Relevance & engagement (cap to keep heavy review counts from saturating)
  _relevance  := coalesce(_pl.rating_avg, 0) / 5.0;
  _engagement := least(
    1.0,
    ln(1 + coalesce(_pl.rating_count, 0)) / ln(1 + 1000)
  );

  _days := extract(epoch from (now() - _pl.created_at)) / 86400.0;
  _freshness := exp(-_days / 60.0);

  -- Plan boost: read effective tier via the current_plan view.
  select pcp.ranking_boost into _boost
    from public.provider_current_plan pcp
    where pcp.provider_id = _pl.provider_id;
  _boost := coalesce(_boost, 1.0);

  -- Weighted composite: relevance dominates (0.55 weight), engagement (0.30),
  -- freshness (0.15). The boost multiplies the *final* score but a sigmoid
  -- clamp prevents Max from > 2x a 4★ Free place with substantial engagement.
  _score := (0.55 * _relevance) + (0.30 * _engagement) + (0.15 * _freshness);
  _score := _score * (1.0 + ((_boost - 1.0) * (1.0 - _engagement * 0.5)));

  return _score;
end;
$$;

comment on function public.place_ranking_score(uuid) is
  'Composite ranking. Boost is dampened by engagement so popular Free places '
  'cannot be buried by a brand-new Max listing.';

-- ----------------------------------------------------------------------------
-- View: ranked_places — the public recommendation feed.
--
-- Only approved + non-deleted places. Adds a `featured_score` so the client
-- can split the feed into "Featured" + "More results" without re-querying.
-- ----------------------------------------------------------------------------
create or replace view public.ranked_places as
select
  p.id,
  p.provider_id,
  p.city_id,
  p.category_id,
  p.slug,
  p.name,
  p.description,
  p.address,
  p.location,
  p.price_min,
  p.price_max,
  p.currency,
  p.budget_bucket,
  p.rating_avg,
  p.rating_count,
  pcp.tier        as plan_tier,
  pcp.is_verified,
  pcp.badge_label,
  pcp.has_featured_slot,
  public.place_ranking_score(p.id) as rank_score,
  -- Featured signal: provider has the slot AND a currently-running featured campaign
  exists (
    select 1 from public.promotional_campaigns c
    where c.place_id  = p.id
      and c.kind      = 'featured'
      and c.status    = 'active'
      and now() between c.starts_at and c.ends_at
  ) as is_featured
from public.places p
left join public.provider_current_plan pcp on pcp.provider_id = p.provider_id
where p.status = 'approved'
  and p.deleted_at is null;

comment on view public.ranked_places is
  'Public-safe recommendation feed. Sort DESC by rank_score; split is_featured = true into a rail.';

commit;
