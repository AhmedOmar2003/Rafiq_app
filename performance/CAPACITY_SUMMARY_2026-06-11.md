# RAFIQ Capacity Summary

Date: 2026-06-11

## Scripts created

- `performance/k6_public_read.js`
- `performance/k6_auth_user_flow.js`
- `performance/k6_provider_flow.js`
- `performance/k6_admin_flow.js`
- `performance/k6_mixed_realistic_load.js`
- `performance/lib/config.js`
- `performance/lib/supabase.js`
- `performance/lib/flows.js`
- `performance/lib/fixtures.js`

## Safe production scope

These runs were intentionally limited to safe read-mostly scenarios with temporary test accounts and temporary provider/admin fixtures.

Not executed as production load:

- write-heavy bulk place creation
- bulk place edits
- bulk campaign creation
- bulk image upload pressure
- moderation accept/reject write storms

Those need a staging environment or a dedicated test dataset.

## Public read

Scenario:

- browse public places
- open place details bundle
- fetch reviews
- fetch gallery
- fetch approved campaigns
- fetch image asset

Load:

- browse peak: 10 iterations/s
- details peak: 5 iterations/s

Result:

- requests: 402
- failures: 0.00%
- overall p95: 396.17ms
- browse p95: 325.56ms
- details p95: 410.89ms

## Authenticated user flow

Scenario:

- sign in
- browse public places
- open details
- read profile
- read favorites

Load:

- user flow peak: 2 iterations/s
- login peak: 1 iteration/s

Result:

- requests: 182
- failures: 0.00%
- overall p95: 308.83ms
- user flow p95: 308.12ms
- login p95: 274.96ms

## Provider flow

Scenario:

- sign in
- open provider hub reads
- read provider profile
- read provider places
- read provider plan
- read provider campaigns
- read provider analytics

Load:

- provider flow peak: 2 iterations/s
- login peak: 1 iteration/s

Result:

- requests: 168
- failures: 0.00%
- overall p95: 197.32ms
- provider flow p95: 146.75ms
- provider login p95: 200.25ms

## Admin flow

Scenario:

- sign in
- open dashboard login page
- read dashboard aggregate counts
- read users
- read providers
- read places
- read reports
- read appeals
- read subscriptions

Load:

- admin flow peak: 1 iteration/s
- login peak: 1 iteration/s

Result:

- requests: 228
- failures: 0.00%
- overall p95: 195.59ms
- admin flow p95: 165.97ms
- admin login p95: 208.97ms

## Mixed realistic beta load

Scenario mix:

- 6 user iterations/s
- 2 provider iterations/s
- 1 admin iteration/s

Result:

- requests: 924
- failures: 0.00%
- overall p95: 381.85ms
- overall p99: 692.66ms
- mixed user p95: 448.20ms
- mixed provider p95: 323.28ms
- mixed admin p95: 315.64ms

## Capacity judgment

Current comfortable beta zone from safe tested scenarios:

- public + authenticated mixed read traffic around 32 HTTP requests/s stayed healthy
- isolated public browsing around 17.6 HTTP requests/s stayed healthy
- provider and admin read flows remained comfortably below 250ms p95 in isolated runs

Observed earlier in the same test session:

- when several login-heavy scripts were run together in parallel, authentication became the first shared chokepoint
- an earlier heavier public stress probe showed public read degradation near roughly 200+ mixed public HTTP requests/s, with failures and dropped iterations

Interpretation:

- read-heavy beta traffic looks healthy
- authentication under concurrent bursty login pressure is the first area to watch
- wide public-scale launch still needs more tuning and a staging write/load round

## Main bottlenecks identified

1. Shared auth/login pressure is more fragile than post-login reads.
2. Public details bundles are slower than simple browse reads.
3. Write-heavy scenarios were not validated on production for safety reasons.

## Recommended next improvements

1. Run staging-only write tests for place create/edit, campaign create/edit, and image uploads.
2. Add or verify indexes behind the slowest details and analytics queries.
3. Consider caching or consolidating place details reads if public traffic grows fast.
4. Keep admin/provider analytics on rollups or pre-aggregated reads where possible.
5. Add a focused auth burst test to measure the real login ceiling before a wide launch.

## Final verdict

Performance status: good for beta, but needs improvements before a wide public launch.
