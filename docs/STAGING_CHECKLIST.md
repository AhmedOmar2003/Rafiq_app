# Staging Checklist

This checklist exists so we stop using production as the first place where
critical flows are exercised.

## 1. Environment

- Create a separate Supabase project for staging.
- Create a separate Vercel project or a staging branch deployment.
- Use different secrets for:
  - `SUPABASE_URL`
  - `SUPABASE_ANON_KEY`
  - `SUPABASE_SERVICE_ROLE_KEY`
  - `GEMINI_API_KEY`
  - `SENTRY_DSN`
- Keep staging APK builds clearly labeled.

## 2. Database Setup

- Run every migration against staging before production.
- Seed only safe test data.
- Create at least:
  - one normal user
  - one provider with a confirmed plan
  - one admin
  - one super admin
- Verify storage buckets exist and match production bucket policies.

## 3. Core Smoke Flow

- Sign up a brand-new user.
- Confirm the user lands on account-type choice.
- Choose regular user and verify:
  - Home opens correctly
  - Profile banner appears
  - No provider plan is auto-selected
- Open subscriptions from the profile banner and verify:
  - all plans render
  - no plan is preselected
- Choose provider flow and verify:
  - plan selection persists
  - provider hub opens
  - profile shows correct account state

## 4. Place Moderation

- Add a new place from the provider flow.
- Verify the new row is created with `status = 'pending'`.
- Verify the provider hub shows the 24-hour countdown.
- Verify the place does **not** appear in the public user feed before approval.
- Approve the place from `/dashboard/places`.
- Verify:
  - the provider sees the approved toast/state
  - the place appears in the public feed
- Reject another place and verify:
  - rejection reason appears for the provider
  - edit/resubmit path works

## 5. Reports And Appeals

- Submit a report against a place.
- Verify it appears in `/dashboard/reports`.
- Verify each report state works:
  - `open`
  - `reviewed`
  - `actioned`
  - `dismissed`
- Submit a provider appeal.
- Verify it appears in `/dashboard/appeals`.
- Accept the appeal and verify the place returns to `approved`.

## 6. Deletion And Cleanup

- Hard-delete a normal user from the dashboard.
- Hard-delete a provider from the dashboard.
- Verify:
  - auth user is gone
  - related database rows are gone
  - `place-images` files are removed
  - `provider-documents` files are removed

## 7. Observability

- Build a release with a real `SENTRY_DSN`.
- Trigger one controlled test error.
- Verify the event appears in Sentry.
- Verify Vercel Analytics records visits on the staging dashboard.

## 8. Release Gate

Production should only be promoted when all items above pass in staging for the
same commit/build that is going live.
