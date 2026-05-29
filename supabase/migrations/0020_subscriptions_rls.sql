-- =============================================================================
-- 0020  RLS for subscriptions, billing, analytics, campaigns
-- -----------------------------------------------------------------------------
-- Threat model (one line per role):
--   anon          → no read on private tables; can call insert_event_batch only
--   authenticated → reads ONLY own provider's subscription / analytics
--   provider      → can manage own campaigns and read own data
--   moderator     → can review pending campaigns + see all provider data
--   admin         → full read + write on plans
--   service_role  → bypasses RLS (used by webhook handlers in Edge Functions)
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- subscription_plans
-- ----------------------------------------------------------------------------
alter table public.subscription_plans enable row level security;

drop policy if exists subscription_plans_public_read on public.subscription_plans;
create policy subscription_plans_public_read
  on public.subscription_plans
  for select
  using (is_public = true);

drop policy if exists subscription_plans_admin_write on public.subscription_plans;
create policy subscription_plans_admin_write
  on public.subscription_plans
  for all
  using (public.is_admin())
  with check (public.is_admin());

-- ----------------------------------------------------------------------------
-- provider_subscriptions
-- ----------------------------------------------------------------------------
alter table public.provider_subscriptions enable row level security;

drop policy if exists provider_subscriptions_owner_read on public.provider_subscriptions;
create policy provider_subscriptions_owner_read
  on public.provider_subscriptions
  for select
  using (
    exists (
      select 1 from public.providers p
      where p.id = provider_subscriptions.provider_id
        and p.owner_id = auth.uid()
    )
    or public.is_moderator_or_above()
  );

-- Writes happen exclusively from the billing webhook handler running under
-- service_role; there is intentionally NO policy that lets `authenticated`
-- insert/update here. service_role bypasses RLS.

-- ----------------------------------------------------------------------------
-- billing_events
-- ----------------------------------------------------------------------------
alter table public.billing_events enable row level security;

drop policy if exists billing_events_owner_read on public.billing_events;
create policy billing_events_owner_read
  on public.billing_events
  for select
  using (
    exists (
      select 1 from public.providers p
      where p.id = billing_events.provider_id
        and p.owner_id = auth.uid()
    )
    or public.is_admin()
  );

-- No public writes — webhook only (service_role).

-- ----------------------------------------------------------------------------
-- analytics_events
--
-- We expose ZERO direct read access to the raw event table. All ingest goes
-- through `insert_event_batch` (SECURITY DEFINER). All reads go through
-- rollups + summary view.
-- ----------------------------------------------------------------------------
alter table public.analytics_events enable row level security;

drop policy if exists analytics_events_admin_read on public.analytics_events;
create policy analytics_events_admin_read
  on public.analytics_events
  for select
  using (public.is_moderator_or_above());

-- No direct inserts/updates allowed; insert_event_batch() runs as definer.

-- ----------------------------------------------------------------------------
-- analytics_daily_rollups
-- ----------------------------------------------------------------------------
alter table public.analytics_daily_rollups enable row level security;

drop policy if exists analytics_rollups_owner_read on public.analytics_daily_rollups;
create policy analytics_rollups_owner_read
  on public.analytics_daily_rollups
  for select
  using (
    exists (
      select 1 from public.providers p
      where p.id = analytics_daily_rollups.provider_id
        and p.owner_id = auth.uid()
    )
    or public.is_moderator_or_above()
  );

-- ----------------------------------------------------------------------------
-- promotional_campaigns
-- ----------------------------------------------------------------------------
alter table public.promotional_campaigns enable row level security;

-- Providers manage their own; moderators read everything.
drop policy if exists promotional_campaigns_owner_rw on public.promotional_campaigns;
create policy promotional_campaigns_owner_rw
  on public.promotional_campaigns
  for all
  using (
    exists (
      select 1 from public.providers p
      where p.id = promotional_campaigns.provider_id
        and p.owner_id = auth.uid()
    )
    or public.is_moderator_or_above()
  )
  with check (
    exists (
      select 1 from public.providers p
      where p.id = promotional_campaigns.provider_id
        and p.owner_id = auth.uid()
    )
    or public.is_moderator_or_above()
  );

-- Public READ for active, approved campaigns only — used by the home feed.
drop policy if exists promotional_campaigns_public_read on public.promotional_campaigns;
create policy promotional_campaigns_public_read
  on public.promotional_campaigns
  for select
  using (
    status = 'active'
    and now() between starts_at and ends_at
  );

commit;
