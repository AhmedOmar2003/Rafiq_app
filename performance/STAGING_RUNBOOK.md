# Staging Runbook

## Required env

- `STAGING_ONLY=true`
- `SUPABASE_URL=<staging-supabase-url>`
- `SUPABASE_ANON_KEY=<staging-anon-key>`
- `SUPABASE_SERVICE_ROLE_KEY=<staging-service-role-key>`
- `DASHBOARD_BASE_URL=<staging-dashboard-url-or-safe-placeholder>`
- Optional:
  - `PERF_TEST_PASSWORD=Rafiq2026@`
  - `STAGING_VUS=1`
  - `STAGING_ITERATIONS=1`

## Safety rules

- Never run these scripts against Production.
- `STAGING_ONLY=true` is mandatory.
- `SUPABASE_URL` must point to Staging only.
- Use Flutter with Staging `--dart-define` values only.

## Flutter on Staging

```powershell
flutter run --dart-define=SUPABASE_URL=<staging-supabase-url> --dart-define=SUPABASE_ANON_KEY=<staging-anon-key>
```

## Safe order

1. Push Staging migrations.
2. Run `flutter analyze`
3. Run `flutter test`
4. Run `npm run build` in `admin-dashboard-rafiq-app` if dashboard changed.
5. Run one k6 script at a time with small load.

## k6 commands

```powershell
& 'C:\Program Files\k6\k6.exe' run performance\k6_staging_write_places.js
& 'C:\Program Files\k6\k6.exe' run performance\k6_staging_image_upload.js
& 'C:\Program Files\k6\k6.exe' run performance\k6_staging_campaigns.js
& 'C:\Program Files\k6\k6.exe' run performance\k6_staging_admin_moderation.js
```

## Acceptable first-pass result

- All checks pass.
- `http_req_failed = 0%`
- Small-load `p95` stays comfortably below the script threshold.
- Approved/rejected moderation flow works.
- Place, image, campaign, and admin moderation writes complete without touching Production.
