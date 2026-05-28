-- =============================================================================
-- 0001  Extensions and enums
-- -----------------------------------------------------------------------------
-- Rafiq backend foundation. Everything that follows depends on these.
-- =============================================================================

begin;

-- pgcrypto    : UUIDs (gen_random_uuid()), digests.
-- citext      : case-insensitive emails / slugs.
-- pg_trgm     : trigram indexes for fuzzy search ("ka" matches "Cairo").
-- unaccent    : strip Arabic diacritics for search.
-- postgis     : geography(Point) for place locations and radius queries.
create extension if not exists "pgcrypto"  with schema extensions;
create extension if not exists "citext"    with schema extensions;
create extension if not exists "pg_trgm"   with schema extensions;
create extension if not exists "unaccent"  with schema extensions;
create extension if not exists "postgis"   with schema extensions;

-- ----------------------------------------------------------------------------
-- Application roles. Stored in `user_roles` (separate from `profiles`) so
-- a user can NEVER escalate their own role through a profile update.
--   user        regular customer
--   provider    business owner submitting places
--   moderator   reviews provider submissions
--   admin       full read + most writes + can suspend providers
--   super_admin can grant admin/moderator roles (rare; only by another super_admin)
-- ----------------------------------------------------------------------------
do $$ begin
  create type public.app_role as enum
    ('user', 'provider', 'moderator', 'admin', 'super_admin');
exception when duplicate_object then null; end $$;

-- Provider/place lifecycle. Public read filters down to `approved` only.
do $$ begin
  create type public.moderation_status as enum
    ('pending', 'under_review', 'approved', 'rejected', 'suspended');
exception when duplicate_object then null; end $$;

-- Used by `moderation_history.action`.
do $$ begin
  create type public.moderation_action as enum
    ('submit', 'start_review', 'approve', 'reject', 'suspend', 'reinstate', 'edit');
exception when duplicate_object then null; end $$;

-- Notification kinds delivered to a user's inbox.
do $$ begin
  create type public.notification_type as enum
    ('provider_approved',
     'provider_rejected',
     'provider_suspended',
     'place_approved',
     'place_rejected',
     'new_review',
     'system');
exception when duplicate_object then null; end $$;

-- Targets of a user-filed abuse report.
do $$ begin
  create type public.report_target as enum
    ('place', 'review', 'provider', 'user');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.report_status as enum
    ('open', 'reviewed', 'actioned', 'dismissed');
exception when duplicate_object then null; end $$;

-- Place pricing currency — defined here so 0006_places.sql can reference it
-- safely whether or not the places table already exists.
do $$ begin
  create type public.currency as enum ('EGP', 'USD', 'EUR', 'SAR');
exception when duplicate_object then null; end $$;

commit;
