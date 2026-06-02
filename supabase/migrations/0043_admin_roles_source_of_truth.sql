-- =============================================================================
-- 0043  admin_roles inside the authoritative migration chain
-- -----------------------------------------------------------------------------
-- Problem:
--   The dashboard depends on public.admin_roles, but the table previously
--   lived only in `admin-dashboard-rafiq-app/supabase_admin_setup.sql`.
--   Fresh environments built from `supabase/migrations/*` alone could miss the
--   table entirely, causing auth drift between staging / production / restore
--   drills.
--
-- Goal:
--   Make `admin_roles` part of the real schema history.
--
-- Design:
--   • RLS stays enabled.
--   • Authenticated users may read ONLY their own admin_roles row. This is
--     enough for the Next.js proxy's "am I an admin?" check.
--   • All writes remain service-role only (dashboard server actions / SQL).
-- =============================================================================

begin;

create table if not exists public.admin_roles (
  user_id      uuid primary key references auth.users(id) on delete cascade,
  role         text not null check (role in ('admin', 'super_admin')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

comment on table public.admin_roles is
  'Back-office roles for the Next.js admin dashboard. Distinct from public.user_roles.';

comment on column public.admin_roles.role is
  'Dashboard access tier. service-role writes only; authenticated users may read only their own row.';

alter table public.admin_roles enable row level security;

drop policy if exists admin_roles_select_self on public.admin_roles;
create policy admin_roles_select_self
  on public.admin_roles for select
  to authenticated
  using (user_id = auth.uid());

drop trigger if exists set_updated_at on public.admin_roles;
create trigger set_updated_at
  before update on public.admin_roles
  for each row execute function public.set_updated_at();

create index if not exists admin_roles_user_idx
  on public.admin_roles (user_id);

commit;
