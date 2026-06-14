# RAFIQ Performance Hardening Plan

Date: 2026-06-14
Scope: Post-capacity-audit hardening based on measured bottlenecks only
Production touched: No

Status: Historical implementation plan. Migrations `0061` through `0066` were
later applied and validated on Staging. See
[`PERFORMANCE_HARDENING_VALIDATION_REPORT.md`](PERFORMANCE_HARDENING_VALIDATION_REPORT.md)
for the measured outcome.

## 1. Root Cause Analysis: Auth Bottleneck

### What the audit showed
- Public browse stayed healthy under much higher read load than auth.
- Auth/login degraded much earlier than browse.
- The smallest unstable area was repeated login bursts, especially when the same credentials were reused aggressively.

### What we found in code
- Flutter user/provider login does not appear to re-login on every navigation. It uses Supabase session persistence and only performs password login during explicit sign-in.
- The Flutter sign-in path in [auth_service.dart](../lib/service/auth_service.dart) performs:
  - a pre-check RPC (`lookup_auth_email_state`)
  - `signInWithPassword`
  - profile hydration and local session caching
- The admin dashboard login path in [actions.ts](../admin-dashboard-rafiq-app/src/app/login/actions.ts) applies app-level throttling before login:
  - email limit: 5 / 15 minutes
  - IP limit: 15 / 15 minutes
  - then performs Supabase password auth
  - then checks `admin_roles`
- The existing k6 auth scripts repeatedly call password-grant login in tight loops against the same accounts. That is useful for burst-ceiling measurement, but it is harsher than normal session-backed usage.

### Real auth bottleneck
The first bottleneck is not normal in-app session reuse. It is the combination of:
- repeated password-grant storms in tests
- Supabase/Auth anti-abuse behavior and/or password-grant ceiling
- extra admin login throttling in the dashboard path

### Hardening decision
- Do not weaken rate limits
- Do not bypass auth
- Do not move secrets client-side
- Treat auth retesting separately from browse tests

### Auth hardening steps proposed
1. Keep session reuse as the default path in app and dashboard.
2. Retest auth with diversified accounts instead of one-account storms.
3. Separate these measurements in future k6:
   - raw password-grant capacity
   - real session-backed user journeys
   - dashboard admin login path through the real server action
4. Add auth observability later:
   - response-code buckets
   - rate-limit hit counters
   - login failure reason aggregation

## 2. Analytics Rollups Plan

### Live aggregation currently in use
These reads were still aggregating raw event tables live:
- `provider_place_analytics_live(...)`
- `provider_campaign_clicks_live(...)`
- admin overview reads over `analytics_events`
- dashboard places analytics derived from raw event rows

### Why this is weak
- raw event tables grow indefinitely
- repeated dashboard/provider reads become slower over time
- exact analytics from raw rows are expensive when the same windows are queried repeatedly

### Existing useful foundation
The repo already had:
- `analytics_daily_rollups`
- `rebuild_daily_rollups(_day)`
- `provider_analytics_summary`

### Safe rollup direction
- Keep raw events for ingestion, auditability, and replay.
- Move provider/admin reads to pre-aggregated daily summaries.
- Limit raw-table reads to “today tail” only where freshness matters.

### Migration added
- [0061_analytics_rollup_hardening.sql](../supabase/migrations/0061_analytics_rollup_hardening.sql)

### What migration 0061 does
- Adds `campaign_metric_daily_rollups`
- Backfills it from `campaign_metric_events`
- Updates `record_campaign_metric(...)` so raw events are still stored and same-day rollups are incremented
- Replaces `provider_place_analytics_live(...)` to:
  - read historical days from `analytics_daily_rollups`
  - read only current-day tail from raw `analytics_events`
- Replaces `provider_campaign_clicks_live(...)` to read rollups instead of aggregating raw clicks live

### App/dashboard code changed to use summaries
- [page.tsx](../admin-dashboard-rafiq-app/src/app/dashboard/page.tsx)
- [page.tsx](../admin-dashboard-rafiq-app/src/app/dashboard/places/page.tsx)

### Remaining risk
- Migration 0061 has been added to the repo but was not applied in this phase.
- Real benefit must be validated on Staging after migration apply.

## 3. Write/Moderation Concurrency Findings

### What likely drives the instability
From the current flows, the main pressure points are:
- sequential image uploads in the Flutter provider flow
- approval flows that replace image sets inside moderation logic
- repeated write bursts on the same logical entity
- moderation operations that do several database actions in one path

### Confirmed weak spots
- [api_service.dart](../lib/service/api_service.dart) previously uploaded place images strictly one by one.
- [0052_place_edit_submission_workflow.sql](../supabase/migrations/0052_place_edit_submission_workflow.sql) still shows approval logic that removes and reinserts image rows for edit approval.

### Safe fix implemented now
- Image upload in Flutter was parallelized in small bounded batches instead of fully sequential upload.
- Parallelism is intentionally conservative to avoid making storage bursts worse.

### Why this helps
- reduces provider-side latency during image submission
- lowers total time spent waiting before the moderation path begins
- improves responsiveness without weakening RLS or moderation controls

### Still needs work
These were intentionally not rewritten yet because they need careful staging validation:
- image rewrite/copy behavior during approval
- duplicate submit protection for place edit approval paths
- orphan-file reconciliation for interrupted moderation/image flows
- transaction-duration profiling inside moderation RPCs

## 4. Place Details Optimization Plan

### What the audit showed
- Place details degraded sooner than public browse.
- That usually indicates too many requests per details screen and/or repeated dependent fetches.

### What we found
Before this hardening pass, place details were loading through multiple separate requests:
- gallery
- last review
- favorite state
- promotions/campaigns
- analytics events triggered separately

### Safe improvement implemented
Added:
- [0062_place_details_context_rpc.sql](../supabase/migrations/0062_place_details_context_rpc.sql)

And updated:
- [api_service.dart](../lib/service/api_service.dart)
- [details_page.dart](../lib/view/details/details_page.dart)

### What changed
- A single RPC now returns:
  - gallery
  - campaigns
  - latest review
  - favorite state
  - canonical place identifiers
- Flutter details screen now hydrates these pieces together instead of spreading them across multiple sequential fetches.
- Analytics “open” and campaign impression tracking remain non-blocking from the UI perspective.

### Why this helps
- fewer round trips
- less client orchestration overhead
- smaller chance of partial/hanging detail states
- better foundation for later caching

### Remaining place-details work
- staging re-benchmark after migration apply
- confirm no N+1 remains around optional provider info
- add thumbnail strategy if image payload sizes are still heavy
- consider caching public approved details if future load justifies it

## 5. Admin Dashboard Query Optimization Plan

### What was inefficient
- overview metrics used raw analytics exact counts repeatedly
- places page fetched raw analytics rows and aggregated them in the app
- this does not scale when event history grows

### Safe improvements implemented
- [page.tsx](../admin-dashboard-rafiq-app/src/app/dashboard/page.tsx)
  - historical analytics come from rollups
  - only the current-day tail still reads raw events
- [page.tsx](../admin-dashboard-rafiq-app/src/app/dashboard/places/page.tsx)
  - replaces wide raw-event reads with rollup + today-tail composition

### What still needs work
- review activity page for long-term event-volume behavior
- reduce broad exact counts where not operationally necessary
- verify real pagination discipline across all admin lists
- add targeted indexes if staging query plans show slow filters/search

## 6. Exact Files Changed

### Added
- [0061_analytics_rollup_hardening.sql](../supabase/migrations/0061_analytics_rollup_hardening.sql)
- [0062_place_details_context_rpc.sql](../supabase/migrations/0062_place_details_context_rpc.sql)
- [PERFORMANCE_HARDENING_PLAN.md](PERFORMANCE_HARDENING_PLAN.md)

### Updated
- [api_service.dart](../lib/service/api_service.dart)
- [details_page.dart](../lib/view/details/details_page.dart)
- [page.tsx](../admin-dashboard-rafiq-app/src/app/dashboard/page.tsx)
- [page.tsx](../admin-dashboard-rafiq-app/src/app/dashboard/places/page.tsx)

## 7. Migrations Added

### 0061
Purpose:
- move provider/admin analytics off full live aggregation
- preserve raw event ingestion
- add campaign metric daily rollups

### 0062
Purpose:
- reduce place-details round trips with a safe public details context RPC

### Migration risk level
- medium, because they affect read paths and summary logic
- safe for staging first
- not applied to Production in this phase

## 8. Tests Run After Fixes

### Flutter
- `flutter analyze`
  - result: passed
- `flutter test`
  - result: passed
  - total: 22 tests passed

### Admin dashboard
- `npm run build`
  - result: passed

### Not run in this phase
- no new wide k6 run
- no Production write tests
- no Production mutation

Reason:
- the goal of this phase was audit + safe high-impact hardening first
- the new database read-path migrations should be applied to Staging before meaningful k6 retest

## 9. Remaining Risks

1. Auth wide-launch readiness is still not proven.
   - We now understand the likely bottleneck better, but diversified-account auth retesting is still needed.

2. Migration-backed improvements are not validated until Staging apply.
   - 0061 and 0062 are added but not exercised on a live staged database in this phase.

3. Moderation concurrency still needs deeper profiling.
   - especially image replacement/copy behavior in approval flows

4. Some admin pages still deserve scaling review.
   - especially high-churn activity/event timelines

## 10. Beta and Wide-Launch Readiness

### Beta readiness
- Improved
- The system is stronger now because the main expensive read paths are being redirected toward rollups and details hydration is being simplified.

### Wide-launch readiness
- Improved, but still not enough to claim ready
- The largest remaining blockers are:
  - auth burst characterization and hardening
  - staging validation of the new analytics/details migrations
  - moderation/write concurrency under realistic parallel writes

## 11. Recommended Next Validation

After applying migrations 0061 and 0062 to Staging:

1. Rerun focused k6 on public details.
2. Rerun mixed browse/details tests.
3. Rerun provider/admin analytics page reads.
4. Rerun small staging write bursts only:
   - place create/edit
   - image upload
   - campaign create/edit
   - moderation approve/reject
5. Rerun auth in two modes:
   - same-account burst
   - diversified-account burst

## 12. Final Status

This phase did not weaken security, did not touch Production data, and did not introduce fake optimizations. It focused on the measured bottlenecks:
- auth diagnosis
- analytics rollup hardening
- place-details round-trip reduction
- dashboard query efficiency
- safer provider-side image upload behavior

RAFIQ is stronger than before this pass, but the next truth point must come from Staging migration apply plus focused k6 retests.
