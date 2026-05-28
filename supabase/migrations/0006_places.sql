-- =============================================================================
-- 0006  Places + place_images
-- -----------------------------------------------------------------------------
-- The customer-facing catalogue. Public visibility is gated by
-- `status = 'approved' and deleted_at is null` in the RLS policy (see 0014).
-- =============================================================================

begin;

-- public.currency is defined in 0001_extensions_and_enums.sql.

-- ----------------------------------------------------------------------------
-- places
-- ----------------------------------------------------------------------------
create table if not exists public.places (
  id              uuid        primary key default gen_random_uuid(),
  provider_id     uuid        not null references public.providers(id) on delete cascade,
  city_id         uuid        not null references public.cities(id)    on delete restrict,
  category_id     uuid        not null references public.categories(id) on delete restrict,

  slug            text        not null check (slug ~ '^[a-z0-9-]{2,80}$'),
  name            text        not null check (char_length(name) between 2 and 120),
  description     text        not null check (char_length(description) between 10 and 4000),
  address         text        not null check (char_length(address) between 5 and 300),
  location        extensions.geography(Point, 4326),       -- PostGIS

  -- Pricing as a structured pair so search can filter by range without parsing.
  price_min       int         check (price_min is null or price_min >= 0),
  price_max       int         check (price_max is null or price_max >= 0),
  currency        public.currency not null default 'EGP',
  check (price_min is null or price_max is null or price_min <= price_max),

  -- Budget bucket — derived for fast filtering; populated by trigger 0019.
  budget_bucket   text        check (budget_bucket in ('low', 'mid', 'high', 'premium')),

  -- Public-facing aggregates (denormalized; trigger keeps them fresh).
  rating_avg      numeric(3,2) not null default 0 check (rating_avg between 0 and 5),
  rating_count    int          not null default 0 check (rating_count >= 0),

  -- Moderation state — public reads must filter to `approved`.
  status          public.moderation_status not null default 'pending',
  rejection_reason text,
  approved_at     timestamptz,
  approved_by     uuid        references auth.users(id) on delete set null,
  suspended_at   timestamptz,

  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,                            -- soft delete

  unique (provider_id, slug)
);

-- Compatibility for older databases that already had places but not these
-- canonical foreign key columns.
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
  add column if not exists currency public.currency,
  add column if not exists budget_bucket text,
  add column if not exists rating_avg numeric(3,2),
  add column if not exists rating_count int,
  add column if not exists status public.moderation_status,
  add column if not exists rejection_reason text,
  add column if not exists approved_at timestamptz,
  add column if not exists approved_by uuid references auth.users(id) on delete set null,
  add column if not exists suspended_at timestamptz,
  add column if not exists created_at timestamptz,
  add column if not exists updated_at timestamptz,
  add column if not exists deleted_at timestamptz;

create unique index if not exists places_id_uidx
  on public.places (id);

-- Guard: if places already existed, add columns introduced in this migration.
alter table public.places
  add column if not exists location         extensions.geography(Point, 4326),
  add column if not exists price_min        int,
  add column if not exists price_max        int,
  add column if not exists currency         public.currency not null default 'EGP',
  add column if not exists budget_bucket    text,
  add column if not exists rating_avg       numeric(3,2) not null default 0,
  add column if not exists rating_count     int          not null default 0,
  add column if not exists status           public.moderation_status not null default 'pending',
  add column if not exists rejection_reason text,
  add column if not exists approved_at      timestamptz,
  add column if not exists approved_by      uuid references auth.users(id) on delete set null,
  add column if not exists suspended_at     timestamptz,
  add column if not exists deleted_at       timestamptz;

comment on table public.places is
  'The catalogue. Public RLS filters to status=approved AND deleted_at IS NULL.';
comment on column public.places.location is
  'PostGIS Point in WGS84. Index uses geography_gist for radius queries.';

-- Indexes ----------------------------------------------------------------------
-- Primary "browse approved places in a city" path:
create index if not exists places_browse_idx
  on public.places (city_id, category_id, rating_avg desc, created_at desc)
  where status = 'approved' and deleted_at is null;

-- "What needs review" admin queue:
create index if not exists places_moderation_idx
  on public.places (status, created_at)
  where status in ('pending', 'under_review') and deleted_at is null;

create index if not exists places_provider_idx on public.places (provider_id) where deleted_at is null;
create index if not exists places_budget_idx   on public.places (budget_bucket) where status = 'approved' and deleted_at is null;
create index if not exists places_geo_idx      on public.places using gist (location);
create index if not exists places_search_idx   on public.places using gin (name extensions.gin_trgm_ops)
  where status = 'approved' and deleted_at is null;

-- ----------------------------------------------------------------------------
-- place_images  —  ordered, captioned gallery
-- ----------------------------------------------------------------------------
create table if not exists public.place_images (
  id           uuid        primary key default gen_random_uuid(),
  place_id     uuid        not null references public.places(id) on delete cascade,
  storage_path text        not null,                       -- in `place-images` bucket
  is_cover     boolean     not null default false,
  alt_text     text        check (alt_text is null or char_length(alt_text) <= 200),
  sort_order   int         not null default 0,
  created_at   timestamptz not null default now()
);

-- Exactly one cover per place — enforced by a partial unique index.
create unique index if not exists place_images_cover_unique
  on public.place_images (place_id) where is_cover = true;

create index if not exists place_images_place_order_idx
  on public.place_images (place_id, sort_order);

commit;
