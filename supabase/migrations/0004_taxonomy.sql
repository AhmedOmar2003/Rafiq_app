-- =============================================================================
-- 0004  Taxonomy — cities & categories
-- -----------------------------------------------------------------------------
-- Reference data. Public read; only admins can mutate.
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- cities
-- ----------------------------------------------------------------------------
create table if not exists public.cities (
  id          uuid        primary key default gen_random_uuid(),
  slug        text        not null unique check (slug ~ '^[a-z0-9-]{2,40}$'),
  name_ar     text        not null,
  name_en     text        not null,
  region_ar   text,
  region_en   text,
  is_active   boolean     not null default true,
  sort_order  int         not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists cities_active_sort_idx on public.cities (is_active, sort_order);
create index if not exists cities_name_ar_trgm_idx on public.cities using gin (name_ar extensions.gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- categories  (activity types: food / culture / tourism / entertainment ...)
-- ----------------------------------------------------------------------------
create table if not exists public.categories (
  id          uuid        primary key default gen_random_uuid(),
  slug        text        not null unique check (slug ~ '^[a-z0-9-]{2,40}$'),
  name_ar     text        not null,
  name_en     text        not null,
  icon_key    text,                                                 -- references illustration set
  parent_id   uuid        references public.categories(id) on delete set null,
  is_active   boolean     not null default true,
  sort_order  int         not null default 0,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create index if not exists categories_parent_idx       on public.categories (parent_id);
create index if not exists categories_active_sort_idx  on public.categories (is_active, sort_order);

commit;
