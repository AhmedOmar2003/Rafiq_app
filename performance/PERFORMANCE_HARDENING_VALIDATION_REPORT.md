# RAFIQ Performance Hardening Validation

Date: 2026-06-14
Environment: Supabase Staging `rafiq-staging` only
Production touched: No

## Executive Verdict

- Controlled beta: stronger and ready
- Stronger beta: yes
- Wide launch: no
- Main blocker: Supabase Auth password-grant rate limiting

The details, analytics, and independent write flows are materially healthier.
Authentication still fails under very small sustained login bursts, including
when requests are distributed across multiple accounts.

## Database Validation

Applied successfully to Staging:

- `0061_analytics_rollup_hardening.sql`
- `0062_place_details_context_rpc.sql`

Validation found two real gaps and added corrective migrations:

- `0063_fix_place_details_context_canonical_schema.sql`
  - `0062` referenced the missing legacy `places.place_id` column.
  - The corrected RPC uses canonical UUID relations.
- `0064_schedule_analytics_rollups.sql`
  - Schedules current-day and previous-day rollup rebuilds hourly with pg_cron.
- `0065_backfill_recent_analytics_rollups.sql`
  - Backfills the 365-day window served by provider/admin analytics.
- `0066_make_analytics_rollup_rebuild_exact.sql`
  - Replaces a requested day so events later marked `is_filtered` cannot leave
    stale summary rows behind.

Migration state is synchronized locally and remotely through `0066`.

The analytics backfill produced 6 rollup rows from 6 valid historical Staging
events. Campaign rollups were empty because Staging had no campaign metric
history.

## Build And Static Validation

| Check | Result |
|---|---|
| `flutter analyze` | Passed, no issues |
| `flutter test` | Passed, 22 tests |
| Dashboard `npm run build` | Passed |
| Updated k6 scripts archive check | Passed |

## Place Details Validation

### Correctness finding

The first runtime call after applying `0062` failed with:

`column pl.place_id does not exist`

This was fixed by migration `0063`. The corrected RPC then resolved an approved
place successfully.

### RPC results

| Target iterations/s | p95 | p99 | Failures | Dropped | Average achieved iterations/s |
|---:|---:|---:|---:|---:|---:|
| 10 | 102.63ms | 119.24ms | 0% | 0 | 5.57 |
| 20 | 104.79ms | 136.30ms | 0% | 0 | 10.52 |
| 40 | 106.74ms | 127.30ms | 0% | 0 | 21.01 |
| 60 | 100.29ms | 109.49ms | 0% | 5 | 31.40 |

The achieved average is lower than the peak target because the scenario ramps
through 25%, 50%, 75%, and 100% stages.

### Same-Staging legacy comparison

| Target | Mode | p95 | p99 | HTTP requests/s | Dropped |
|---:|---|---:|---:|---:|---:|
| 40 | Three legacy REST reads | 99.36ms | 134.19ms | 63.01 | 0 |
| 40 | Context RPC | 106.74ms | 127.30ms | 21.04 | 0 |
| 60 | Three legacy REST reads | 159.66ms | 284.93ms | 93.71 | 14 |
| 60 | Context RPC | 100.29ms | 109.49ms | 31.43 | 5 |

### Details verdict

- Comfortable capacity increased from the previous 20 target/s evidence to at
  least 40 target/s in this validation.
- 60 target/s is a warning zone because dropped iterations begin.
- At 40, both implementations were healthy on Staging.
- At 60, the RPC reduced p95 by about 37%, p99 by about 62%, and dropped
  iterations from 14 to 5.
- The RPC also reduces database/API request amplification from three details
  reads to one.
- The previous Production degradation at 40 was not reproduced on Staging, so
  environment and runner variability remain part of the comparison.

## Mixed Browse And Details

Retest mix: user/provider/admin `20/5/2`

| Scenario | p95 | p99 | Failures |
|---|---:|---:|---:|
| User | 108.49ms | 142.37ms | 0% |
| Provider | 108.49ms | 151.02ms | 0% |
| Admin | 132.09ms | 195.14ms | 0% |

Overall:

- 4,615 HTTP requests
- 0% failures
- 1 dropped iteration
- Details were no longer the visible weak point in this mixed run.

## Analytics Rollup Validation

Final test used populated `analytics_daily_rollups`, not an empty table.

| Scenario | Peak target | p95 | p99 | Failures |
|---|---:|---:|---:|---:|
| Provider analytics | 8/s | 106.21ms | 151.84ms | 0% |
| Admin analytics | 4/s | 106.99ms | 135.46ms | 0% |

Query behavior now is:

- historical place analytics from `analytics_daily_rollups`
- current-day freshness from the raw `analytics_events` tail
- campaign clicks from `campaign_metric_daily_rollups`
- raw event tables remain the source of truth

The earlier provider/admin full-flow baselines were approximately 205ms and
235ms p95. The new isolated analytics reads are near 106ms p95, but this is a
directional comparison because the old measurements included additional page
queries.

Staging contains only a small analytics dataset. The query design is improved,
but large-history scalability still needs a seeded high-volume Staging test.

## Write And Moderation Validation

The previous 3x3 scripts reused one provider and one approved place across all
VUs. That caused edit conflicts and plan-limit contention. The corrected tests
use one independent provider/place fixture per VU.

| Flow | 1x1 p95 | 3x3 p95 | 3x3 p99 | 3x3 failures |
|---|---:|---:|---:|---:|
| Place create/edit | 320.06ms | 266.74ms | 360.23ms | 0% |
| Image upload | 213.72ms | 223.91ms | 237.46ms | 0% |
| Campaign create/edit | 247.50ms | 196.14ms | 205.42ms | 0% |
| Admin moderation | 109.16ms | 111.41ms | 125.88ms | 0% |

Previous 3x3 p95 values were 5.4s to 10.2s with failures in three flows.

Verdict:

- Independent small write bursts are stable.
- Most previous instability came from shared-fixture contention, not backend
  saturation.
- The image k6 script uses small placeholder PNG payloads and does not prove
  performance for large real phone photos.
- Flutter bounded parallel uploads were not directly exercised by k6.
- Higher write concurrency was intentionally not tested in this phase.

One moderation run completed all checks but its teardown timed out because it
performed unrelated Storage cleanup. That cleanup was removed, the test was
rerun, and the final run completed normally.

Three orphaned `k6perf.*` users from the timed-out teardown were identified and
deleted from Staging. No test users remain from that run.

## Authentication Validation

### Results

| Mode | Target | p95 | HTTP failure rate | Successful checks | 429 responses |
|---|---:|---:|---:|---:|---:|
| User, same account | 3/s | 196.58ms | 44.07% | 53.57% | Not instrumented in first run |
| User, 6-account pool | 3/s | 183.95ms | 46.38% | 42.86% | 64 |
| Admin, 3-account pool | 1/s | 186.05ms | 26.58% | 66.13% | 21 |
| Provider, 3-account pool | 1/s | 191.99ms | 21.10% | 62.90% | 23 |

All instrumented authentication failures were HTTP `429`. No `400` failures
were recorded.

### Auth verdict

- Diversifying accounts did not fix the bottleneck.
- The failure is consistent with Supabase Auth project/IP password-grant rate
  limiting rather than per-account locking or Flutter session misuse.
- Admin and provider roles use the same underlying password-grant endpoint.
- The admin/provider tests were run after earlier auth bursts, so their exact
  percentages include an already-consumed project/IP rate budget.
- Session-backed application reads remain healthy.
- Security throttling was not weakened.

Required operational response:

- preserve sessions and avoid unnecessary password re-authentication
- use exponential backoff and jitter after `429`
- prevent repeated button submissions
- monitor Auth 429 rate
- confirm the intended Supabase Auth rate-limit configuration before wide
  launch

## Files Changed During Validation

Added:

- `performance/k6_analytics_rollups.js`
- `performance/PERFORMANCE_HARDENING_VALIDATION_REPORT.md`
- `supabase/migrations/0063_fix_place_details_context_canonical_schema.sql`
- `supabase/migrations/0064_schedule_analytics_rollups.sql`
- `supabase/migrations/0065_backfill_recent_analytics_rollups.sql`
- `supabase/migrations/0066_make_analytics_rollup_rebuild_exact.sql`

Updated:

- `performance/k6_public_read.js`
- `performance/k6_auth_user_flow.js`
- `performance/k6_provider_flow.js`
- `performance/k6_admin_flow.js`
- `performance/k6_staging_write_places.js`
- `performance/k6_staging_image_upload.js`
- `performance/k6_staging_campaigns.js`
- `performance/k6_staging_admin_moderation.js`
- `performance/lib/fixtures.js`
- `performance/lib/flows.js`
- `performance/lib/supabase.js`

Validation was completed before the release commit and push.

## Remaining Bottlenecks

1. Supabase Auth password-grant rate limiting remains the first blocker.
2. Analytics was validated on a very small historical dataset.
3. Large real-image upload performance remains unmeasured.
4. Write concurrency above three independent VUs remains unmeasured.
5. Production detail capacity must be rechecked with the RPC after release;
   this phase did not modify or load-test Production.

## Final Readiness

### Stronger beta

Yes.

- Details request amplification is lower.
- Mixed reads are healthy.
- Rollups are populated and scheduled.
- Independent 3x3 write/moderation flows are stable.

### Wide launch

No.

Authentication still fails too early under sustained password-login bursts.
Wide launch should wait for Auth rate-limit capacity planning, retry UX,
monitoring, and a clean distributed-runner authentication validation.

## Evidence

Raw k6 JSON summaries were retained locally during validation and intentionally
excluded from Git. The before/after measurements, limitations, and final
readiness decision are preserved in this report.
