-- =============================================================================
-- 0036  Indexes that keep the dashboard fast as the app grows
-- -----------------------------------------------------------------------------
-- The overview page now reads `places.created_at` to build the 14-day growth
-- chart, and the appeals page reads `place_appeals.created_at` + status.
-- These compound indexes cover those queries so the planner avoids a seq
-- scan once we cross a few thousand rows.
--
-- IF NOT EXISTS so re-runs are safe.
-- =============================================================================

begin;

-- Overview growth chart: ORDER BY created_at, optionally LIMIT N
create index if not exists places_created_at_idx
  on public.places (created_at desc);

-- Appeals page: status filter + most-recent-first ordering
create index if not exists place_appeals_status_created_idx
  on public.place_appeals (status, created_at desc);

-- Subscriptions page: status filter + ordering
create index if not exists provider_subscriptions_status_created_idx
  on public.provider_subscriptions (status, created_at desc);

-- Reviews page (when it loads top reviews)
create index if not exists reviews_created_at_idx
  on public.reviews (created_at desc);

commit;
