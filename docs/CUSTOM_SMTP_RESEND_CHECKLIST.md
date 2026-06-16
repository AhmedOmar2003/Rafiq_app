# RAFIQ Custom SMTP Readiness With Resend

Purpose: prepare RAFIQ for open registration without relying on Supabase's
small built-in email quota.

Production touched: No.
Secrets in this file: None.

## Why Custom SMTP Is Required

Open registration can create bursts of:

- signup confirmation emails, if email confirmation is enabled
- password reset emails
- OTP verification emails

Supabase's built-in email sender is useful for development and light beta, but
it is not enough for public onboarding. Custom SMTP gives RAFIQ better
deliverability, higher operational control, and clearer rollback.

Recommended provider: **Resend**.

## Current App Email Flows

RAFIQ still uses Supabase Auth as the source of truth.

Reviewed flows:

- Register screen calls `AuthService.signUp(...)`.
- `AuthService.signUpWithEmailOtp(...)` calls `supabase.auth.signUp(...)`.
- If Supabase Email Confirmation is ON, Supabase sends the signup OTP/email.
- Forgot Password calls `AuthService.sendPasswordResetOtp(...)`.
- `sendPasswordResetOtp(...)` calls `supabase.auth.resetPasswordForEmail(...)`.
- Reset Password verifies Supabase recovery OTP and calls
  `supabase.auth.updateUser(...)`.

There is no custom PHP auth, no custom password storage, and no custom email
delivery path in the app.

## Resend Setup Checklist

1. Create a Resend account.
2. Add the RAFIQ sending domain.
3. Choose a sender address such as `no-reply@your-domain.com`.
4. Verify the domain in Resend.
5. Add the DNS records shown by Resend.
6. Wait until Resend marks the domain as verified.
7. Create SMTP credentials in Resend.
8. Open Supabase Dashboard.
9. Go to Authentication -> Emails / SMTP.
10. Enable Custom SMTP.
11. Enter the SMTP fields listed below.
12. Send a signup email test.
13. Send a forgot-password email test.
14. Confirm inbox delivery and spam-folder behavior.
15. Keep a rollback note with the previous Supabase SMTP state.

## DNS Records Needed

Exact values come from Resend. Do not invent them.

- SPF: authorizes Resend to send mail for the domain.
- DKIM: cryptographic sender verification.
- DMARC: reporting and policy for failed SPF/DKIM checks.

Recommended DMARC starting point for beta:

```txt
v=DMARC1; p=none; rua=mailto:dmarc@your-domain.com
```

After deliverability is clean, the policy can become stricter.

## Supabase SMTP Fields

Fill these in Supabase only. Never commit the values.

- SMTP host
- SMTP port
- SMTP username
- SMTP password
- sender email
- sender name

Recommended sender name:

```txt
رفيق
```

## Staging Validation Plan

Use Staging first.

1. Configure Custom SMTP on Supabase Staging.
2. Register a new Staging user.
3. Confirm the signup email arrives.
4. Complete signup/verification if email confirmation is enabled.
5. Request forgot-password email.
6. Confirm reset email arrives.
7. Complete password reset.
8. Confirm login with the new password.
9. Check dashboard launch safety card after failed/limited auth attempts.
10. Confirm no secrets appear in logs or Git.

## Production Rollout Plan

1. Configure Production SMTP only after Staging passes.
2. Do not run load tests on Production.
3. Do a single real signup test.
4. Do a single forgot-password test.
5. Watch the dashboard safety card for auth/email failures.
6. Keep the first public registration wave small.

## Rollback Plan

If emails fail:

1. Pause public signup announcements.
2. Disable Custom SMTP or restore the previous SMTP values in Supabase.
3. Re-test signup and forgot-password with one account.
4. Check Resend domain verification and DNS status.
5. Keep the dashboard safety card open during rollback.

## Never Commit

- SMTP password
- Resend API key
- Supabase service role key
- real test-user passwords
- screenshots that reveal credentials

