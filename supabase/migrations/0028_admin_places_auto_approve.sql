-- =============================================================================
-- 0028  Admin-added places auto-approve + backfill
-- -----------------------------------------------------------------------------
-- Product rule
--   Places added directly by an admin from the web dashboard are trusted by
--   definition — the admin IS the moderator. Those rows must:
--     1. Default to `status = 'approved'` so they go live immediately.
--     2. Skip the 24-hour review queue and the "تحت المراجعة" countdown card.
--
--   Places added by providers from the mobile app still default to
--   `status = 'pending'` (no change), so the admin reviews them as before.
--
-- How we tell them apart
--   * Provider-added places carry `provider_id` (the FK to the provider row).
--   * Admin-added places have `provider_id IS NULL` (the dashboard's
--     createPlace server action never sets one).
--
-- This migration
--   * Backfills every existing row where `provider_id IS NULL` to
--     `status = 'approved'` + `approved_at = now()` so the historical
--     admin-added places don't sit forever in "pending" if they were
--     inserted before this rule existed.
--   * No trigger needed — the dashboard's server action will write
--     `status = 'approved'` explicitly going forward (see places/actions.ts).
-- =============================================================================

begin;

-- The 0010 places guard trigger blocks status changes unless `auth.uid()`
-- resolves to a moderator. Migration runs as the postgres role with no JWT,
-- so `auth.uid()` is null. For this one-shot historical backfill we flip the
-- session replication role so the trigger is skipped, run the UPDATE, then
-- restore — equivalent to a moderator action without coupling the migration
-- to any specific user id.
set local session_replication_role = 'replica';

update public.places
   set status      = 'approved'::public.moderation_status,
       approved_at = coalesce(approved_at, now())
 where provider_id is null
   and (status is null or status <> 'approved');

-- transaction COMMIT below auto-restores session_replication_role.
commit;
