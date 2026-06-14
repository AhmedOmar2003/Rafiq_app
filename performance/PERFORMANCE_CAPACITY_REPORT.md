# RAFIQ Performance Capacity Report

Date: 2026-06-13
Workspace: repository root

## Executive Summary

This audit executed real k6-based capacity tests against RAFIQ with a strict safety split:

- Production: public read-only traffic only
- Staging: authenticated reads, login capacity, and write/moderation flows only
- No production write mutation was performed
- No secrets are printed in this report

Measured outcome:

- Public browsing is currently the strongest path
- Place details are noticeably weaker than browse
- Authentication is the first major operational bottleneck
- Low-concurrency write flows are already unstable under small concurrent bursts
- Provider analytics and campaign analytics still rely on live aggregation over raw events, which is not a scalable design for wide launch

Bottom line:

- Beta readiness: **Yes, for controlled beta**
- Wide-launch readiness: **No, not yet**

## Scope And Safety Rules

Executed:

- Existing `performance/` scripts audit
- Script fixes before measurement
- Public read/load tests
- Public spike test
- Public soak test
- Staging login/auth capacity tests
- Staging provider/admin/mixed realistic read tests
- Staging-only write tests guarded by `STAGING_ONLY=true`
- Schema/query/index review for likely bottlenecks

Not executed:

- Production write tests
- Production auth storm tests
- Production data mutation of any kind

## Script Audit And Fixes Applied

Before running tests, the performance harness was updated so results reflect the current system more accurately and more safely.

### Changes made

1. `performance/lib/config.js`
   - Updated the default dashboard URL to the current production dashboard.

2. `performance/lib/fixtures.js`
   - Added a hard staging-only guard by calling `requireStagingOnly(config)`.
   - This prevents fixture-creating scripts from mutating production accidentally.

3. `performance/lib/supabase.js`
   - Updated storage upload helper defaults away from SVG.
   - Fixed sample place fetching to return both canonical UUID and legacy numeric `place_id` when present.

4. `performance/k6_public_read.js`
   - Refined scenario controls.
   - Removed `/login` from the place-details bundle.
   - Added a dedicated login-page probe scenario.

5. `performance/lib/flows.js`
   - Updated review projections to a canonical shared subset:
     - `id,place_id,user_id,rating,body,created_at`
   - Added an environment toggle to skip the protected staging preview HTML check.

6. Additional script coverage
   - Added:
     - `performance/k6_public_spike.js`
     - `performance/k6_public_soak.js`

### Important audit findings

1. **Schema drift exists between old review field usage and canonical review schema**
   - Canonical schema uses fields like `id`, `body`.
   - Some dashboard code still references legacy fields such as `review_id`, `review_text`, `name`.
   - This is a real parity and maintainability issue.

2. **Staging Vercel preview is access-protected**
   - Anonymous preview HTML load testing returned `401`.
   - Staging admin measurements therefore focused on actual authenticated data/API reads, not anonymous preview HTML.

3. **Provider analytics still aggregate raw event tables live**
   - `provider_place_analytics_live(...)` groups directly from `analytics_events`
   - `provider_campaign_clicks_live(...)` counts directly from `campaign_metric_events`
   - This is acceptable for small scale, but not a strong design for wide launch.

## Test Matrix

| Area | Environment | Type | Status |
|---|---|---|---|
| Public browse | Production | Read load | Executed |
| Place details | Production | Read load | Executed |
| Login page | Production | Read load | Executed |
| Public spike | Production | Read load | Executed |
| Public soak | Production | Read load | Executed |
| User login | Staging | Auth capacity | Executed |
| Provider login | Staging | Auth capacity | Executed |
| Admin login | Staging | Auth capacity | Executed |
| Provider dashboard flow | Staging | Authenticated read | Executed |
| Admin dashboard flow | Staging | Authenticated read | Executed |
| Mixed realistic read load | Staging | Authenticated mixed read | Executed |
| Place create/edit flow | Staging | Write | Executed |
| Image upload flow | Staging | Write | Executed |
| Campaign create/edit flow | Staging | Write | Executed |
| Admin moderation flow | Staging | Write | Executed |

## Measured Results

## 1. Production Public Browse Capacity

Short-ramp browse measurements:

| Target load | Achieved req/s | p95 | p99 | Failures | Dropped iterations | Assessment |
|---|---:|---:|---:|---:|---:|---|
| 20 | 10.47/s | 142.75ms | 172.52ms | 0% | 0 | Healthy |
| 50 | 26.49/s | 128.79ms | 204.97ms | 0% | 0 | Healthy |
| 70 | 36.87/s | 122.85ms | 165.12ms | 0% | 3 | Healthy |
| 100 | 52.13/s | 123.71ms | 160.78ms | 0% | 13 | Healthy |
| 150 | 78.09/s | 120.98ms | 147.35ms | 0% | 30 | Healthy |
| 200 | 102.98/s | 144.36ms | 195.78ms | 0% | 50 | Still strong |
| 250 | 128.79/s | 153.11ms | 193.39ms | 0% | 70 | Warning zone |
| 300 | 131.31/s | 426.80ms | 914.11ms | 0% | 270 | Clear danger zone |

Interpretation:

- Public browse is currently comfortable through roughly **200 req/s short-ramp read traffic**
- Warning signs begin around **250 req/s**
- The first clear browse danger point appears at **300 req/s**

## 2. Production Public Smoke Bundle

Corrected smoke bundle result:

- Total requests: `538`
- Average throughput: `11.52/s`
- Average latency: `120.4ms`
- p95: `175.63ms`
- p99: `259.94ms`
- Failures: `0%`

By scenario:

- Browse p95: `125.99ms`
- Details p95: `203.48ms`
- Login page p95: `136.59ms`
- Redirect p95: `123.67ms`

Interpretation:

- The public read surface is fast in low realistic traffic
- Details are already a little heavier than browse even at smoke level

## 3. Production Place Details Capacity

Sequential valid detail runs:

| Target load | Achieved req/s | p95 | p99 | Failures | Dropped iterations | Assessment |
|---|---:|---:|---:|---:|---:|---|
| 10 | 21.87/s | 177.50ms | 212.70ms | 0% | 0 | Healthy |
| 20 | 41.82/s | 192.75ms | 235.92ms | 0% | 0 | Healthy |
| 40 | 76.02/s | 2360.93ms | 3650.37ms | 0% | 56 | Degraded |

Interpretation:

- Place details remain strong through **20 target req/s**
- Details degrade sharply at **40 target req/s**
- This is materially weaker than the public browse endpoint

Important note:

- Earlier `prod_place_details_*_v2` runs were launched in parallel and are **discarded** from the final evidence set.

## 4. Production Spike Behavior

Measured spike:

- Baseline: `20/s`
- Spike: `200/s`
- Resulting average throughput: `116.07/s`
- p95: `331.48ms`
- p99: `578.15ms`
- Failures: `0%`
- Dropped iterations: `73`

Interpretation:

- The public browse layer absorbs a short spike reasonably well
- It does not collapse immediately
- Latency rises, but remained below one second at p99 in this test

## 5. Production Soak Behavior

10-minute soak at configured `50/s`:

- Total requests: `18,263`
- Achieved average throughput: `27.97/s`
- Average latency: `197.27ms`
- p95: `207.36ms`
- p99: `283.54ms`
- Failures: `0.01%`
- Dropped iterations: `2,665`

Observed warnings:

- Request timeouts occurred
- k6 also reported unplanned VU allocation pressure

Interpretation:

- Completed requests stayed relatively fast
- But the system did **not** sustain the configured rate
- This is a meaningful reliability warning
- The exact split between backend saturation and k6 runner-side pressure is uncertain from this single-host run, so that uncertainty should be respected

## 6. Staging Authentication Capacity

### User login

| Load | Achieved req/s | p95 | Failures | Checks | Assessment |
|---|---:|---:|---:|---:|---|
| 1 | 1.01/s | 214.63ms | 0% | 100% | Healthy |
| 3 | 1.78/s | 209.37ms | 45.45% | 50.82% | Broken |

### Provider login

| Load | Achieved req/s | p95 | Failures | Checks | Assessment |
|---|---:|---:|---:|---:|---|
| 1 | 1.26/s | 210.39ms | 0% | 100% | Healthy |
| 3 | 1.96/s | 209.79ms | 28.57% | 65.63% | Broken |

### Admin login

| Load | Achieved req/s | p95 | p99 | Failures | Checks | Assessment |
|---|---:|---:|---:|---:|---:|---|
| 1 | 1.36/s | 501.91ms | 1016.55ms | 14.55% | 78.38% | Already unstable |

Interpretation:

- Authentication is the **first major capacity bottleneck**
- User and provider login both fail materially by **3 login requests/s**
- Admin login is already unstable at **1 login request/s**

This does **not** mean normal user browsing is unstable; it means the auth path is much weaker than the read path and will become an operational problem first during bursts.

## 7. Staging Authenticated Read Capacity

### Provider flow

- Throughput: `23.69/s`
- p95: `204.61ms`
- p99: `361.06ms`
- Failures: `0%`

### Admin flow

- Throughput: `21.47/s`
- p95: `234.82ms`
- p99: `372.09ms`
- Failures: `0%`

### Mixed realistic load

| Mix | Achieved req/s | p95 | p99 | Failures | Assessment |
|---|---:|---:|---:|---:|---|
| `10/3/1` | 49.78/s | 430.70ms | 1010.68ms | 0% | Acceptable |
| `20/5/2` | 88.72/s | 166.81ms | 469.07ms | 0% | Stronger than expected |

Interpretation:

- Once sessions already exist, RAFIQ performs much better than during repeated login storms
- Session-backed browsing and dashboard reads are materially healthier than auth creation/sign-in bursts
- The non-monotonic result between the two mixed runs should be treated as test variability, not as proof of perfect linear scaling

## 8. Staging Write Capacity

### Single-user baseline

| Flow | Throughput | p95 | Failures | Checks | Assessment |
|---|---:|---:|---:|---:|---|
| Place create/edit | 6.23/s | 204.28ms | 0% | 100% | Healthy |
| Image upload | 4.97/s | 356.89ms | 0% | 100% | Healthy |
| Campaign create/edit | 5.92/s | 290.28ms | 0% | 100% | Healthy |
| Admin moderation | 6.09/s | 226.96ms | 0% | 100% | Healthy |

### Small concurrent burst: `3 x 3`

| Flow | Throughput | p95 | p99 | Failures | Checks | Assessment |
|---|---:|---:|---:|---:|---:|---|
| Place create/edit | 4.58/s | 5420.04ms | 10138.82ms | 4.44% | 92.59% | Unstable |
| Image upload | 2.85/s | 10207.17ms | 10242.68ms | 0% | 100% | Extremely slow |
| Campaign create/edit | 2.02/s | 246.34ms | 6273.48ms | 8.33% | 86.67% | Unstable |
| Admin moderation | 4.12/s | 8164.41ms | 10144.77ms | 8.82% | 87.50% | Unstable |

Interpretation:

- Single write flows are fine
- Small concurrent bursts already create real tail latency and failure issues
- RAFIQ should **not** be considered ready for broad write-heavy concurrency without further hardening

## Comfortable Capacity And Danger Zones

## Comfortable Capacity

Evidence-based comfortable operating zone today:

- Public browse: about **200 req/s short-ramp**
- Place details: about **20 target req/s**
- Mixed authenticated reads with existing sessions: about **50–90 req/s** in staging-level tests
- Write flows: **single-user or very light concurrency only**
- Login/auth bursts: **well below 3 login req/s**, especially for admin

## Danger Zones

Evidence-based danger zones today:

- Public browse: **300 req/s**
- Place details: **40 target req/s**
- User/provider login: **3 login req/s**
- Admin login: **already unstable at 1 login req/s**
- Multi-step write/moderation concurrency: **3x3 already unstable**

## First Bottleneck

The first clear bottleneck is **authentication/login capacity**.

Why:

- Read traffic holds up much better than auth
- User/provider logins fail materially at 3 login requests/s
- Admin login is already unstable at 1 login requests/s

Operational implication:

- A marketing burst, release-day login wave, or OTP/login retry burst can fail before browse endpoints appear unhealthy

## Bottleneck Analysis

## Critical

### 1. Authentication path is fragile under very small bursts

Evidence:

- User login failure rate at 3 req/s: `45.45%`
- Provider login failure rate at 3 req/s: `28.57%`
- Admin login failure rate at 1 req/s: `14.55%`

Impact:

- This is the first path likely to fail during real spikes
- It directly affects onboarding, re-login, and admin operations

### 2. Write/moderation flows are not yet concurrency-resilient

Evidence:

- 3x3 write tests show 5–10 second tail latencies
- Failures appear in place edit, campaign flow, and moderation flow

Impact:

- Small teams of providers or moderators acting at the same time can already create a poor experience

## High

### 3. Provider analytics and campaign analytics still query raw event tables live

Evidence:

- `provider_place_analytics_live(...)` aggregates directly from `analytics_events`
- `provider_campaign_clicks_live(...)` counts directly from `campaign_metric_events`
- Daily rollups already exist, but the provider-facing reads are not using them

Impact:

- This design scales poorly as event volume grows
- It risks slow provider dashboards and expensive repeated aggregation

### 4. Place details path is much weaker than browse

Evidence:

- Browse remains healthy through ~200 req/s short-ramp
- Details degrade strongly at 40 target req/s

Impact:

- A place going popular can stress details before the home feed shows visible strain

## Medium

### 5. Dashboard relies on exact counts and wide reads

Examples observed:

- Multiple `count: "exact"` queries
- Wide `limit(2000)` and `limit(5000)` reads in dashboard surfaces
- Large analytics and activity reads

Impact:

- This is acceptable at small scale
- It becomes increasingly wasteful and slower as data grows

### 6. Soak sustainability is weaker than short-ramp behavior

Evidence:

- Configured soak rate: `50/s`
- Achieved average: `27.97/s`
- Dropped iterations: `2,665`

Impact:

- Sustained traffic behavior is less reassuring than short burst behavior

## Low

### 7. Schema drift around reviews increases fragility

Evidence:

- Some code still references old review fields while canonical migrations use newer field names

Impact:

- This is more a correctness and maintainability risk than an immediate capacity ceiling
- It can still create broken screens, bad dashboards, or misleading analytics under load

## Security, Reliability, And Operational Findings

## Biggest security or reliability issue

The biggest practical reliability issue is:

- **Auth instability under small bursts**

The biggest operational safety issue is:

- **Live aggregation over raw analytics event tables instead of provider-facing rollups**

Additional operational findings:

- Storage bucket rules are constrained and do not appear recklessly open
- Production write safety was respected during this audit
- Sentry wiring exists in app code but only activates when `SENTRY_DSN` is supplied
- Vercel Analytics is present in the dashboard

## Unrealistic Or Weak Areas

These are the parts of the current system or test model that are weak, misleading, or not yet strong enough for wide launch confidence:

1. Public read performance is much better than write/auth performance
   - If one only looks at browse numbers, the system would look stronger than it really is

2. Provider analytics currently feel real, but are implemented in a way that will not scale gracefully

3. Dashboard exact-count patterns and wide reads are acceptable for beta, but not a solid long-term admin scaling strategy

4. Staging/production parity is imperfect
   - Review field drift is a concrete example

5. The soak result shows that short bursts and steady-state sustainability are not the same thing

## Architecture And Query Review Notes

Strong points found:

- Browse path has meaningful index coverage
- Approved/public browse logic is already centralized in RPC
- Storage MIME restrictions exist for place images

Scaling concerns found:

- Provider analytics read raw events live instead of rollups
- Campaign click analytics read raw events live
- Place edit approval workflow rewrites related images during approval, which becomes heavier as edits and image counts grow
- Dashboard pages perform some wide exact counts and broad scans

## Recommendations

## Top recommended improvement

Move provider-facing and admin-facing analytics reads away from raw-event live aggregation and onto **pre-aggregated rollups/materialized summaries**, then cache those reads.

Why this is the top recommendation:

- It improves provider dashboard scalability
- It reduces pressure on event tables
- It helps both app UX and admin UX
- It becomes more important as usage grows

## Recommended roadmap

### Priority 1

1. Harden the authentication path
   - Investigate why user/provider/admin login already fail at very low rates
   - Check Supabase auth limits, OTP/session workflows, retry storms, and dashboard auth path behavior
   - Add auth-specific alerting and rate metrics

2. Replace live analytics aggregation with rollups for provider-facing reads
   - Use `analytics_daily_rollups` or equivalent summaries for dashboards
   - Keep raw event tables for ingestion and forensic detail, not repeated UI reads

3. Reduce admin dashboard exact counts and wide scans
   - Cache overview metrics
   - Precompute counters
   - Paginate more aggressively

### Priority 2

4. Harden write flows under concurrency
   - Review transaction duration
   - Review edit approval workflow
   - Review image upload + moderation flow sequencing
   - Add request tracing around slow multi-step mutations

5. Improve place details efficiency
   - Cache public approved place details bundles
   - Consider consolidating details-related reads where safe
   - Reduce parallel round trips if possible

6. Add a dedicated production-like load runner host
   - The soak test shows the need to separate application limits from local k6 host limitations

### Priority 3

7. Remove schema drift around reviews and other legacy field assumptions

8. Add formal performance SLOs
   - Example:
     - browse p95 < 250ms
     - details p95 < 500ms
     - login failure rate < 1%
     - moderation flow p95 < 1.5s

## Beta Readiness

## Ready for beta?

**Yes, for controlled beta.**

Reason:

- Public browsing is strong enough
- Session-backed reads are reasonably healthy
- Single-user writes work
- The system is usable if user volume is controlled and operations are watched closely

Conditions:

- Beta should be controlled
- Monitoring should be active
- Auth failures and moderation/write latency must be watched immediately

## Ready for wide launch?

**No.**

Reason:

- Authentication breaks too early
- Write/moderation concurrency is not yet resilient
- Provider analytics architecture is not yet strong enough for larger scale
- Soak sustainability is weaker than short-ramp results suggest

## Limitations Of This Audit

1. Production write tests were intentionally not run
2. Production auth storm tests were intentionally not run
3. Staging preview HTML itself was access-protected, so anonymous preview-page load testing was not meaningful there
4. One earlier set of parallel detail runs was invalid and has been excluded
5. The 10-minute soak showed throughput shortfall, but exact causality needs deeper telemetry or a stronger load runner host
6. Write tests were intentionally not escalated beyond low concurrency once clear instability appeared

## Final Verdict

RAFIQ is currently:

- **Good enough for a monitored, limited beta**
- **Not yet strong enough for a broad public launch**

If the team wants the fastest path to a safer next step:

1. Fix auth burst reliability first
2. Move provider/admin analytics reads to rollups and cache
3. Reduce dashboard exact counts and wide scans
4. Re-run write concurrency tests after those fixes

## Evidence Files

Main output report:

- `performance/PERFORMANCE_CAPACITY_REPORT.md`

Raw k6 JSON summaries were retained locally during analysis and intentionally
excluded from Git. The measured values and limitations needed for engineering
decisions are preserved in this report.
