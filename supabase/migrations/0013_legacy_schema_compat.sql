-- =============================================================================
-- 0013  Legacy schema compatibility
-- ---------------------------------------------------------------------------
-- Some environments already have partial tables from an older schema. This
-- migration adds the canonical columns that the newer migrations expect, so
-- index creation and RLS do not fail with "column ... does not exist".
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- providers
-- -----------------------------------------------------------------------------
alter table if exists public.providers
  add column if not exists city_id uuid references public.cities(id) on delete set null,
  add column if not exists status public.moderation_status not null default 'pending',
  add column if not exists rejection_reason text,
  add column if not exists suspended_at timestamptz,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references auth.users(id) on delete set null,
  add column if not exists deleted_at timestamptz;

-- -----------------------------------------------------------------------------
-- places
-- -----------------------------------------------------------------------------
alter table if exists public.places
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists provider_id uuid references public.providers(id) on delete cascade,
  add column if not exists city_id uuid references public.cities(id) on delete restrict,
  add column if not exists category_id uuid references public.categories(id) on delete restrict,
  add column if not exists slug text,
  add column if not exists name text,
  add column if not exists description text,
  add column if not exists address text,
  add column if not exists location extensions.geography(Point, 4326),
  add column if not exists price_min int,
  add column if not exists price_max int,
  add column if not exists currency public.currency not null default 'EGP',
  add column if not exists budget_bucket text,
  add column if not exists rating_avg numeric(3,2) not null default 0,
  add column if not exists rating_count int not null default 0,
  add column if not exists status public.moderation_status not null default 'pending',
  add column if not exists rejection_reason text,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references auth.users(id) on delete set null,
  add column if not exists suspended_at timestamptz,
  add column if not exists deleted_at timestamptz;

create unique index if not exists places_id_uidx
  on public.places (id);

-- -----------------------------------------------------------------------------
-- place_images
-- -----------------------------------------------------------------------------
alter table if exists public.place_images
  add column if not exists place_id uuid references public.places(id) on delete cascade,
  add column if not exists storage_path text,
  add column if not exists is_cover boolean not null default false,
  add column if not exists alt_text text,
  add column if not exists sort_order int not null default 0,
  add column if not exists created_at timestamptz not null default now();

commit;
