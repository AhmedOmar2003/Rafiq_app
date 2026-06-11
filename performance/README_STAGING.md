# RAFIQ Staging Performance Writes

These scripts are for staging only.

## Files

- `performance/k6_staging_write_places.js`
- `performance/k6_staging_image_upload.js`
- `performance/k6_staging_campaigns.js`
- `performance/k6_staging_admin_moderation.js`
- `performance/STAGING_WRITE_CHECKLIST.md`

## Safety guard

Every staging write script refuses to run unless:

- `STAGING_ONLY=true`
- `SUPABASE_URL` is not the production Supabase URL
- `DASHBOARD_BASE_URL` is not the production dashboard URL

## Required env

- `STAGING_ONLY=true`
- `SUPABASE_URL=<staging supabase url>`
- `SUPABASE_ANON_KEY=<staging anon key>`
- `SUPABASE_SERVICE_ROLE_KEY=<staging service role key>`
- `DASHBOARD_BASE_URL=<staging dashboard url>`
- optional:
  - `PERF_TEST_PASSWORD`
  - `STAGING_VUS`
  - `STAGING_ITERATIONS`
  - `STAGING_MAX_DURATION`

## Example run

```powershell
$env:STAGING_ONLY='true'
$env:SUPABASE_URL='https://your-staging-project.supabase.co'
$env:SUPABASE_ANON_KEY='...'
$env:SUPABASE_SERVICE_ROLE_KEY='...'
$env:DASHBOARD_BASE_URL='https://your-staging-dashboard.vercel.app'

C:\Program Files\k6\k6.exe run performance/k6_staging_write_places.js
```

## What each script covers

- `k6_staging_write_places.js`
  - create place
  - update pending place
  - upload/register place images
  - request edit for approved place
  - submit approved-place edit
  - read provider analytics after writes

- `k6_staging_image_upload.js`
  - upload place gallery images
  - register gallery images
  - upload campaign asset image

- `k6_staging_campaigns.js`
  - create campaign
  - confirm `pending_review`
  - request campaign edit
  - approve edit window
  - resubmit updated campaign
  - read provider analytics/campaign state after writes

- `k6_staging_admin_moderation.js`
  - approve/reject place from admin side
  - approve edit window
  - approve submitted place edit
  - read dashboard/moderation state after actions

## Test data expected on staging

- plan/subscription seed data exists
- provider fixtures can call `become_provider`
- campaign features are enabled in the seeded plan
- storage buckets exist and are writable

## What to monitor during runs

- `http_req_failed`
- `p95` and `p99`
- storage upload latency
- queue visibility in `places`, `place_edit_submissions`, `promotional_campaigns`
- cleanup success for staging image prefixes

## When performance is considered safe

- writes succeed without `4xx/5xx`
- moderation and follow-up reads stay stable
- storage uploads do not spike latency excessively
- cleanup finishes without leaving large orphaned prefixes
