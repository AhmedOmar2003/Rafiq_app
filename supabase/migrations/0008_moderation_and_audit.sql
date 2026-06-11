-- =============================================================================
-- 0008  Moderation, audit & rate limits
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- moderation_reports  —  user-filed abuse reports
-- ----------------------------------------------------------------------------
create table if not exists public.moderation_reports (
  id            uuid        primary key default gen_random_uuid(),
  reporter_id   uuid        not null references auth.users(id) on delete set null,
  target_type   public.report_target not null,
  target_id     uuid        not null,
  reason_code   text        not null check (reason_code in
                  ('spam','offensive','off_topic','fake','illegal','harassment','other')),
  details       text        check (details is null or char_length(details) <= 1000),
  status        public.report_status not null default 'open',
  resolved_by   uuid        references auth.users(id) on delete set null,
  resolved_at   timestamptz,
  resolution_note text,
  created_at    timestamptz not null default now()
);

create index if not exists moderation_reports_open_idx
  on public.moderation_reports (created_at) where status = 'open';
create index if not exists moderation_reports_target_idx
  on public.moderation_reports (target_type, target_id);
create index if not exists moderation_reports_reporter_idx
  on public.moderation_reports (reporter_id);

-- ----------------------------------------------------------------------------
-- moderation_history  —  full timeline of every moderation transition
--
-- Append-only. Rows are never updated/deleted (trigger 0019 enforces this).
-- ----------------------------------------------------------------------------
create table if not exists public.moderation_history (
  id           uuid        primary key default gen_random_uuid(),
  target_type  public.report_target not null,    -- place / provider / review / user
  target_id    uuid        not null,
  action       public.moderation_action not null,
  from_status  public.moderation_status,
  to_status    public.moderation_status,
  actor_id     uuid        references auth.users(id) on delete set null,
  reason       text,
  metadata     jsonb       not null default '{}'::jsonb,
  created_at   timestamptz not null default now()
);

create index if not exists moderation_history_target_idx
  on public.moderation_history (target_type, target_id, created_at desc);

-- ----------------------------------------------------------------------------
-- admin_logs  —  generic audit trail for privileged actions
--
-- Written by every Edge Function that performs a write with the service role,
-- and by triggers on moderation tables. Append-only.
-- ----------------------------------------------------------------------------
create table if not exists public.admin_logs (
  id           uuid        primary key default gen_random_uuid(),
  actor_id     uuid        references auth.users(id) on delete set null,
  actor_role   public.app_role,
  action       text        not null check (char_length(action) between 1 and 80),
  entity_type  text        not null check (char_length(entity_type) between 1 and 40),
  entity_id    uuid,
  ip_address   inet,
  user_agent   text,
  payload      jsonb       not null default '{}'::jsonb,    -- diffs / before / after
  created_at   timestamptz not null default now()
);

create index if not exists admin_logs_actor_idx     on public.admin_logs (actor_id, created_at desc);
create index if not exists admin_logs_entity_idx    on public.admin_logs (entity_type, entity_id, created_at desc);
create index if not exists admin_logs_action_idx    on public.admin_logs (action, created_at desc);

-- ----------------------------------------------------------------------------
-- rate_limit_buckets  —  generic per-key sliding window
-- ----------------------------------------------------------------------------
create table if not exists public.rate_limit_buckets (
  bucket        text        not null,            -- e.g. 'submit_place', 'login'
  key           text        not null,            -- e.g. user_id::text or ip
  hits          int         not null default 0,
  window_start  timestamptz not null default now(),
  primary key (bucket, key)
);

create index if not exists rate_limit_buckets_expire_idx
  on public.rate_limit_buckets (window_start);

-- ----------------------------------------------------------------------------
-- login_attempts  —  brute-force surface for the auth layer
-- ----------------------------------------------------------------------------
create table if not exists public.login_attempts (
  id           uuid        primary key default gen_random_uuid(),
  email        extensions.citext not null,
  ip_address   inet,
  user_agent   text,
  succeeded    boolean     not null,
  reason       text,                                       -- 'wrong_password', 'unverified', etc.
  created_at   timestamptz not null default now()
);

create index if not exists login_attempts_email_idx
  on public.login_attempts (email, created_at desc);
create index if not exists login_attempts_ip_idx
  on public.login_attempts (ip_address, created_at desc);

commit;
