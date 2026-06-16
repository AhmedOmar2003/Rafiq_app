# RAFIQ Beta Auth And Monitoring Plan

Date: 2026-06-16
Scope: controlled beta auth hardening and launch guardrails
Production data touched: No

## 1. Current Beta Readiness

RAFIQ is ready for a controlled beta, not a wide launch.

The latest performance validation showed:

- public browse and session-backed reads are healthy for a controlled beta
- place details improved after the context RPC work
- independent small write/moderation bursts are stable on Staging
- repeated password login remains the first operational bottleneck

## 2. Why Wide Launch Is Still Blocked

Wide launch is still blocked by Supabase Auth password-grant throttling.

The failure mode is not normal in-app navigation. It appears when password
login is repeated in bursts. Diversifying test accounts did not remove the
problem, and instrumented failures were HTTP `429`.

This means a public launch, campaign spike, or retry storm can fail at login
before browse/detail pages look unhealthy.

## 3. Auth Strategy Audit

### Flutter app

1. **Session reuse**
   - The app initializes Supabase once through `AuthService.ensureSupabaseInitialized()`.
   - `AuthGate` checks `Supabase.instance.client.auth.currentSession`.
   - Normal navigation does not call password login repeatedly.

2. **Normal browse**
   - Users can browse with an existing session.
   - Public browse/details do not require repeated password login.

3. **Startup behavior**
   - Startup finalizes pending Google OAuth and loads local role/profile state.
   - It does not intentionally re-authenticate with password on every launch.

4. **Repeated login risk**
   - Repeated taps or Enter submissions on the login form could trigger more
     than one auth attempt while a request was already pending.
   - This is now blocked in the login screen.

5. **HTTP 429 behavior**
   - Supabase `429` and rate-limit-like errors now map to:
     `في محاولات تسجيل دخول كتير دلوقتي. استنى دقيقة وجرب تاني.`
   - The app does not auto-retry password login aggressively.
   - The login screen applies a one-minute local retry delay after a rate-limit
     message.

### Admin dashboard

1. **Session reuse**
   - The dashboard uses `@supabase/ssr` cookies in
     `admin-dashboard-rafiq-app/src/lib/supabase/server.ts`.
   - The proxy checks the current user and admin role from the existing cookie
     session.
   - Dashboard page navigation does not password-login repeatedly.

2. **Admin throttling**
   - `admin-dashboard-rafiq-app/src/app/login/actions.ts` applies existing
     email and IP rate limits before Supabase Auth.
   - These limits were preserved.

3. **Repeated login risk**
   - The login form now disables all controls while pending and ignores
     duplicate submits during the same pending action.

4. **HTTP 429 behavior**
   - Supabase auth `429` is separated from invalid credentials.
   - Admins now see:
     `تم إيقاف محاولات الدخول مؤقتًا للحماية. حاول مرة أخرى بعد قليل.`

## 4. Safe Auth UX Improvements Made

Implemented:

- duplicate login submission guard in Flutter login
- visible loading state remains active during Flutter login
- friendly Flutter `429`/rate-limit message
- one-minute local retry delay after Flutter rate-limit feedback
- no aggressive auto-retry
- admin login fieldset disabled while pending
- duplicate admin form submit prevention
- dashboard Supabase `429` handled separately from invalid credentials
- existing admin email/IP throttling preserved

Not changed:

- Supabase Auth was not bypassed
- auth throttling was not weakened
- service role keys were not exposed
- Production data was not touched

## 5. Files Changed

Flutter:

- `../lib/auth/login/login_screen.dart`
- `../lib/core/utils/app_error_formatter.dart`
- `../lib/core/utils/app_microcopy.dart`
- `../lib/service/auth_service.dart`

Admin dashboard:

- `../admin-dashboard-rafiq-app/src/app/login/actions.ts`
- `../admin-dashboard-rafiq-app/src/app/login/page.tsx`
- `../admin-dashboard-rafiq-app/src/app/login/page.module.css`

Report:

- `BETA_AUTH_AND_MONITORING_PLAN.md`

## 6. Tests Run

- `flutter analyze`: passed, no issues
- `flutter test`: passed, 22 tests
- dashboard `npm run build`: passed

## 7. Beta Launch Limits

Recommended starting limits for controlled beta:

- users: 100 to 200 invited users
- providers: 20 to 40 providers
- admins/moderators: 2 to 4 operators
- campaigns: keep campaign creation invite-only at first
- daily onboarding bursts: avoid mass invites; send in small waves

Escalate beyond these only after auth, storage, detail pages, and moderation
queues stay healthy for several days.

## 8. Daily Metrics To Watch

Watch daily during beta:

- Supabase Auth `429` count
- login failure rate
- successful login count
- password reset request count
- dashboard login failures by reason
- Supabase database errors
- Storage upload errors
- Vercel runtime errors
- Flutter crash/error events
- slow place details
- slow provider hub
- failed campaign creation
- failed moderation actions
- moderation queue age
- pending place count
- pending campaign count
- image upload p95 if available

## 9. Alert Thresholds

Treat these as dangerous:

- auth `429` appears repeatedly within the same hour
- login failure rate stays above 5% for real users
- place details p95 goes above 1 second for sustained periods
- image upload failures exceed 2% in a day
- moderation queue has items older than 24 hours for places
- campaign review queue has items older than 6 hours
- Vercel runtime errors increase after deploy
- dashboard actions fail for admins

Acceptable controlled-beta target:

- login failure rate below 2% for real users
- no recurring Supabase Auth `429` during normal invite waves
- no unresolved moderation queue breach

## 10. Incident Playbook

### If login `429` increases

1. Pause new invites.
2. Check whether users are retrying repeatedly.
3. Ask users to wait one minute before retrying.
4. Confirm Supabase Auth rate-limit settings.
5. Review dashboard `login_attempts` reasons.
6. Do not weaken security without a deliberate owner decision.

### If place details slow down

1. Check Vercel runtime errors.
2. Check Supabase database latency.
3. Confirm `get_place_details_context` is healthy.
4. Check image size and storage response times.
5. Temporarily avoid marketing pushes to a single place.

### If image uploads fail

1. Check Storage errors and bucket policy logs.
2. Confirm file MIME and size.
3. Ask providers to retry with JPG/PNG/WebP under the configured size limit.
4. Watch for orphan files if an upload is interrupted.

### If moderation queues grow

1. Add admin review coverage.
2. Prioritize oldest pending places and campaigns.
3. Pause provider onboarding if review SLAs are breached.
4. Keep rejection reasons clear so appeals are easier to review.

## 11. Monitoring Checklist

Supabase:

- Auth errors and `429`
- database errors
- RPC errors
- Storage upload failures
- slow queries for details/provider/admin surfaces

Vercel dashboard:

- runtime errors
- failed Server Actions
- slow dashboard pages
- login action failures
- moderation action failures

Flutter app:

- crash/error tracking events
- login failures
- session-expired messages
- place-details errors
- provider hub errors
- image upload errors
- campaign creation errors

Operational queues:

- pending places over 24 hours
- pending campaigns over 6 hours
- failed appeals/resolutions
- repeated reports against one provider/place

## 12. Sentry And Analytics Status

The project has Sentry package wiring in the dashboard dependencies and Flutter
code paths that can use runtime DSN configuration. Before wider launch, confirm:

- Flutter release builds receive a real `SENTRY_DSN`
- dashboard production has a real Sentry DSN if Sentry is expected there
- test crash events are received in Sentry
- test-only crash code is removed after verification
- Vercel Analytics remains enabled for dashboard traffic

If DSNs are missing, beta can proceed only as a controlled beta with tighter
manual monitoring, not as a wide launch.

## 13. Remaining Risks

- Supabase Auth throttling still blocks wide launch readiness.
- Real large invite waves have not been validated.
- Large real photo upload behavior still needs monitoring.
- Wider write concurrency beyond small Staging bursts remains unproven.
- Monitoring must be actively watched during beta; passive deployment is not
  enough.

## 14. Go / No-Go Recommendation

Controlled beta: Go.

Conditions:

- invite users in waves
- watch auth `429` and login failures daily
- keep provider onboarding limited
- keep moderation staffed
- do not run broad public marketing yet

Wide launch: No-go.

Reason:

- password login still rate-limits too early under burst conditions
- operational monitoring and incident response must be proven first
