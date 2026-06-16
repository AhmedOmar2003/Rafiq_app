# RAFIQ Public Launch Guardrails

RAFIQ keeps Supabase Auth as the source of truth. The launch guardrails around
it are designed to reduce avoidable pressure, detect abuse, and make launch
issues visible without storing passwords or exposing secrets.

## Production Defaults To Use Before Soft Public Opening

- Supabase Auth sign-up/sign-in limit: recommended `90 requests / 5 min`
- Do not use `120 requests / 5 min` based on Staging results
- Keep retry/cooldown UX enabled in the Flutter app
- Keep dashboard login IP/email throttling enabled

## Required Before Open Registration At Scale

1. Configure Custom SMTP in Supabase Auth.
2. Add Cloudflare Turnstile to Register and Forgot Password.
3. Enable Sentry DSNs for release builds and dashboard if used.
4. Surface `launch_safety_overview` in the admin dashboard as a banner/card.
5. Add report-only orphan storage cleanup before deleting files automatically.
6. Contact Supabase support before wide launch auth capacity planning.

## Do Not Commit

- SMTP passwords
- Turnstile secret keys
- Supabase service role keys
- Sentry auth tokens
- real user exports

## Guardrail Tables

Migration `0067_public_launch_guardrails.sql` adds:

- `auth_security_events`
- `launch_safety_alerts`
- `launch_safety_overview`

These are report-only launch safety signals. They do not disable browsing, do
not replace Supabase Auth, and do not delete business data.
