-- =============================================================================
-- 0007  Reviews + favorites + notifications
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- reviews
-- ----------------------------------------------------------------------------
create table if not exists public.reviews (
  id           uuid        primary key default gen_random_uuid(),
  place_id     uuid        not null references public.places(id) on delete cascade,
  user_id      uuid        not null references auth.users(id) on delete cascade,
  rating       smallint    not null check (rating between 1 and 5),
  body         text        not null check (char_length(body) between 3 and 2000),

  -- Moderation. Reviews are public by default but get flagged via the
  -- moderation_reports table. Hidden reviews drop out of public reads.
  is_hidden    boolean     not null default false,
  hidden_by    uuid        references auth.users(id) on delete set null,
  hidden_reason text,
  hidden_at    timestamptz,

  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  deleted_at   timestamptz,

  unique (place_id, user_id)                              -- one review per user per place
);

-- Compatibility for older databases that already had reviews but not the
-- canonical moderation columns.
alter table if exists public.reviews
  add column if not exists id uuid default gen_random_uuid(),
  add column if not exists place_id uuid references public.places(id) on delete cascade,
  add column if not exists user_id uuid references auth.users(id) on delete cascade,
  add column if not exists rating smallint,
  add column if not exists body text,
  add column if not exists is_hidden boolean not null default false,
  add column if not exists hidden_by uuid references auth.users(id) on delete set null,
  add column if not exists hidden_reason text,
  add column if not exists hidden_at timestamptz,
  add column if not exists created_at timestamptz default now(),
  add column if not exists updated_at timestamptz default now(),
  add column if not exists deleted_at timestamptz;

create unique index if not exists reviews_id_uidx
  on public.reviews (id);

create index if not exists reviews_place_idx
  on public.reviews (place_id, created_at desc)
  where is_hidden = false and deleted_at is null;
create index if not exists reviews_user_idx
  on public.reviews (user_id, created_at desc)
  where deleted_at is null;
create index if not exists reviews_hidden_idx
  on public.reviews (created_at) where is_hidden;

-- ----------------------------------------------------------------------------
-- favorites
-- ----------------------------------------------------------------------------
create table if not exists public.favorites (
  user_id     uuid        not null references auth.users(id) on delete cascade,
  place_id    uuid        not null references public.places(id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (user_id, place_id)
);

create index if not exists favorites_user_idx on public.favorites (user_id, created_at desc);

-- ----------------------------------------------------------------------------
-- notifications  —  per-user inbox
-- ----------------------------------------------------------------------------
create table if not exists public.notifications (
  id          uuid        primary key default gen_random_uuid(),
  user_id     uuid        not null references auth.users(id) on delete cascade,
  type        public.notification_type not null,
  title       text        not null check (char_length(title) between 1 and 140),
  body        text        check (body is null or char_length(body) <= 1000),
  data        jsonb       not null default '{}'::jsonb,     -- typed payload for deep links
  read_at     timestamptz,
  created_at  timestamptz not null default now()
);

create index if not exists notifications_user_unread_idx
  on public.notifications (user_id, created_at desc)
  where read_at is null;
create index if not exists notifications_user_idx
  on public.notifications (user_id, created_at desc);

commit;
