# RAFIQ Cloudflare Turnstile Readiness Plan

Purpose: protect open registration and forgot-password requests from bot
traffic without weakening Supabase Auth or exposing secrets.

Production touched: No.
Secrets in this file: None.

## Target Screens

- Register
- Forgot Password

Login can remain unchanged for beta. Add Turnstile to login only if abuse
appears, because extra friction on login can hurt normal users.

## Current Decision

Do not add a fake or half-wired challenge UI now.

Reason:

- Flutter needs a real Turnstile site key and a challenge surface.
- Verification needs a server-side secret.
- Blocking registration without a working challenge would break the current
  auth flow.

Instead, this phase documents the safe architecture and keeps current flows
working until real keys and a verifier are ready.

## Required Environment Variables

Client-side only:

- `TURNSTILE_SITE_KEY`

Server-side only:

- `TURNSTILE_SECRET_KEY`
- `TURNSTILE_VERIFY_URL=https://challenges.cloudflare.com/turnstile/v0/siteverify`

Never expose `TURNSTILE_SECRET_KEY` to Flutter, Vercel client bundles, logs, or
GitHub.

## Safe Architecture

1. Flutter opens a Turnstile challenge screen before sensitive auth actions.
2. The challenge returns a short-lived token.
3. Flutter sends the token to a trusted verifier.
4. The verifier uses `TURNSTILE_SECRET_KEY` server-side.
5. The verifier returns only `success: true/false`.
6. Register/Forgot Password proceeds only when verification succeeds.
7. Supabase Auth remains the only auth provider.

Recommended verifier:

- Supabase Edge Function named `verify-turnstile`

Alternative:

- Admin/dashboard trusted backend endpoint, only if it is server-only and never
  exposes the secret.

## Flutter Challenge Options

Recommended for mobile:

1. A small hosted challenge page using Cloudflare Turnstile.
2. Flutter opens it in WebView or external browser.
3. The page sends the token back through a controlled callback/deep link.
4. Flutter calls the verifier.

Do not embed the secret in the app.

## Guarded Behavior

If Turnstile keys are missing:

- Register keeps working.
- Forgot Password keeps working.
- No broken UI is shown.
- No user is blocked.
- The app should log/document that bot protection is not active.

If Turnstile is configured:

- Register must verify a valid token before `supabase.auth.signUp(...)`.
- Forgot Password must verify a valid token before
  `supabase.auth.resetPasswordForEmail(...)`.
- Invalid/missing tokens should show a friendly Arabic message:

```txt
محتاجين نتأكد إنك شخص حقيقي. جرّب التحقق مرة تانية.
```

## Supabase Edge Function Foundation

When implementing, create an Edge Function that:

1. Accepts a Turnstile token.
2. Rejects empty tokens.
3. Sends token + secret to Cloudflare's verify URL.
4. Returns only sanitized result fields.
5. Rate-limits repeated failures where possible.
6. Never logs the secret or raw token.

Pseudo flow:

```text
Flutter -> verify-turnstile(token)
verify-turnstile -> Cloudflare siteverify(secret, token)
verify-turnstile -> { success: true }
Flutter -> AuthService.signUp/sendPasswordResetOtp
```

## Staging Validation Plan

1. Create Turnstile site in Cloudflare for Staging.
2. Add Staging site key to Flutter run/build config.
3. Add Staging secret key to Supabase Edge Function secrets.
4. Deploy verifier to Supabase Staging only.
5. Register with valid token.
6. Register with missing/invalid token and confirm it is blocked.
7. Forgot Password with valid token.
8. Forgot Password with missing/invalid token and confirm it is blocked.
9. Confirm normal login remains unaffected.
10. Confirm no secrets appear in logs.
11. Confirm dashboard safety card still loads.

## Production Readiness Gate

Do not enable Turnstile enforcement in Production until:

- Staging valid-token test passes.
- Staging invalid-token test blocks.
- Custom SMTP is live.
- Auth rate limit decision is finalized.
- Owner understands the fallback path if challenge failures occur.

## Rollback Plan

If Turnstile causes user friction:

1. Disable enforcement flag server-side.
2. Keep Supabase Auth active.
3. Keep Register/Forgot Password available.
4. Watch auth/security events and launch alerts.
5. Re-enable after fixing challenge callback or verifier errors.

