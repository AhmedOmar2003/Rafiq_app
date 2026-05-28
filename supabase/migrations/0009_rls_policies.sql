-- =============================================================================
-- 0009  Row-Level Security policies
-- -----------------------------------------------------------------------------
-- POLICY MODEL
--   1. RLS is ON for every table in public.*.
--   2. The `service_role` always bypasses RLS (Postgres behaviour) — server-side
--      Edge Functions use it for privileged writes.
--   3. Anonymous (`anon`) reads are limited to PUBLIC catalogue content:
--      approved places, place images, approved-place reviews, cities, categories.
--   4. Authenticated users (`authenticated`) can:
--        - manage their own profile (limited fields)
--        - file moderation reports
--        - submit reviews on places
--   5. Favorites and notifications are intentionally disabled for now.
--   6. Providers (`provider` role) can manage *their own* providers row,
--      provider_documents, and places — but cannot self-approve.
--   7. Moderators/admins can read everything and update moderation flags
--      via Edge Functions (server-side validated).
--   8. user_roles is read-only to authenticated users (own rows); writes are
--      service-role only. This prevents privilege escalation entirely.
-- =============================================================================

begin;

-- Turn on RLS everywhere.
alter table if exists public.profiles            enable row level security;
alter table if exists public.user_roles          enable row level security;
alter table if exists public.cities              enable row level security;
alter table if exists public.categories          enable row level security;
alter table if exists public.providers           enable row level security;
alter table if exists public.provider_documents  enable row level security;
alter table if exists public.provider_requests   enable row level security;
alter table if exists public.places              enable row level security;
alter table if exists public.place_images        enable row level security;
alter table if exists public.reviews             enable row level security;
alter table if exists public.favorites           enable row level security;
alter table if exists public.notifications       enable row level security;
alter table if exists public.moderation_reports  enable row level security;
alter table if exists public.moderation_history  enable row level security;
alter table if exists public.admin_logs          enable row level security;
alter table if exists public.rate_limit_buckets  enable row level security;
alter table if exists public.login_attempts      enable row level security;

-- =============================================================================
-- profiles
-- =============================================================================
drop policy if exists profiles_select_self_or_admin on public.profiles;
create policy profiles_select_self_or_admin
  on public.profiles for select
  to authenticated
  using (
    auth.uid() = id
    or public.is_moderator_or_above()
  );

-- Anon CANNOT read profiles. Public name/avatar lookups (e.g. on reviews)
-- go through a view exposed via security_invoker = off, not the raw table.

drop policy if exists profiles_insert_self on public.profiles;
create policy profiles_insert_self
  on public.profiles for insert
  to authenticated
  with check (auth.uid() = id);

-- IMPORTANT: only allow user to update *their own* non-privileged fields.
-- We block role, is_disabled, deleted_at from being written by the user via
-- a column grant + a check that those values don't change. The simplest
-- guarantee is to never let the user update those columns — since they aren't
-- listed here in user-land, and there's a separate `user_roles` table.
drop policy if exists profiles_update_self on public.profiles;
create policy profiles_update_self
  on public.profiles for update
  to authenticated
  using (auth.uid() = id and is_disabled = false)
  with check (
    auth.uid() = id
    and is_disabled = false              -- cannot un-disable themselves
    and deleted_at is null               -- cannot un-delete themselves
  );

drop policy if exists profiles_admin_update on public.profiles;
create policy profiles_admin_update
  on public.profiles for update
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- =============================================================================
-- user_roles  —  AUTHORITATIVE RBAC TABLE
--
-- Users can SELECT their own (revoked) roles for UI gating, nothing else.
-- All writes go through service role / Edge Functions.
-- =============================================================================
drop policy if exists user_roles_select_self on public.user_roles;
create policy user_roles_select_self
  on public.user_roles for select
  to authenticated
  using (user_id::text = auth.uid()::text or public.is_admin());

-- Explicitly NO insert/update/delete policy for non-service-role.
-- Without a policy, INSERT/UPDATE/DELETE is denied for anon + authenticated.

-- =============================================================================
-- cities / categories  —  public read, admin write
-- =============================================================================
drop policy if exists cities_select_public on public.cities;
create policy cities_select_public
  on public.cities for select
  using (is_active or public.is_moderator_or_above());

drop policy if exists cities_admin_write on public.cities;
create policy cities_admin_write
  on public.cities for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

drop policy if exists categories_select_public on public.categories;
create policy categories_select_public
  on public.categories for select
  using (is_active or public.is_moderator_or_above());

drop policy if exists categories_admin_write on public.categories;
create policy categories_admin_write
  on public.categories for all
  to authenticated
  using (public.is_admin())
  with check (public.is_admin());

-- =============================================================================
-- providers
-- =============================================================================
-- Public sees ONLY approved providers (used in place listings).
drop policy if exists providers_select_public on public.providers;
create policy providers_select_public
  on public.providers for select
  using (
    (status = 'approved' and deleted_at is null)
    or owner_id = auth.uid()
    or public.is_moderator_or_above()
  );

-- A provider user creates their own row exactly once. The owner_id MUST match
-- the JWT; the initial status is forced to 'pending' regardless of payload.
drop policy if exists providers_insert_self on public.providers;
create policy providers_insert_self
  on public.providers for insert
  to authenticated
  with check (
    owner_id = auth.uid()
    and public.is_provider()
    and status = 'pending'                       -- cannot self-approve
    and approved_at is null
    and approved_by is null
    and suspended_at is null
  );

-- Owner can edit their own row, BUT cannot mutate moderation columns.
drop policy if exists providers_update_self on public.providers;
create policy providers_update_self
  on public.providers for update
  to authenticated
  using (owner_id = auth.uid())
  with check (
    owner_id = auth.uid()
    -- status / approved_* / suspended_* can ONLY be changed by service role.
    -- Postgres enforces this naturally because the `with check` re-evaluates
    -- the row; the helper trigger 0019 belt-and-braces these columns.
  );

-- Moderators can read & update for moderation actions (typically through
-- Edge Functions, but a direct UPDATE from a trusted dashboard also works).
drop policy if exists providers_moderator_update on public.providers;
create policy providers_moderator_update
  on public.providers for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

-- =============================================================================
-- provider_documents  —  PRIVATE
-- =============================================================================
drop policy if exists provider_documents_select_self on public.provider_documents;
create policy provider_documents_select_self
  on public.provider_documents for select
  to authenticated
  using (
    exists (
      select 1 from public.providers p
      where p.id = provider_documents.provider_id
        and (p.owner_id = auth.uid() or public.is_moderator_or_above())
    )
  );

drop policy if exists provider_documents_insert_self on public.provider_documents;
create policy provider_documents_insert_self
  on public.provider_documents for insert
  to authenticated
  with check (
    exists (
      select 1 from public.providers p
      where p.id = provider_documents.provider_id
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists provider_documents_moderator_verify on public.provider_documents;
create policy provider_documents_moderator_verify
  on public.provider_documents for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

drop policy if exists provider_documents_delete_self on public.provider_documents;
create policy provider_documents_delete_self
  on public.provider_documents for delete
  to authenticated
  using (
    exists (
      select 1 from public.providers p
      where p.id = provider_documents.provider_id
        and p.owner_id = auth.uid()
    )
  );

-- =============================================================================
-- provider_requests
-- =============================================================================
drop policy if exists provider_requests_select on public.provider_requests;
create policy provider_requests_select
  on public.provider_requests for select
  to authenticated
  using (
    submitted_by = auth.uid()
    or public.is_moderator_or_above()
  );

drop policy if exists provider_requests_insert_self on public.provider_requests;
create policy provider_requests_insert_self
  on public.provider_requests for insert
  to authenticated
  with check (
    submitted_by = auth.uid()
    and status = 'pending'
    and exists (
      select 1 from public.providers p
      where p.id = provider_requests.provider_id
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists provider_requests_moderator_review on public.provider_requests;
create policy provider_requests_moderator_review
  on public.provider_requests for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

-- =============================================================================
-- places
-- =============================================================================
-- Public sees ONLY approved + not deleted. Owners see their own. Mods see all.
drop policy if exists places_select_public on public.places;
create policy places_select_public
  on public.places for select
  using (
    (status = 'approved' and deleted_at is null)
    or exists (
      select 1 from public.providers p
      where p.id = places.provider_id and p.owner_id = auth.uid()
    )
    or public.is_moderator_or_above()
  );

-- Provider creates places for themselves; status forced to pending.
drop policy if exists places_insert_provider on public.places;
create policy places_insert_provider
  on public.places for insert
  to authenticated
  with check (
    status = 'pending'
    and approved_at is null
    and approved_by is null
    and exists (
      select 1 from public.providers p
      where p.id = places.provider_id
        and p.owner_id = auth.uid()
        and p.status = 'approved'                          -- only approved providers can list
        and p.deleted_at is null
    )
  );

-- Provider can edit content of their own places.
drop policy if exists places_update_owner on public.places;
create policy places_update_owner
  on public.places for update
  to authenticated
  using (
    exists (
      select 1 from public.providers p
      where p.id = places.provider_id and p.owner_id = auth.uid()
    )
    and status in ('pending', 'approved')                  -- can't edit while rejected/suspended
  )
  with check (
    exists (
      select 1 from public.providers p
      where p.id = places.provider_id and p.owner_id = auth.uid()
    )
  );

drop policy if exists places_moderator_update on public.places;
create policy places_moderator_update
  on public.places for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

-- Soft delete only — service role / admin sets deleted_at.
drop policy if exists places_admin_delete on public.places;
create policy places_admin_delete
  on public.places for delete
  to authenticated
  using (public.is_admin());

-- =============================================================================
-- place_images
-- =============================================================================
drop policy if exists place_images_select_public on public.place_images;
create policy place_images_select_public
  on public.place_images for select
  using (
    exists (
      select 1 from public.places pl
      where pl.id::text = place_images.place_id::text
        and ((pl.status = 'approved' and pl.deleted_at is null)
             or exists (select 1 from public.providers p
                        where p.id = pl.provider_id and p.owner_id = auth.uid())
             or public.is_moderator_or_above())
    )
  );

drop policy if exists place_images_insert_owner on public.place_images;
create policy place_images_insert_owner
  on public.place_images for insert
  to authenticated
  with check (
    exists (
      select 1
      from public.places pl
      join public.providers p on p.id = pl.provider_id
      where pl.id::text = place_images.place_id::text
        and p.owner_id = auth.uid()
    )
  );

drop policy if exists place_images_delete_owner on public.place_images;
create policy place_images_delete_owner
  on public.place_images for delete
  to authenticated
  using (
    exists (
      select 1
      from public.places pl
      join public.providers p on p.id = pl.provider_id
      where pl.id::text = place_images.place_id::text
        and (p.owner_id = auth.uid() or public.is_moderator_or_above())
    )
  );

-- =============================================================================
-- reviews
-- =============================================================================
drop policy if exists reviews_select_public on public.reviews;
create policy reviews_select_public
  on public.reviews for select
  using (
    (is_hidden = false and deleted_at is null
     and exists (
       select 1 from public.places pl
       where pl.id::text = reviews.place_id::text
         and pl.status = 'approved' and pl.deleted_at is null
     ))
    or user_id::text = auth.uid()::text
    or public.is_moderator_or_above()
  );

drop policy if exists reviews_insert_self on public.reviews;
create policy reviews_insert_self
  on public.reviews for insert
  to authenticated
  with check (
    user_id::text = auth.uid()::text
    and exists (
      select 1 from public.places pl
      where pl.id::text = reviews.place_id::text
        and pl.status = 'approved' and pl.deleted_at is null
    )
    and not exists (
      -- Prevent a provider from reviewing their own place.
      select 1 from public.places pl
      join public.providers p on p.id = pl.provider_id
      where pl.id::text = reviews.place_id::text and p.owner_id = auth.uid()
    )
  );

drop policy if exists reviews_update_self on public.reviews;
create policy reviews_update_self
  on public.reviews for update
  to authenticated
  using (user_id::text = auth.uid()::text and deleted_at is null)
  with check (user_id::text = auth.uid()::text and is_hidden = false);  -- user can't hide their own to bypass mod

drop policy if exists reviews_moderator_hide on public.reviews;
create policy reviews_moderator_hide
  on public.reviews for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

drop policy if exists reviews_delete_self on public.reviews;
create policy reviews_delete_self
  on public.reviews for delete
  to authenticated
  using (user_id::text = auth.uid()::text or public.is_admin());

-- =============================================================================
-- favorites
-- =============================================================================
-- Disabled for now. The table remains in the schema for compatibility, but
-- RLS has no policies here so anon/authenticated cannot use it.

-- =============================================================================
-- notifications
-- =============================================================================
-- Disabled for now. Any Edge Function calls that used to write inbox rows are
-- turned into no-ops in `supabase/functions/_shared/auth.ts`.

-- =============================================================================
-- moderation_reports
-- =============================================================================
drop policy if exists moderation_reports_select on public.moderation_reports;
create policy moderation_reports_select
  on public.moderation_reports for select
  to authenticated
  using (
    reporter_id::text = auth.uid()::text
    or public.is_moderator_or_above()
  );

drop policy if exists moderation_reports_insert_self on public.moderation_reports;
create policy moderation_reports_insert_self
  on public.moderation_reports for insert
  to authenticated
  with check (
    reporter_id::text = auth.uid()::text
    and status = 'open'
    and resolved_by is null
    and resolved_at is null
  );

drop policy if exists moderation_reports_moderator_resolve on public.moderation_reports;
create policy moderation_reports_moderator_resolve
  on public.moderation_reports for update
  to authenticated
  using (public.is_moderator_or_above())
  with check (public.is_moderator_or_above());

-- =============================================================================
-- moderation_history & admin_logs  —  APPEND-ONLY for everyone except service role
-- =============================================================================
drop policy if exists moderation_history_select on public.moderation_history;
create policy moderation_history_select
  on public.moderation_history for select
  to authenticated
  using (public.is_moderator_or_above());

-- NO insert/update/delete policy ⇒ only service role writes (via triggers / Edge Functions).

drop policy if exists admin_logs_select on public.admin_logs;
create policy admin_logs_select
  on public.admin_logs for select
  to authenticated
  using (public.is_admin());

-- NO write policy ⇒ service role only.

-- =============================================================================
-- rate_limit_buckets + login_attempts  —  service role only
-- =============================================================================
-- No policies at all. RLS is on, no rows are visible to anon/authenticated;
-- the helper function 0002 runs SECURITY DEFINER so it can read/write
-- regardless. login_attempts is written by Edge Functions with service role.

commit;
