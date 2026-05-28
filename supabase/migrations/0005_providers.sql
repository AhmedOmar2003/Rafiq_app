-- =============================================================================
-- 0005  Providers & KYC
-- -----------------------------------------------------------------------------
--   providers           One business profile per provider user.
--   provider_documents  KYC docs in the PRIVATE storage bucket.
--   provider_requests   Onboarding submissions, reviewed by moderators.
-- =============================================================================

begin;

-- ----------------------------------------------------------------------------
-- providers
-- ----------------------------------------------------------------------------
create table if not exists public.providers (
  id              uuid        primary key default gen_random_uuid(),
  owner_id        uuid        not null unique references auth.users(id) on delete cascade,
  business_name   text        not null check (char_length(business_name) between 2 and 120),
  legal_name      text                 check (legal_name is null or char_length(legal_name) <= 120),
  description     text                 check (description is null or char_length(description) <= 2000),
  contact_email   citext      not null,
  contact_phone   text                 check (contact_phone is null or contact_phone ~ '^\+?[0-9]{6,15}$'),
  website_url     text                 check (website_url is null or website_url ~* '^https?://'),
  city_id         uuid        references public.cities(id) on delete set null,
  status          public.moderation_status not null default 'pending',
  rejection_reason text,                                            -- last reason (history is in moderation_history)
  suspended_at    timestamptz,
  approved_at     timestamptz,
  approved_by     uuid        references auth.users(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz                                       -- soft delete
);

-- Compatibility for older databases that already had providers but not city_id.
alter table if exists public.providers
  add column if not exists city_id uuid references public.cities(id) on delete set null;

comment on table public.providers is
  'Business profile. owner_id MUST also have the `provider` role in user_roles.';

create index if not exists providers_status_idx     on public.providers (status) where deleted_at is null;
create index if not exists providers_owner_idx      on public.providers (owner_id);
create index if not exists providers_city_idx       on public.providers (city_id);
create index if not exists providers_search_idx     on public.providers using gin (business_name extensions.gin_trgm_ops);

-- ----------------------------------------------------------------------------
-- provider_documents  —  private KYC artefacts (national ID, commercial reg, ...)
--
-- Files live in the PRIVATE `provider-documents` storage bucket. This row
-- just stores the path + metadata; URL access goes through signed URLs from
-- an Edge Function with role check.
-- ----------------------------------------------------------------------------
do $$ begin
  create type public.kyc_doc_type as enum
    ('national_id', 'commercial_register', 'tax_card', 'lease', 'other');
exception when duplicate_object then null; end $$;

create table if not exists public.provider_documents (
  id           uuid        primary key default gen_random_uuid(),
  provider_id  uuid        not null references public.providers(id) on delete cascade,
  doc_type     public.kyc_doc_type not null,
  storage_path text        not null,                       -- bucket-relative
  mime_type    text        not null check (mime_type ~ '^(application/pdf|image/(png|jpe?g|webp))$'),
  size_bytes   int         not null check (size_bytes > 0 and size_bytes <= 10485760), -- 10 MB
  verified     boolean     not null default false,
  verified_by  uuid        references auth.users(id) on delete set null,
  verified_at  timestamptz,
  notes        text,
  created_at   timestamptz not null default now()
);

create index if not exists provider_documents_provider_idx on public.provider_documents (provider_id);
create index if not exists provider_documents_unverified_idx
  on public.provider_documents (created_at) where verified = false;

-- ----------------------------------------------------------------------------
-- provider_requests  —  onboarding submission with state machine
--
-- Distinct from the `providers` row so the provider can resubmit / amend
-- after a rejection without polluting the canonical record.
-- ----------------------------------------------------------------------------
create table if not exists public.provider_requests (
  id              uuid        primary key default gen_random_uuid(),
  provider_id     uuid        not null references public.providers(id) on delete cascade,
  submitted_by    uuid        not null references auth.users(id) on delete set null,
  status          public.moderation_status not null default 'pending',
  payload         jsonb       not null,                    -- snapshot of edits
  reviewer_id     uuid        references auth.users(id) on delete set null,
  reviewer_notes  text,
  rejection_reason text,
  reviewed_at     timestamptz,
  created_at      timestamptz not null default now()
);

create index if not exists provider_requests_status_idx
  on public.provider_requests (status, created_at);
create index if not exists provider_requests_provider_idx
  on public.provider_requests (provider_id, created_at desc);

commit;
