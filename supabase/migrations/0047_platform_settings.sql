-- =============================================================================
-- 0047  Platform settings
-- =============================================================================

begin;

create table if not exists public.platform_settings (
  key text primary key,
  value jsonb not null default '{}'::jsonb,
  description text,
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now()
);

comment on table public.platform_settings is
  'Backend-backed dashboard settings for notifications, moderation SLA and app support metadata.';

alter table public.platform_settings enable row level security;

insert into public.platform_settings (key, value, description)
values
  (
    'notification_preferences',
    jsonb_build_object(
      'new_place', true,
      'new_review', true,
      'new_signup', false,
      'weekly_reports', false
    ),
    'Admin dashboard notification switches.'
  ),
  (
    'moderation_sla',
    jsonb_build_object(
      'place_review_hours', 24,
      'campaign_review_hours', 6
    ),
    'Operational review targets surfaced in the dashboard.'
  ),
  (
    'support_profile',
    jsonb_build_object(
      'app_name_ar', 'رفيق',
      'app_name_en', 'Rafiq App',
      'support_email', 'admin@rafiq.app'
    ),
    'Support contact and app branding metadata.'
  )
on conflict (key) do nothing;

commit;
