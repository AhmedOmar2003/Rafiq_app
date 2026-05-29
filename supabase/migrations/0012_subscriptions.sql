-- =============================================================================
-- 0012  Subscriptions, plans, billing events
-- -----------------------------------------------------------------------------
-- Three plans (free / pro / max) with per-plan limits & visibility rules.
-- One *active* subscription row per provider; history is preserved.
--
-- Design notes (why this shape):
--   • plan limits live in a *table* so business edits (image cap, badge text,
--     boost weight) don't require a code release.
--   • subscriptions table is event-sourced: a new row is appended on every
--     transition (subscribe / upgrade / downgrade / cancel / expire). The
--     "current" row is found via `(provider_id, status='active')` partial
--     uniqueness, which keeps writes idempotent under retry.
--   • billing_events is the webhook landing pad. It is append-only with a
--     `provider_event_id` unique index, so Paymob/Stripe retries don't
--     double-charge or double-extend a subscription.
--   • Future-proofing: the schema does NOT assume Paymob. `gateway` is text +
--     enum so adding Stripe / Fawry later is additive.
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- Enums
-- ----------------------------------------------------------------------------
do $$ begin
  create type public.plan_tier as enum ('free', 'pro', 'max');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.subscription_status as enum (
    'trialing',     -- inside introductory period
    'active',       -- paid + within period_end
    'past_due',     -- payment missed, grace_period_ends_at not yet hit
    'canceled',     -- user-requested; still active until period_end
    'expired',      -- period ended, no renewal
    'incomplete'    -- created but first payment never confirmed
  );
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_gateway as enum ('paymob', 'stripe', 'manual');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.billing_event_kind as enum (
    'subscription_created',
    'payment_succeeded',
    'payment_failed',
    'subscription_renewed',
    'subscription_upgraded',
    'subscription_downgraded',
    'subscription_canceled',
    'subscription_expired',
    'refund_issued'
  );
exception when duplicate_object then null; end $$;

-- ----------------------------------------------------------------------------
-- subscription_plans
--
-- Single source of truth for what each tier UNLOCKS. UI reads this table to
-- render the pricing page so prices/limits can be changed without a deploy.
-- ----------------------------------------------------------------------------
create table if not exists public.subscription_plans (
  tier                  public.plan_tier primary key,
  display_name          text             not null,
  tagline               text             not null,
  price_monthly_egp     int              not null check (price_monthly_egp >= 0),
  price_yearly_egp      int              not null check (price_yearly_egp  >= 0),
  -- Catalog limits ---------------------------------------------------------
  max_places            int              not null check (max_places >= 1),
  max_gallery_images    int              not null check (max_gallery_images >= 1),
  max_videos            int              not null check (max_videos >= 0),
  max_cover_images      int              not null check (max_cover_images >= 1),
  -- Visibility / engagement ------------------------------------------------
  ranking_boost         numeric(4,3)     not null default 1.000
    check (ranking_boost between 1.000 and 2.000),  -- never > 2x (anti-dominance)
  is_verified           boolean          not null default false,
  has_analytics_basic   boolean          not null default false,
  has_analytics_pro     boolean          not null default false,
  has_promotions        boolean          not null default false,
  has_featured_slot     boolean          not null default false,
  has_push_campaigns    boolean          not null default false,
  has_homepage_spotlight boolean         not null default false,
  has_priority_support  boolean          not null default false,
  has_priority_moderation boolean        not null default false,
  -- UI metadata ------------------------------------------------------------
  badge_label           text,                          -- "Verified", "Premium"
  accent_color_hex      text             not null default '#681F00',
  cta_label             text             not null default 'اشترك',
  sort_order            int              not null,
  is_public             boolean          not null default true,  -- hides while editing
  created_at            timestamptz      not null default now(),
  updated_at            timestamptz      not null default now()
);

comment on table public.subscription_plans is
  'Catalog of plans. Update rows here to change UI + enforced limits.';
comment on column public.subscription_plans.ranking_boost is
  'Multiplier applied to ranking score. Hard-capped at 2x so relevance still wins.';

-- ----------------------------------------------------------------------------
-- Seed data — change anytime via SQL, no redeploy needed.
-- ----------------------------------------------------------------------------
insert into public.subscription_plans (
  tier, display_name, tagline,
  price_monthly_egp, price_yearly_egp,
  max_places, max_gallery_images, max_videos, max_cover_images,
  ranking_boost, is_verified,
  has_analytics_basic, has_analytics_pro,
  has_promotions, has_featured_slot, has_push_campaigns,
  has_homepage_spotlight, has_priority_support, has_priority_moderation,
  badge_label, accent_color_hex, cta_label, sort_order
) values
  ('free', 'مجاني',  'ابدأ مكانك على رفيق',
    0, 0,
    1, 3, 0, 1,
    1.000, false,
    false, false, false, false, false, false, false, false,
    null, '#979797', 'ابدأ ببلاش', 1),
  ('pro',  'برو',    'ظهور أحسن + analytics',
    299, 2990,
    3, 15, 1, 1,
    1.250, true,
    true, false, true, true, false, false, false, true,
    'موثَّق', '#681F00', 'اشترك في برو', 2),
  ('max',  'ماكس',   'كامل التحكم + spotlight',
    799, 7990,
    10, 60, 3, 3,
    1.500, true,
    true, true, true, true, true, true, true, true,
    'بريميوم', '#4A1600', 'اشترك في ماكس', 3)
on conflict (tier) do nothing;

-- ----------------------------------------------------------------------------
-- provider_subscriptions
--
-- Append-only history. The *current* subscription is the row whose status is
-- one of (trialing, active, past_due) and period_end is in the future.
-- ----------------------------------------------------------------------------
create table if not exists public.provider_subscriptions (
  id                    uuid              primary key default gen_random_uuid(),
  provider_id           uuid              not null references public.providers(id) on delete cascade,
  tier                  public.plan_tier  not null references public.subscription_plans(tier),
  status                public.subscription_status not null default 'incomplete',
  gateway               public.billing_gateway not null default 'manual',
  gateway_subscription_id text,                          -- ID at Paymob/Stripe
  -- Billing cycle ----------------------------------------------------------
  period_start          timestamptz       not null default now(),
  period_end            timestamptz       not null,      -- next renewal cut-off
  trial_ends_at         timestamptz,
  grace_period_ends_at  timestamptz,                     -- past_due hard cutoff
  cancel_at_period_end  boolean           not null default false,
  -- Schedule a downgrade *without* losing benefits mid-cycle ---------------
  scheduled_tier        public.plan_tier,
  scheduled_at          timestamptz,
  -- Audit ------------------------------------------------------------------
  amount_paid_egp       int               check (amount_paid_egp is null or amount_paid_egp >= 0),
  currency              public.currency   not null default 'EGP',
  metadata              jsonb             not null default '{}'::jsonb,
  canceled_at           timestamptz,
  created_at            timestamptz       not null default now(),
  updated_at            timestamptz       not null default now()
);

comment on table public.provider_subscriptions is
  'History of plan ownership. The current entitlement is the row that is in '
  '(trialing,active,past_due) for the provider, found via the partial unique index below.';

-- Exactly one currently-billed subscription per provider — enforced via
-- a partial unique index. Old rows (canceled / expired) stay for history.
create unique index if not exists provider_subscriptions_current_uidx
  on public.provider_subscriptions (provider_id)
  where status in ('trialing', 'active', 'past_due');

create index if not exists provider_subscriptions_provider_idx
  on public.provider_subscriptions (provider_id, created_at desc);
create index if not exists provider_subscriptions_status_idx
  on public.provider_subscriptions (status, period_end);
create index if not exists provider_subscriptions_renewal_idx
  on public.provider_subscriptions (period_end)
  where status in ('active', 'past_due', 'trialing');

-- ----------------------------------------------------------------------------
-- billing_events
--
-- Idempotent webhook landing. The gateway's own event id goes into
-- `provider_event_id`; duplicate deliveries hit the unique index and
-- safely no-op.
-- ----------------------------------------------------------------------------
create table if not exists public.billing_events (
  id                   uuid              primary key default gen_random_uuid(),
  provider_id          uuid              references public.providers(id) on delete cascade,
  subscription_id      uuid              references public.provider_subscriptions(id) on delete set null,
  kind                 public.billing_event_kind not null,
  gateway              public.billing_gateway not null,
  provider_event_id    text              not null,      -- gateway's idempotency key
  amount_egp           int,
  currency             public.currency   not null default 'EGP',
  raw_payload          jsonb             not null,
  occurred_at          timestamptz       not null default now(),
  processed_at         timestamptz,
  processing_error     text
);

create unique index if not exists billing_events_idempotency_uidx
  on public.billing_events (gateway, provider_event_id);
create index if not exists billing_events_provider_idx
  on public.billing_events (provider_id, occurred_at desc);
create index if not exists billing_events_unprocessed_idx
  on public.billing_events (occurred_at) where processed_at is null;

-- ----------------------------------------------------------------------------
-- View: provider_current_plan
--
-- Resolves the active plan + limits for a provider in one row. Anything that
-- needs to enforce limits should read this view, not the raw tables. Falls
-- back to 'free' when a provider has no subscription row.
-- ----------------------------------------------------------------------------
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
  -- Pull current limits from the plan catalog ------------------------------
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
  sp.accent_color_hex
from public.providers p
left join public.provider_subscriptions ps
       on ps.provider_id = p.id
      and ps.status in ('trialing', 'active', 'past_due')
left join public.subscription_plans sp
       on sp.tier = coalesce(ps.tier, 'free'::public.plan_tier)
where p.deleted_at is null;

comment on view public.provider_current_plan is
  'Effective plan resolution. Clients enforce limits by reading this view.';

-- ----------------------------------------------------------------------------
-- updated_at triggers
-- ----------------------------------------------------------------------------
drop trigger if exists set_updated_at on public.subscription_plans;
create trigger set_updated_at
  before update on public.subscription_plans
  for each row execute function public.set_updated_at();

drop trigger if exists set_updated_at on public.provider_subscriptions;
create trigger set_updated_at
  before update on public.provider_subscriptions
  for each row execute function public.set_updated_at();

commit;
