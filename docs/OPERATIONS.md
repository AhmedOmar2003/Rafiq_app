# Operations runbook — Rafiq

This doc covers the three operational pillars the launch needs:
1. Error monitoring (Sentry)
2. Database backup + restore
3. Content moderation policy + abuse reports

Keep it short. Update it the day something changes.

---

## Current truth

- `Sentry` is now wired in code and activates only when `SENTRY_DSN` is
  supplied at build time.
- `Vercel Analytics` stays dashboard-only.
- Self-delete now prefers the `delete-account` Edge Function so storage
  cleanup runs before the account disappears.
- Staging env templates now live in:
  - [D:\rafiq_master\.env.staging.example](D:/rafiq_master/.env.staging.example)
  - [D:\rafiq_master\supabase\.env.staging.example](D:/rafiq_master/supabase/.env.staging.example)
  - [D:\rafiq_master\admin-dashboard-rafiq-app\.env.staging.example](D:/rafiq_master/admin-dashboard-rafiq-app/.env.staging.example)

---

## 1 · Error monitoring (Sentry)

We ship `sentry_flutter` in the app and **only activate it when a DSN is
supplied at build time**. That way the codebase stays free of credentials,
and dev builds don't pollute the dashboard.

### Enable Sentry for a release

1. Create a project on https://sentry.io (Flutter platform).
2. Copy the DSN — looks like `https://abc123@o0.ingest.sentry.io/12345`.
3. Build the APK with the DSN baked in:
   ```bash
   flutter build apk --release \
     --dart-define=SENTRY_DSN=https://abc123@o0.ingest.sentry.io/12345
   ```
4. Verify the dashboard receives a test event — easiest is to force a
   throw inside an `onTap` for one build, hit it, then revert.

### What we capture
- Every uncaught Dart exception (covered by `SentryFlutter.init`).
- Every Flutter framework error.
- 20% of navigation transactions (`tracesSampleRate = 0.20`).

### What we DON'T capture
- Screenshots (`attachScreenshot = false`) — PII safety.
- Profiling traces (`profilesSampleRate = 0`) — cost.
- User identifiers — only the Supabase `auth.uid()` is attached when
  available, never the email or phone.

---

## 2 · Database backup & restore (Supabase)

### Automatic backups
| Plan | Frequency | Retention | PITR (Point-in-Time Recovery) |
|---|---|---|---|
| Free | Daily | 7 days | ❌ |
| Pro | Daily | 7 days | ✅ (up to 7 days) |
| Team / Enterprise | Daily | 14–28 days | ✅ (up to 28 days) |

For launch we're on **Pro tier** so any data loss within 7 days is
recoverable down to the minute.

### Manual backup (anytime)

```bash
# From any machine that has the Supabase CLI installed:
supabase db dump --linked --data-only > rafiq-data-$(date +%Y%m%d).sql
supabase db dump --linked              > rafiq-schema-$(date +%Y%m%d).sql
```

Store the dumps in an encrypted drive separate from the app server.
**Don't** commit them to git — they include emails and contact info.

### Restore drill (quarterly)

Once a quarter, prove the backup actually works:

1. Spin up a **brand-new** Supabase project (Free tier is fine for the drill).
2. Apply our migration history:
   ```bash
   supabase link --project-ref <new-project-ref>
   supabase db push --include-all
   ```
3. Restore the latest schema + data dumps:
   ```bash
   psql <new-project-conn-str> < rafiq-schema-YYYYMMDD.sql
   psql <new-project-conn-str> < rafiq-data-YYYYMMDD.sql
   ```
4. Smoke-test: log in via dashboard with `admin@rafiq.app`, confirm KPIs
   render, confirm `places.status = 'rejected'` rows still carry their
   `rejection_reason`.
5. Tear the project down. Note the date + duration in `docs/RESTORE_DRILLS.md`.

### Disaster recovery RTO/RPO

| Metric | Value |
|---|---|
| Recovery Time Objective (RTO) | < 2 hours |
| Recovery Point Objective (RPO) | < 24 hours (Free), < 5 minutes (Pro + PITR) |

---

## 3 · Content moderation policy

### Who can post content
- **Providers** can list places (`places.status` defaults to `pending`).
- **Regular users** can submit reviews (`reviews`) and abuse reports
  (`moderation_reports`).
- **Admins** can do everything.

### What gets reviewed
1. **Every new provider place** — sits in `pending` until an admin
   approves it from `/dashboard/places`. SLA: 24 hours (visible to the
   provider as a live countdown in the Hub).
2. **User-flagged reports** — when a user taps the flag icon on a place
   details page, a row lands in `moderation_reports`. Visible to admins
   at `/dashboard/reports`.

### Reason codes (user-facing)
```
spam       | إعلانات مزعجة
offensive  | محتوى مسيء
fake       | معلومات مزيفة
off_topic  | خارج الموضوع
illegal    | محتوى غير قانوني
harassment | تحرش
other      | أخرى
```

### Admin actions on reports
| Status | When to use |
|---|---|
| `open` | Default. Report just submitted, untouched. |
| `reviewed` | Admin saw the report but hasn't acted yet (e.g. waiting for the place owner to respond). |
| `actioned` | The reported content was hidden, edited, or the offending user warned/banned. |
| `dismissed` | Report was invalid (the user mass-flagged for a personal beef, etc). |

Every transition writes a row to `moderation_reports.resolution_note` so
the audit trail survives staff turnover.

### Provider appeals
If a place is rejected, the provider sees the admin's `rejection_reason`
plus an "طعن في قرار الرفض" button. The appeal lands in
`/dashboard/appeals`. Resolving the appeal as "تم الحل" auto-promotes the
place back to `approved` via trigger `sync_appeal_with_place` (0034).

### Hard limits
- Auto-reject any review longer than 4000 chars (`reviews.body CHECK`).
- Auto-reject any appeal message shorter than 5 chars (`place_appeals.message CHECK`).
- Auto-block accounts with > 10 dismissed reports filed in 24h
  (planned — `consume_rate_limit` infra exists; wire it on next sprint).

---

## Contacts

- DB / infra: ahmedessam.uiux@gmail.com
- Phone: 01036925982
- WhatsApp: 01050242285
