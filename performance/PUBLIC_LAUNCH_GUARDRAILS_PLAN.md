# RAFIQ Public Launch Guardrails Plan

Date: 2026-06-16
Scope: open registration readiness, self-protection, self-cleaning, and auto-safe operations
Production touched: No

## 1. Current Risk Summary

RAFIQ is stronger than it was during controlled-beta preparation, but open
registration changes the risk profile. The main public-launch risks are:

- password sign-in bursts still hit Supabase Auth `429`
- Production sign-up/sign-in limit is still around `30 requests / 5 min`
- Staging tests showed `90 requests / 5 min` is more defensible than `60`
- `120 requests / 5 min` did not improve the measured bottleneck
- Supabase built-in email quota appears too low for open registration
- public registration needs bot protection before broad marketing
- the owner should not be expected to manually inspect dashboards every day
- moderation queues can grow past SLA if signup/provider activity spikes
- upload interruption can leave orphan files unless cleanup/reporting exists

## 2. Why Open Registration Needs Protection

Invite-only beta can rely on slow waves and manual intervention. Open
registration cannot. A public app needs guardrails before traffic arrives:

- users may retry login repeatedly after a slow or failed attempt
- bots may create accounts or request password reset emails
- providers may submit places/campaigns faster than moderators can review
- built-in email sending limits can block legitimate signups/password resets
- one deployment issue can create repeated runtime errors without the owner
  noticing quickly

The goal is not to replace Supabase Auth. The goal is to reduce avoidable
pressure before requests hit Supabase Auth and to surface safety problems
inside the product.

## 3. Auth Bottleneck Explanation

The bottleneck remains Supabase Auth password-grant throttling.

Observed test history:

- `60/5 min`: admin/provider improved a little, user `3/s` remained unstable
- `90/5 min`: best measured practical setting for controlled beta
- `120/5 min`: no meaningful improvement and sometimes worse

Interpretation:

- the visible sign-up/sign-in setting helps only partly
- another effective IP/project/token bucket probably still applies
- normal session-backed browsing is healthy; repeated password login is the
  risky path

## 4. Recommended Production Rate Limit

For controlled beta or a very soft public opening:

- Recommended Production setting: `90 requests / 5 min`
- Do not use `120` based on current evidence
- Do not disable throttling
- Keep invite/marketing waves slow until real-user login metrics are clean

For a true public launch:

- Contact Supabase support before relying on password-grant capacity
- Retest with realistic distributed traffic after any support-approved change

## 5. Custom SMTP Recommendation

Custom SMTP is required before public launch if email confirmation, OTP, or
password reset emails are part of the public flow.

Recommended provider: **Resend**.

Why:

- simple setup for small teams
- strong developer UX
- good deliverability once DNS is configured
- easier than Amazon SES for a non-technical owner

Required Supabase SMTP settings:

- SMTP host
- SMTP port
- SMTP username
- SMTP password
- sender email
- sender name

DNS requirements:

- SPF
- DKIM
- DMARC

Manual setup required:

1. Create a Resend account.
2. Verify the sending domain.
3. Add DNS records.
4. Configure Supabase Authentication email SMTP.
5. Send test signup and password reset emails.
6. Confirm deliverability before opening registration.

No SMTP credentials should ever be committed.

## 6. Bot Protection Recommendation

Recommended option: **Cloudflare Turnstile**.

Why:

- privacy-friendly compared with reCAPTCHA
- lower user friction
- good fit for public signup and forgot-password protection
- free tier is practical for launch

Minimum launch surfaces:

- Register
- Forgot Password

Optional:

- Login, only if abuse appears or implementation is low-friction

Implementation notes:

- client receives only the Turnstile site key
- secret key must remain server-side
- verification should happen in a Supabase Edge Function or trusted backend
- Flutter support needs either WebView-based challenge or a small hosted
  challenge page/deep-link pattern

Required env names:

- `TURNSTILE_SITE_KEY`
- `TURNSTILE_SECRET_KEY`
- `TURNSTILE_VERIFY_URL=https://challenges.cloudflare.com/turnstile/v0/siteverify`

Because external keys are required, this phase documents the safe integration
path and does not commit real keys.

## 7. Auto-Cleanup Plan

Implemented now:

- report-only guardrail tables
- safety overview view
- no destructive Production cleanup

Existing cleanup:

- account deletion Edge Function cleans `place-images` and `campaign-assets`
  tied to deleted users/providers
- analytics rollups are scheduled through `pg_cron`

Recommended next cleanup jobs:

- report orphan `place-images` objects older than 24 hours
- report orphan `campaign-assets` objects older than 24 hours
- keep auth/security event logs for 90 days, then aggregate/delete old rows
- report pending places older than 24 hours
- report pending campaigns older than 6 hours
- report stale upload prefixes before deleting anything

Risk rule:

- business data should be report-only or soft-cleaned first
- physical deletion should only apply to clearly orphaned temporary files

## 8. Auto-Alert Plan

Implemented foundation:

- `auth_security_events`
- `launch_safety_alerts`
- `launch_safety_overview`
- `launch_safety` platform setting
- dashboard safety card on `/dashboard`
- dashboard list of open/acknowledged launch alerts
- alert acknowledge/resolve server actions with admin audit logging

Alert triggers to add as scheduled jobs or dashboard server actions:

- Auth `429` over threshold in the last hour
- login failure rate over threshold
- signup failure spike
- forgot-password failure spike
- pending places older than 24 hours
- pending campaigns older than 6 hours
- open critical launch alerts
- upload/storage errors
- runtime errors from Sentry/Vercel

Suggested owner-friendly alert channels:

- dashboard banner first
- email alert second
- Telegram/Slack/webhook later if needed

Recommended Staging-first scheduled rule:

1. Read `launch_safety_overview` every 10 minutes.
2. Insert a `launch_safety_alerts` row only when a threshold is crossed.
3. Deduplicate by `metric_key` and open status to avoid alert spam.
4. Do not send email until Custom SMTP is configured and tested.
5. Promote the scheduled job to Production only after Staging creates the
   expected report-only alerts.

## 9. Launch Safety Mode Plan

The `launch_safety` platform setting supports these modes:

- `normal`
- `busy`
- `high_pressure`
- `maintenance_lite`

Recommended behavior:

- `normal`: regular UI copy
- `busy`: calmer retry copy, avoid aggressive resend prompts
- `high_pressure`: stronger cooldown messaging, require bot challenge for
  signup/reset, slow invite/marketing pushes
- `maintenance_lite`: browsing remains available, new submissions/uploads can
  show delayed-review messaging

Core browsing should not be disabled by safety mode.

## 10. Files Changed

Flutter:

- `lib/service/auth_service.dart`
- `lib/auth/register/register_screen.dart`
- `lib/auth/forget password/forget_password.dart`
- `lib/auth/forget password/reset_password.dart`

Database:

- `supabase/migrations/0067_public_launch_guardrails.sql`

Docs/reports:

- `performance/PUBLIC_LAUNCH_GUARDRAILS_PLAN.md`
- `docs/PUBLIC_LAUNCH_GUARDRAILS.md`
- `docs/CUSTOM_SMTP_RESEND_CHECKLIST.md`
- `docs/TURNSTILE_READINESS_PLAN.md`

Dashboard:

- `admin-dashboard-rafiq-app/src/app/dashboard/page.tsx`
- `admin-dashboard-rafiq-app/src/app/dashboard/page.module.css`
- `admin-dashboard-rafiq-app/src/app/dashboard/actions.ts`

## 11. Migrations Added

`0067_public_launch_guardrails.sql`

Adds:

- `auth_security_events`
- `record_auth_security_event(...)`
- `launch_safety_alerts`
- `launch_safety` platform setting
- `launch_safety_overview` view

The migration is report-only and does not change auth settings.

Validation:

- Applied to Supabase Staging `znvxkqsjmqdfhnrqohzp`
- `record_auth_security_event(...)` smoke test passed
- `launch_safety_overview` returned a single safety summary row
- Production was not touched

## 12. Env Vars Required

Future captcha:

- `TURNSTILE_SITE_KEY`
- `TURNSTILE_SECRET_KEY`
- `TURNSTILE_VERIFY_URL`

SMTP:

- SMTP host
- SMTP port
- SMTP username
- SMTP password
- sender email
- sender name

Monitoring:

- `SENTRY_DSN` for Flutter release builds
- dashboard Sentry DSN/env if dashboard Sentry is expected

No credentials should be committed.

## 13. What Still Needs Manual Setup

- Change Production sign-up/sign-in limit to `90/5 min` if approved
- Configure Custom SMTP
- Configure Turnstile keys and backend verification
- Confirm Sentry DSN is live for Flutter and dashboard
- Add email notification wiring from `launch_safety_overview`
- Add Staging-tested scheduled alert creation job
- Contact Supabase support before wide launch

## 14. What Is Safe For Controlled Beta

Safe if:

- Production Auth sign-up/sign-in is moved to `90/5 min`
- invites/marketing are gradual
- Custom SMTP is configured before large signup waves
- Sentry is enabled or logs are checked during the early period
- moderation is staffed

## 15. What Is Required Before Full Public Launch

Required:

- Custom SMTP live and tested
- Turnstile or equivalent bot protection on Register and Forgot Password
- Production auth limit decision finalized with Supabase support
- automatic alerting from `launch_safety_overview`
- storage orphan reporting/cleanup job
- moderation SLA alerts
- Sentry error alerts tested

Final verdict:

- Controlled beta / soft opening: possible with guardrails and `90/5 min`
- Wide public launch: not yet

## 16. Validation Run

- `flutter analyze`: passed
- `flutter test`: passed, 22 tests
- dashboard `npm run build`: passed

## 17. Dashboard Safety Surface

The admin overview now surfaces public-launch safety in owner-friendly Arabic.

It reads:

- `launch_safety_overview`
- open and acknowledged rows from `launch_safety_alerts`

Visible signals:

- current recommended launch mode
- Auth `429` events in the last hour
- signup failures today
- forgot-password failures today
- pending places older than 24 hours
- pending campaigns older than 6 hours
- open launch alerts
- recommended action

Alert actions:

- `acknowledged`: admin saw the alert
- `resolved`: issue was handled

Both actions are non-destructive and logged in `admin_logs`.

## 18. Custom SMTP Setup Checklist

Recommended provider: Resend.

Owner checklist:

1. Create Resend account.
2. Verify sending domain.
3. Add DNS SPF, DKIM, and DMARC records.
4. Create SMTP credentials in Resend.
5. Configure Supabase Authentication SMTP settings.
6. Send a signup email test.
7. Send a password reset email test.
8. Confirm inbox deliverability.
9. Keep rollback values available.

Never commit SMTP credentials.

## 19. Turnstile Integration Plan

Target screens:

- Register
- Forgot Password

Safe implementation:

- Flutter uses only `TURNSTILE_SITE_KEY`
- `TURNSTILE_SECRET_KEY` remains server-side
- a Supabase Edge Function or trusted backend verifies the token
- Register/Forgot Password continue only after a valid token for public launch

Current status:

- no real keys committed
- no Flutter flow is broken when keys are absent
- implementation remains blocked on real Turnstile site/secret keys and a
  server-side verifier

## 20. Production Readiness Checklist

Before opening registration publicly:

1. Set Production sign-up/sign-in limit to `90 requests / 5 min`.
2. Do not use `120`.
3. Custom SMTP live and tested.
4. Turnstile live on Register and Forgot Password.
5. Dashboard safety card visible.
6. Alerts visible and actionable.
7. Sentry/error reporting verified.
8. Supabase support contacted before major marketing/wide launch.
