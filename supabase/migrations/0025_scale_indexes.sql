-- =============================================================================
-- 0025  Scale indexes — covering indexes for the hot read paths
-- -----------------------------------------------------------------------------
-- The base schema already has the single-column indexes that make individual
-- lookups fast (`providers_owner_idx`, `places_provider_idx`, etc.). What it
-- doesn't have are the *composite* and *partial* indexes that turn the
-- admin-dashboard and Flutter-bootstrap queries from O(N) seq-scans into
-- O(log N) index-only scans once the user base grows past a few thousand.
--
-- Every index here is created with `if not exists` so this migration is safe
-- to re-run, and `concurrently` is NOT used (Supabase migration runner uses
-- a transaction). If you ever rerun this on a busy production DB outside of
-- a migration window, do it manually with `concurrently` to avoid table
-- locks.
-- =============================================================================

begin;

-- ── provider_subscriptions ──────────────────────────────────────────────────
-- The admin Subscriptions page reads rows where status ∈ (active, trialing,
-- past_due). This composite covers the filter + ordering in one index.
create index if not exists provider_subscriptions_active_idx
  on public.provider_subscriptions (status, created_at desc)
  where status in ('active', 'trialing', 'past_due');

-- The "find the current sub for a provider" lookup (used by
-- apply_demo_subscription and delete_my_account) hits provider_id + status.
create index if not exists provider_subscriptions_provider_status_idx
  on public.provider_subscriptions (provider_id, status);

-- ── user_roles ──────────────────────────────────────────────────────────────
-- Bootstrap reads ask "what active roles does this user have?". The default
-- index on (user_id, role) is the unique key, but it doesn't filter out
-- revoked rows. This partial gives us index-only scans on the hot path.
create index if not exists user_roles_active_idx
  on public.user_roles (user_id, role)
  where revoked_at is null;

-- ── admin_roles (dashboard auth check on every dashboard request) ───────────
-- Admin proxy: `select role from admin_roles where user_id = ?` runs on every
-- single dashboard page navigation. The PK already covers it, but explicit
-- index lets the planner pick it without scanning the FK.
do $$
begin
  if to_regclass('public.admin_roles') is not null then
    create index if not exists admin_roles_user_idx
      on public.admin_roles (user_id);
  end if;
end $$;

-- ── places (count per provider for the admin Providers tab) ─────────────────
-- `places_provider_idx` already exists with `where deleted_at is null`. We
-- add a covering index that includes the FK for fast COUNT(*) aggregations.
-- (Postgres < 11 doesn't support INCLUDE; everything we run is >= 14.)
create index if not exists places_provider_count_idx
  on public.places (provider_id)
  include (id)
  where deleted_at is null and status = 'approved';

-- ── profiles (search by email in admin) ─────────────────────────────────────
-- The admin Users page filter searches by name + email. citext is
-- case-insensitive but a btree on it still helps prefix matches. The trigram
-- index handles substring search.
create index if not exists profiles_email_idx
  on public.profiles (email);

-- ── account_deletions (admin audit page, sorted by recency) ─────────────────
-- Already has `account_deletions_when_idx`. No further work needed; this
-- block exists only as a documentation anchor so future readers know we
-- considered it.

commit;
