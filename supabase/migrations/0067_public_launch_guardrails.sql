-- =============================================================================
-- 0067  Public launch guardrails (report-only safety infrastructure)
-- =============================================================================
--
-- This migration does not change Supabase Auth behaviour and does not delete
-- business data. It adds safe, service-readable signals that help RAFIQ detect
-- public-launch pressure without exposing passwords, service keys, or plaintext
-- app-user emails.

begin;

create table if not exists public.auth_security_events (
  id uuid primary key default gen_random_uuid(),
  event_type text not null check (
    event_type in (
      'login_failed',
      'signup_failed',
      'forgot_password_failed',
      'otp_verify_failed',
      'rate_limited'
    )
  ),
  source text not null check (source in ('flutter_app', 'admin_dashboard', 'edge_function')),
  email_hash text,
  role text,
  status text not null check (status in ('failed', 'rate_limited', 'blocked')),
  reason text,
  user_agent text,
  ip_address inet,
  created_at timestamptz not null default now()
);

comment on table public.auth_security_events is
  'Low-PII auth pressure events. App emails are SHA-256 hashed by RPC; no passwords or secrets.';
comment on column public.auth_security_events.email_hash is
  'Hex SHA-256 hash of the normalized email. Plaintext email is intentionally not stored.';
comment on column public.auth_security_events.ip_address is
  'Server-side only when available; client RPC calls leave this null.';

create index if not exists auth_security_events_created_idx
  on public.auth_security_events (created_at desc);
create index if not exists auth_security_events_type_created_idx
  on public.auth_security_events (event_type, created_at desc);
create index if not exists auth_security_events_email_created_idx
  on public.auth_security_events (email_hash, created_at desc)
  where email_hash is not null;
create index if not exists auth_security_events_status_created_idx
  on public.auth_security_events (status, created_at desc);

alter table public.auth_security_events enable row level security;

-- No direct anon/auth read policies. Writes should go through the bounded RPC
-- below or through dashboard server actions with the service role.

create or replace function public.record_auth_security_event(
  _event_type text,
  _source text,
  _email text default null,
  _status text default 'failed',
  _reason text default null,
  _role text default null,
  _user_agent text default null
)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  _normalized_email text;
  _email_hash text;
  _accepted boolean;
begin
  if _event_type not in (
    'login_failed',
    'signup_failed',
    'forgot_password_failed',
    'otp_verify_failed',
    'rate_limited'
  ) then
    return;
  end if;

  if _source not in ('flutter_app', 'admin_dashboard', 'edge_function') then
    return;
  end if;

  if _status not in ('failed', 'rate_limited', 'blocked') then
    _status := 'failed';
  end if;

  _normalized_email := nullif(lower(trim(coalesce(_email, ''))), '');
  if _normalized_email is not null then
    _email_hash := encode(digest(_normalized_email, 'sha256'), 'hex');
  end if;

  -- Prevent a broken client from turning the logging endpoint into its own
  -- write-amplification problem. This intentionally uses source+hash, not
  -- plaintext email.
  _accepted := public.consume_rate_limit(
    'auth_security_event',
    coalesce(_source, 'unknown') || ':' || coalesce(_email_hash, 'anonymous'),
    20,
    interval '5 minutes'
  );

  if not _accepted then
    return;
  end if;

  insert into public.auth_security_events (
    event_type,
    source,
    email_hash,
    role,
    status,
    reason,
    user_agent
  )
  values (
    _event_type,
    _source,
    _email_hash,
    nullif(left(coalesce(_role, ''), 40), ''),
    _status,
    nullif(left(coalesce(_reason, ''), 240), ''),
    nullif(left(coalesce(_user_agent, ''), 240), '')
  );
end;
$$;

revoke all on function public.record_auth_security_event(text, text, text, text, text, text, text)
  from public;
grant execute on function public.record_auth_security_event(text, text, text, text, text, text, text)
  to anon, authenticated, service_role;

create table if not exists public.launch_safety_alerts (
  id uuid primary key default gen_random_uuid(),
  severity text not null check (severity in ('info', 'warning', 'critical')),
  category text not null check (
    category in (
      'auth',
      'email',
      'storage',
      'moderation',
      'campaigns',
      'runtime',
      'database'
    )
  ),
  title text not null,
  body text not null,
  metric_key text,
  metric_value numeric,
  threshold numeric,
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved')),
  created_at timestamptz not null default now(),
  acknowledged_at timestamptz,
  resolved_at timestamptz
);

comment on table public.launch_safety_alerts is
  'Report-only launch guardrail alerts for dashboard surfacing. No automatic destructive action.';

create index if not exists launch_safety_alerts_status_created_idx
  on public.launch_safety_alerts (status, created_at desc);
create index if not exists launch_safety_alerts_category_created_idx
  on public.launch_safety_alerts (category, created_at desc);

alter table public.launch_safety_alerts enable row level security;

insert into public.platform_settings (key, value, description)
values (
  'launch_safety',
  jsonb_build_object(
    'mode', 'normal',
    'auth_signin_rate_limit_per_5_min_recommended', 90,
    'auth_signin_rate_limit_per_5_min_max_tested_useful', 90,
    'auth_429_warning_threshold_per_hour', 10,
    'login_failure_warning_rate_percent', 5,
    'place_review_hours', 24,
    'campaign_review_hours', 6,
    'custom_smtp_required_for_public_launch', true,
    'bot_challenge_required_for_public_launch', true,
    'updated_by', 'migration_0067'
  ),
  'Public launch safety thresholds and current operating mode.'
)
on conflict (key) do update
set value = excluded.value,
    description = excluded.description,
    updated_at = now();

create or replace view public.launch_safety_overview
with (security_invoker = true)
as
with auth_today as (
  select
    count(*) filter (where created_at >= now() - interval '1 hour' and status = 'rate_limited') as auth_429_last_hour,
    count(*) filter (where created_at >= current_date) as auth_events_today,
    count(*) filter (where created_at >= current_date and event_type = 'signup_failed') as signup_failures_today,
    count(*) filter (where created_at >= current_date and event_type = 'forgot_password_failed') as forgot_password_failures_today
  from public.auth_security_events
),
admin_login_today as (
  select
    count(*) filter (where created_at >= current_date) as dashboard_login_attempts_today,
    count(*) filter (where created_at >= current_date and succeeded = false) as dashboard_login_failures_today,
    count(*) filter (where created_at >= current_date and reason = 'supabase_rate_limited') as dashboard_auth_429_today
  from public.login_attempts
),
queues as (
  select
    (select count(*) from public.places
      where status in ('pending', 'under_review')
        and created_at < now() - interval '24 hours') as pending_places_over_24h,
    (select count(*) from public.promotional_campaigns
      where status = 'pending_review'
        and created_at < now() - interval '6 hours') as pending_campaigns_over_6h,
    (select count(*) from public.places
      where edit_request_status = 'pending') as pending_place_edit_requests,
    (select count(*) from public.promotional_campaigns
      where edit_request_status = 'pending') as pending_campaign_edit_requests
),
open_alerts as (
  select
    count(*) filter (where status = 'open') as open_launch_alerts,
    count(*) filter (where status = 'open' and severity = 'critical') as critical_launch_alerts
  from public.launch_safety_alerts
),
safety as (
  select value from public.platform_settings where key = 'launch_safety'
)
select
  coalesce(safety.value->>'mode', 'normal') as launch_safety_mode,
  auth_today.auth_429_last_hour,
  auth_today.auth_events_today,
  auth_today.signup_failures_today,
  auth_today.forgot_password_failures_today,
  admin_login_today.dashboard_login_attempts_today,
  admin_login_today.dashboard_login_failures_today,
  admin_login_today.dashboard_auth_429_today,
  queues.pending_places_over_24h,
  queues.pending_campaigns_over_6h,
  queues.pending_place_edit_requests,
  queues.pending_campaign_edit_requests,
  open_alerts.open_launch_alerts,
  open_alerts.critical_launch_alerts,
  case
    when open_alerts.critical_launch_alerts > 0
      or auth_today.auth_429_last_hour >= coalesce((safety.value->>'auth_429_warning_threshold_per_hour')::int, 10)
      then 'high_pressure'
    when queues.pending_places_over_24h > 0
      or queues.pending_campaigns_over_6h > 0
      or open_alerts.open_launch_alerts > 0
      then 'busy'
    else coalesce(safety.value->>'mode', 'normal')
  end as recommended_mode
from auth_today, admin_login_today, queues, open_alerts, safety;

comment on view public.launch_safety_overview is
  'Single-row report-only launch safety summary for admin dashboard and operations.';

commit;
