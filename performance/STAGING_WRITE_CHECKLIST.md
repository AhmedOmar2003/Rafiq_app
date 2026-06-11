# RAFIQ Staging Write Checklist

Use this only on staging. Do not run on production.

## Preconditions

- `STAGING_ONLY=true`
- `SUPABASE_URL` points to the staging Supabase project
- `DASHBOARD_BASE_URL` points to the staging dashboard
- `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are staging keys
- staging buckets exist: `place-images`, `campaign-assets`
- staging plan/subscription data is seeded so provider fixtures can use campaigns

## Flow checklist

1. Create a new place and confirm it lands in `pending`.
2. Update a place while it is still `pending`.
3. Upload place images and register them through `register_provider_place_images`.
4. Request edit access for an already approved place.
5. Approve the edit request from the admin side.
6. Submit the approved-place edit and confirm a `place_edit_submissions` row is created.
7. Create a campaign and confirm it lands in `pending_review`.
8. Request a campaign edit, approve the edit window, then resubmit the campaign.
9. Approve or reject place/campaign moderation from the admin side.
10. Read provider analytics and dashboard counts after the writes.

## What to watch

- request latency for each write step
- failed writes or `4xx/5xx`
- storage upload latency
- moderation rows appearing in admin queues
- approved edits updating the published place correctly
- provider hub counters still loading after writes

## Safe outcome

- no write hits production
- no orphan image prefixes remain after teardown
- no moderation RPC fails
- analytics and dashboard reads still return quickly after write sequences
