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
4. Keep the dashboard launch safety card visible on `/dashboard`.
5. Review open `launch_safety_alerts` from the dashboard.
6. Add report-only orphan storage cleanup before deleting files automatically.
7. Contact Supabase support before wide launch auth capacity planning.

## Dashboard Safety Surface

The admin dashboard overview now reads:

- `launch_safety_overview`
- `launch_safety_alerts`

The card intentionally uses owner-friendly Arabic, not technical logs. It shows:

- current launch safety status
- Auth `429` count for the last hour
- signup failures today
- forgot-password failures today
- places pending longer than 24 hours
- campaigns pending longer than 6 hours
- open launch alerts
- a simple recommended action

Open alerts can be marked as:

- `acknowledged`: the admin has seen it
- `resolved`: the issue is handled

No alert action deletes business data.

## Custom SMTP Checklist With Resend

Custom SMTP is required before public registration because Supabase's built-in
email quota is not designed for public onboarding or password-reset spikes.

Recommended provider: **Resend**.

Setup checklist:

1. Create a Resend account.
2. Add the RAFIQ sending domain.
3. Verify DNS records in the domain DNS panel.
4. Add SPF record.
5. Add DKIM records.
6. Add a DMARC record, starting with a monitoring-friendly policy.
7. Create an SMTP credential in Resend.
8. Open Supabase Dashboard → Authentication → Emails / SMTP.
9. Enter SMTP host, port, username, password, sender email, and sender name.
10. Send a test signup email.
11. Send a test password-reset email.
12. Confirm messages arrive in inbox, not spam.
13. Keep old SMTP settings documented so rollback is quick.

Never commit:

- SMTP password
- Resend API key
- DNS private screenshots containing secrets

Rollback plan:

1. Disable Custom SMTP in Supabase or restore previous SMTP values.
2. Pause public registration campaigns.
3. Watch signup/password-reset error counts in the dashboard safety card.

## Cloudflare Turnstile Plan

Turnstile should protect public entry points before broad launch:

- Register
- Forgot Password

Safe architecture:

1. Flutter receives only `TURNSTILE_SITE_KEY`.
2. `TURNSTILE_SECRET_KEY` stays server-side only.
3. A Supabase Edge Function or trusted backend verifies the Turnstile token.
4. Register/Forgot Password calls proceed only after verification succeeds.
5. If keys are missing, current flows continue during beta; public launch should
   not proceed without real keys configured and tested.

Recommended Flutter approach:

- show a small hosted Turnstile challenge page in WebView or external browser
- return the challenge token to the app via deep link or controlled callback
- send the token to a server-side verifier
- do not send the Turnstile secret to Flutter

Required env placeholders:

- `TURNSTILE_SITE_KEY`
- `TURNSTILE_SECRET_KEY`
- `TURNSTILE_VERIFY_URL=https://challenges.cloudflare.com/turnstile/v0/siteverify`

Do not hardcode keys.

## Auto-Alert Rules Proposal

The current dashboard displays alert rows. Automated alert creation should be
added as a Staging-tested scheduled job before public launch.

Recommended report-only rules:

- create warning if Auth `429` last hour is greater than configured threshold
- create warning if signup failures spike
- create warning if forgot-password failures spike
- create warning if places stay pending longer than 24 hours
- create warning if campaigns stay pending longer than 6 hours
- create critical alert if `recommended_mode = high_pressure`

Implementation options:

- Supabase `pg_cron` function that inserts into `launch_safety_alerts`
- Supabase Edge Function scheduled externally
- dashboard-only manual refresh is not enough for public launch

Production cron should not be enabled until it is tested on Staging.

## Final Checklist Before Open Registration

1. Production sign-up/sign-in rate limit changed from about `30` to `90 requests / 5 min`.
2. Do not use `120`; it did not improve Staging results.
3. Custom SMTP is live and tested.
4. Turnstile is live on Register and Forgot Password.
5. Dashboard safety card is visible on `/dashboard`.
6. Launch alerts are visible and can be acknowledged/resolved.
7. Sentry or equivalent error reporting is verified.
8. Supabase support is contacted before major marketing or wide launch.
9. Moderation team is ready for places older than 24 hours and campaigns older than 6 hours.
10. No secrets are committed to GitHub.

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
