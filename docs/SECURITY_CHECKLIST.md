# Rafiq Security Checklist

Pre-release gates. Every item must be ✅ before promoting to production.
This list is derived from `S & P/release-checklist.md` and adapted to the
Supabase + Flutter stack.

---

## 1. Secrets & configuration

- [ ] `SUPABASE_SERVICE_ROLE_KEY` is in **Vercel env (server) + Supabase
      function secrets only**. Not in any frontend bundle. Confirm via
      `grep -r "service_role" lib/` (must be empty) and Vercel build logs.
- [ ] `SUPABASE_ANON_KEY` is the only Supabase key embedded in the Flutter
      app and the public Next.js bundle.
- [ ] Google OAuth client secret is in Supabase Auth provider config only.
- [ ] All keys are rotated at least once per year; rotation procedure
      documented in the runbook.

## 2. Authentication

- [ ] Email confirmation is **ON** (Auth → Providers → Email).
- [ ] "Confirm signup" email template contains `{{ .Token }}` (6 digits)
      rather than `{{ .ConfirmationURL }}` — otherwise the OTP flow breaks.
- [ ] Password recovery template likewise uses `{{ .Token }}`.
- [ ] Auth rate limits configured (Auth → Rate limits): OTP/hr ≤ 10,
      Sign-ups/hr ≤ 30 per IP.
- [ ] `Site URL` and `Redirect URLs` only contain trusted hosts
      (your Vercel production domain + `rafiqapp://` deep link).
- [ ] Multi-factor is enabled for every admin / super_admin account.
- [ ] Password policy enforced client-side **and** rejected by Supabase
      (Auth → Password requirements).

## 3. RBAC integrity

- [ ] `user_roles` has **no** INSERT / UPDATE / DELETE policy. Verify:
      `select polname from pg_policies where tablename='user_roles' and cmd<>'SELECT'`
      should return zero rows.
- [ ] No `role` column on `profiles`.
- [ ] Profile UPDATE policy excludes `is_disabled`, `deleted_at` from
      caller mutations. Verified via integration test
      `test/rls/profile_cannot_self_disable.sql`.
- [ ] At least one `super_admin` exists. Document who.
- [ ] `assign-role` Edge Function rejects self-assignment (test:
      super_admin grants themselves admin → 403).

## 4. RLS coverage

- [ ] `select tablename from pg_tables t where schemaname='public' and not exists
      (select 1 from pg_policies p where p.tablename=t.tablename)` returns
      ZERO rows. (Every table has at least one policy.)
- [ ] `select tablename from pg_tables where schemaname='public' and rowsecurity=false`
      returns ZERO rows. (RLS is ON for every table.)
- [ ] Anon role cannot read `profiles`. Verified by
      `set role anon; select * from public.profiles limit 1;` → 0 rows.
- [ ] Anon role cannot read `user_roles`, `admin_logs`,
      `moderation_history`, `login_attempts`, `rate_limit_buckets`.

## 5. Storage

- [ ] Each bucket has `file_size_limit` and `allowed_mime_types` set
      (verify via Supabase Studio → Storage → bucket settings).
- [ ] `provider-documents` bucket is **private** (`public=false`).
- [ ] Storage RLS checks `(storage.foldername(name))[1]` against the
      owner key for every write/delete policy.
- [ ] Client renames uploaded files to a UUID before upload (never trusts
      `file.name`).
- [ ] Document access is only via `sign-document-url` Edge Function;
      no public download URL pattern exists.

## 6. Edge Functions

- [ ] Every function calls `requireAuth(req, '<role>')` as its first
      authenticated step.
- [ ] No function logs the JWT, password, or document contents to stdout.
- [ ] `ALLOWED_ORIGINS` env var is set in production (no `*` fallback).
- [ ] Every privileged write calls `logAdmin(...)` before returning.
- [ ] Functions reject bodies > 100 KB at the framework layer.

## 7. Audit & monitoring

- [ ] `admin_logs` is append-only — verified by the `deny_mutation()`
      trigger. Try `update admin_logs set action='x' where id=...` → error.
- [ ] At least one alert configured for: > N failed logins / 5 min for a
      single email; > N moderation rejections / day for a single moderator.
- [ ] Backups: Supabase daily PITR enabled. Confirm restoration drill
      ran in the last quarter.

## 8. Anti-abuse

- [ ] `consume_rate_limit` wired in client paths that submit content
      (places, reviews, abuse reports).
- [ ] Provider self-review is rejected by RLS — integration test asserts
      this.
- [ ] Unique constraint `(place_id, user_id)` on reviews prevents
      review spam.
- [ ] Abuse-report intake (`moderation_reports`) has a rate limit.

## 9. Client-side hardening

- [ ] Flutter app uses HTTPS-only URLs; cleartext traffic disabled in
      `AndroidManifest.xml` (`android:usesCleartextTraffic="false"`).
- [ ] Supabase session is stored in secure storage (default for
      `supabase_flutter` 2.x).
- [ ] Admin dashboard uses `httpOnly`, `Secure`, `SameSite=Lax` cookies
      for the Supabase session (set by `@supabase/auth-helpers-nextjs`).
- [ ] Admin routes are protected by middleware that calls
      `getUser()` server-side and checks the role from `user_roles`.
- [ ] Content-Security-Policy header set on the admin dashboard.
- [ ] No `dangerouslySetInnerHTML` in admin dashboard with user content.

## 10. Privacy

- [ ] Personal fields (`profiles.phone`, `profiles.email`) never appear
      in public catalogue queries — confirm with the explain plan for
      `select * from places ... join provider_id`.
- [ ] Avatar URL is generated on the client; storage path doesn't reveal
      stable user identifiers (we use `<user_uuid>/avatar.jpg` which
      requires guessing a 128-bit UUID).
- [ ] Account deletion path soft-deletes `profiles`, revokes all
      `user_roles`, cascades to provider/places.

## 11. Performance gates

- [ ] Catalogue read path uses `places_browse_idx` (verify with EXPLAIN).
- [ ] `places.rating_avg` populated by trigger (never computed at read
      time in the hot path).
- [ ] All list endpoints are paginated (no unbounded selects).
- [ ] Image uploads compressed client-side before send.

## 12. Pre-deploy script

```bash
# Run before every prod deploy
supabase db lint              # static checks
supabase test db              # if you've added pgTAP tests
supabase functions deploy --no-verify-jwt=false ...
```
