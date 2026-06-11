-- =============================================================================
-- 0003  Profiles + role separation
-- -----------------------------------------------------------------------------
-- WHY two tables?
--
-- A common mistake is putting `role` on `profiles` and writing an RLS policy
-- like `update on profiles using (auth.uid() = id)`. That lets the user set
-- their own role to 'admin'.
--
-- We solve this with a dedicated `user_roles` table. Profiles are owner-writable
-- for personal data; user_roles is writable ONLY by service role / super_admin.
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- profiles  —  display info kept in sync with auth.users
-- ----------------------------------------------------------------------------
create table if not exists public.profiles (
  id           uuid        primary key references auth.users(id) on delete cascade,
  full_name    text        not null check (char_length(full_name) between 1 and 80),
  email        extensions.citext not null unique check (char_length(email) <= 254),
  phone        text                 check (phone is null or phone ~ '^\+?[0-9]{6,15}$'),
  avatar_url   text                 check (avatar_url is null or avatar_url ~* '^https?://'),
  locale       text        not null default 'ar-EG',
  email_verified_at timestamptz,
  is_disabled  boolean     not null default false,    -- soft account lock
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz                                          -- soft delete
);

comment on table public.profiles is
  'Public-facing user profile. One row per auth.users. Owner-writable for personal fields.';
comment on column public.profiles.is_disabled is
  'Set true by an admin to soft-lock the account without deleting the auth row.';

-- Guard: if profiles already existed before this migration, ensure the
-- is_disabled column is present (CREATE TABLE IF NOT EXISTS skips it).
alter table public.profiles
  add column if not exists is_disabled boolean not null default false,
  add column if not exists deleted_at  timestamptz;

create index if not exists profiles_email_idx     on public.profiles (email);
create index if not exists profiles_deleted_idx   on public.profiles (deleted_at) where deleted_at is not null;
create index if not exists profiles_disabled_idx  on public.profiles (is_disabled) where is_disabled;

-- ----------------------------------------------------------------------------
-- user_roles  —  authoritative source for RBAC
-- ----------------------------------------------------------------------------
create table if not exists public.user_roles (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  role        public.app_role not null,
  granted_by  uuid        references auth.users(id) on delete set null,
  granted_at  timestamptz not null default now(),
  revoked_at  timestamptz,                                          -- soft revoke
  unique (user_id, role)
);

comment on table public.user_roles is
  'Authoritative RBAC table. Users CANNOT modify this — only service role / super_admin.';
comment on column public.user_roles.revoked_at is
  'Setting this revokes the role; we keep the row for audit history.';

create index if not exists user_roles_user_idx on public.user_roles (user_id) where revoked_at is null;
create index if not exists user_roles_role_idx on public.user_roles (role)    where revoked_at is null;

-- ----------------------------------------------------------------------------
-- Bootstrap the helper functions from 0002 now that user_roles exists.
-- Re-create so PL/pgSQL plan caches refresh against the new table.
-- ----------------------------------------------------------------------------
create or replace function public.has_role(_role public.app_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role    = _role
      and ur.revoked_at is null
  );
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('admin', 'super_admin')
      and ur.revoked_at is null
  );
$$;

create or replace function public.is_moderator_or_above()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role in ('moderator', 'admin', 'super_admin')
      and ur.revoked_at is null
  );
$$;

create or replace function public.is_provider()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists(
    select 1
    from public.user_roles ur
    where ur.user_id = auth.uid()
      and ur.role = 'provider'
      and ur.revoked_at is null
  );
$$;

-- Convenience: highest active role held by the current user (for UI gating).
create or replace function public.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = ''
as $$
  select role
  from public.user_roles
  where user_id = auth.uid()
    and revoked_at is null
  order by case role
    when 'super_admin' then 1
    when 'admin'       then 2
    when 'moderator'   then 3
    when 'provider'    then 4
    when 'user'        then 5
  end
  limit 1;
$$;

commit;
