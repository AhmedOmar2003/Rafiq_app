-- =============================================================================
-- 0015  Restore profiles.email_verified_at
-- -----------------------------------------------------------------------------
-- Some remote databases were created without the canonical
-- `profiles.email_verified_at` column. The auth triggers and bootstrap code
-- expect it to exist, so this migration restores the column and backfills it
-- from auth.users for any already-created profiles.
-- =============================================================================

begin;

alter table if exists public.profiles
  add column if not exists email_verified_at timestamptz;

update public.profiles p
set email_verified_at = u.email_confirmed_at
from auth.users u
where p.id = u.id
  and p.email_verified_at is null
  and u.email_confirmed_at is not null;

commit;
