# Rafiq Backend Architecture

Production-grade Supabase backend for the Rafiq mobile app + admin dashboard.

> **Source of truth.** SQL files in `supabase/migrations/` are authoritative.
> Edge Functions in `supabase/functions/` carry the privileged write paths.
> This document explains *why* the pieces fit together — not how to type SQL.

---

## 1. Stack

| Layer            | Tech                                          |
| ---------------- | --------------------------------------------- |
| Database         | PostgreSQL 15+ on Supabase                    |
| Extensions       | pgcrypto, citext, pg_trgm, unaccent, postgis  |
| Auth             | Supabase Auth (email + password + 6-digit OTP, Google OAuth) |
| Authorization    | RLS + dedicated `user_roles` table (RBAC)     |
| Storage          | Supabase Storage (4 buckets, RLS-enforced)    |
| Privileged writes| Deno Edge Functions, service-role gated       |
| Mobile           | Flutter + `supabase_flutter`                  |
| Admin dashboard  | Next.js on Vercel + Supabase JS client        |
| Notifications    | disabled for now                              |

---

## 2. Folder layout

```
supabase/
├── migrations/
│   ├── 0001_extensions_and_enums.sql
│   ├── 0002_helper_functions.sql
│   ├── 0003_profiles_and_roles.sql
│   ├── 0004_taxonomy.sql
│   ├── 0005_providers.sql
│   ├── 0006_places.sql
│   ├── 0007_reviews_favorites_notifications.sql
│   ├── 0008_moderation_and_audit.sql
│   ├── 0009_rls_policies.sql
│   ├── 0010_triggers.sql
│   ├── 0011_storage_buckets.sql
│   └── 0012_disable_favorites_notifications.sql
├── functions/
│   ├── _shared/
│   │   ├── auth.ts             # JWT + RBAC guard, audit logger
│   │   └── cors.ts
│   ├── approve-provider/
│   ├── reject-provider/
│   ├── approve-place/
│   ├── reject-place/
│   ├── suspend-provider/
│   ├── assign-role/
│   └── sign-document-url/
└── seed.sql                    # cities + categories (run once)
```

---

## 3. Data model (ER overview)

```
auth.users (Supabase managed)
  └─ profiles            1:1   personal display info
  └─ user_roles          1:N   one row per granted role (the RBAC source)
  └─ providers           1:1   business profile (only if intended_role=provider)
                          └─ provider_documents   N   KYC (private storage)
                          └─ provider_requests    N   submission timeline
  └─ places               N
                                └─ place_images   N
                                └─ reviews        N
  └─ favorites           disabled for now
  └─ notifications       disabled for now

  Reference tables (admin-writable):
    cities · categories

  Moderation & audit (append-only for non-service-role):
    moderation_reports · moderation_history · admin_logs

  Anti-abuse:
    rate_limit_buckets · login_attempts
```

Every mutable table has `id uuid`, `created_at`, `updated_at`. Soft-delete is via
`deleted_at` on the tables that need it (`profiles`, `providers`, `places`,
`reviews`).

---

## 4. RBAC — why two tables instead of `profiles.role`

The textbook mistake is putting `role` on `profiles` and writing
`update on profiles using (auth.uid() = id)`. That single policy lets the user
flip themselves to `admin` with one PATCH.

**Rafiq does this instead:**

- `profiles` — owner-writable, *no role column*.
- `user_roles(user_id, role)` — append-only-ish (soft revoke). **No** RLS write
  policy. Only the service role and Edge Functions can grant/revoke.
- RLS policies and triggers always check the role via the SECURITY DEFINER
  helpers `public.has_role(...)`, `is_admin()`, `is_moderator_or_above()`.

Roles, lowest → highest:

```
user · provider · moderator · admin · super_admin
```

Grants are done via the `assign-role` Edge Function (super_admin only,
self-assignment forbidden, every change written to `admin_logs`).

---

## 5. Authentication flows

### 5.1  Email + password + 6-digit OTP (primary)

```
Flutter                                Supabase
  │                                       │
  │  signUpWithEmailOtp(name,email,pwd)   │
  │ ────────────────────────────────────▶ │  POST /auth/v1/signup
  │                                       │  creates unconfirmed auth.users row
  │                                       │  sends "Confirm signup" email
  │                                       │  containing {{ .Token }} (6 digits)
  │                                       │
  │  user receives email                  │
  │                                       │
  │  verifySignUpOtp(email, code)         │
  │ ────────────────────────────────────▶ │  POST /auth/v1/verify
  │                                       │  type=signup
  │ ◀──────────────────────────────────── │  returns Session
  │                                       │  trigger handle_new_user runs:
  │                                       │   - inserts profiles row
  │                                       │   - inserts user_roles('user')
  │                                       │
  ▼
session live; UI proceeds to home
```

**Supabase configuration required (one-time):**

| Setting                                              | Value                          |
| ---------------------------------------------------- | ------------------------------ |
| Auth → Providers → Email → Enable email confirmations| ON                             |
| Auth → Email templates → "Confirm signup" body       | contains `{{ .Token }}`        |
| Auth → URL config → Site URL                         | your deep link / web origin    |
| Auth → Rate limits → OTP/hour                        | ≤ 10                           |

### 5.2  Google OAuth

```
signInWithGoogle()  ─▶  Supabase opens system browser  ─▶  Google consent
   ─▶  redirect to rafiqapp:// (or https for web)
   ─▶  Supabase exchanges code, issues Session
   ─▶  handle_new_user trigger (only on first sign-in) creates profile + role
```

Dashboard → Auth → Providers → Google: enable, paste client ID + secret.
Add `rafiqapp://` (or the Vercel domain) to **Redirect URLs**.

### 5.3  Password reset

Existing `sendPasswordResetOtp` + `verifyPasswordResetOtp` flow. Uses
`OtpType.recovery`. Already wired in the Flutter app.

### 5.4  Why not store the password before OTP verification?

Supabase's `signUp` does — the password is hashed and stored on the
unconfirmed row. The OTP only flips `email_confirmed_at`. This is the
recommended pattern; rolling our own would introduce more surface area than
it removes.

---

## 6. Provider moderation workflow

```
1. User signs up with intended_role='provider' (set via Edge Function or
   admin-blessed app metadata).
2. handle_new_user grants the 'provider' role on user creation.
3. Provider creates a row in `providers` (status='pending') — RLS enforces
   owner_id = auth.uid() and forbids self-approval.
4. Provider uploads KYC docs to provider-documents storage bucket (PRIVATE).
5. Moderator queries the moderation queue:
     select * from providers where status in ('pending','under_review');
6. Moderator opens documents via /sign-document-url (5-min signed URL).
7. Decision:
     POST /approve-provider { provider_id, notes }
     POST /reject-provider  { provider_id, reason }
8. Trigger `guard_provider_moderation` writes a row to `moderation_history`.
9. Edge Function writes `admin_logs` row for the provider.
```

Place submissions follow the same pattern (`approve-place` / `reject-place`).

A **suspended** provider keeps their row but loses public visibility; the
`suspend-provider` Edge Function cascades the suspension to all of their
places.

---

## 7. Public visibility rules

| Table              | Anon read?                       | Conditions                              |
| ------------------ | -------------------------------- | --------------------------------------- |
| cities, categories | yes                              | `is_active = true`                      |
| providers          | yes                              | `status = 'approved' AND deleted_at IS NULL` |
| places             | yes                              | same                                    |
| place_images       | yes                              | parent place visible                    |
| reviews            | yes                              | parent place approved · `is_hidden = false` · `deleted_at IS NULL` |
| profiles           | **NO**                           | always behind auth                       |
| user_roles         | **NO**                           | self-row only when authenticated         |
| moderation_*       | **NO**                           | moderator+ only                          |
| admin_logs         | **NO**                           | admin+ only                              |
| storage:avatars / place-images / banners | yes (public buckets) | |
| storage:provider-documents | **NO**                  | signed URLs from Edge Function only      |

---

## 8. Storage strategy

| Bucket             | Public | Max size | MIME allowlist                                | Path layout                  |
| ------------------ | ------ | -------- | --------------------------------------------- | ---------------------------- |
| avatars            | ✅     | 2 MB     | image/{png,jpeg,webp}                         | `<user_uuid>/<file>`         |
| place-images       | ✅     | 5 MB     | image/{png,jpeg,webp}                         | `<provider_uuid>/<file>`     |
| provider-documents | ❌     | 10 MB    | application/pdf, image/{png,jpeg,webp}        | `<provider_uuid>/<file>`     |
| banners            | ✅     | 5 MB     | image/{png,jpeg,webp}                         | `banners/<file>`             |

The path's first segment is the **owner key**. Storage RLS verifies the
caller owns that key — preventing IDOR (User A uploading into User B's folder).

Files are renamed on upload (UUID-prefixed) by the client to avoid extension
collisions; never trust the client filename.

---

## 9. Edge Functions (privileged actions)

All functions follow the same shape:

```ts
1. Parse + validate body
2. requireAuth(req, 'moderator')   // throws 401/403 on mismatch
3. Do the work via service-role serviceClient
4. notify(...) target user (currently disabled)
5. logAdmin(...) write the audit row
6. Return JSON
```

The shared helper is in `supabase/functions/_shared/auth.ts`. It re-validates
the JWT against GoTrue every call and reads the role from `user_roles` (never
from JWT claims, which could be stale).

| Function              | Min role     | Effect                                            |
| --------------------- | ------------ | ------------------------------------------------- |
| approve-provider      | moderator    | status=approved, ensures provider role           |
| reject-provider       | moderator    | status=rejected                                  |
| approve-place         | moderator    | status=approved                                  |
| reject-place          | moderator    | status=rejected                                  |
| suspend-provider      | admin        | cascade-suspend provider and their places         |
| assign-role           | super_admin  | grant/revoke role, self-assignment forbidden      |
| sign-document-url     | user         | returns 5-min signed URL after ACL check          |

---

## 10. Anti-abuse

| Vector                | Defence                                                  |
| --------------------- | -------------------------------------------------------- |
| Brute-force login     | `login_attempts` table; combine with Supabase Auth limits + IP-based `consume_rate_limit('login', ip)` |
| Spam place submissions| `consume_rate_limit('submit_place', user_id, 5, '1 hour')` in client → server-side trigger optional |
| Fake reviews          | unique (place_id, user_id); provider can't review own place (RLS); abuse reports |
| Mass abuse reports    | `consume_rate_limit('report_abuse', user_id, 20, '1 day')` |
| Privilege escalation  | `user_roles` is service-role only; trigger blocks moderation column writes |
| IDOR on storage       | RLS checks first path segment against ownership          |
| Sensitive data leaks  | profiles & user_roles are auth-only; admin logs never include passwords/tokens |

---

## 11. Performance & scaling

- Every public catalogue query has a **partial covering index**
  (`places_browse_idx`, `places_search_idx`, `reviews_place_idx`) that filters
  on `status='approved' AND deleted_at IS NULL` — the planner uses these
  directly instead of scanning suspended/rejected rows.
- Trigger-maintained denormalized counters (`places.rating_avg`,
  `places.rating_count`) avoid expensive `AVG/COUNT` per request.
- PostGIS `geography` column on `places.location` with a GIST index enables
  radius queries (`ST_DWithin(location, ST_MakePoint(lng, lat)::geography, 5000)`)
  without table scans.
- Trigram (`pg_trgm`) GIN indexes on `places.name`, `cities.name_ar`,
  `providers.business_name` make fuzzy search fast.
- Pagination model: keyset by `(rating_avg desc, created_at desc, id)` —
  add this clause as the last cursor in the `places_browse_idx` query for
  stable, cheap "load more".

---

## 12. Operational invariants

These are facts that must remain true for the system to be safe:

1. **Anon role can never read `profiles`, `user_roles`, `admin_logs`,
   `moderation_*`.** Verified by the RLS policy set; double-check periodically
   with `select * from pg_policies where schemaname='public'`.
2. **`user_roles` has no INSERT/UPDATE/DELETE policy.** Adding one would
   open privilege escalation; reviews must reject such PRs.
3. **`moderation_history` and `admin_logs` are append-only.** Enforced by
   the `deny_mutation()` trigger; if you need to "fix" a row, write a new
   row that supersedes it.
4. **Service role key never appears in client code.** It lives in Vercel
   env vars and Supabase function secrets only.
5. **Edge Functions never trust JWT claims for role.** Always re-read
   `user_roles`.

---

## 13. Local dev quickstart

```bash
# One-time
supabase login
supabase link --project-ref <ref>

# Apply migrations
supabase db push          # or `supabase db reset` for clean local

# Run functions locally
supabase functions serve approve-provider --env-file ./supabase/.env.local

# Deploy
supabase db push          # remote
supabase functions deploy approve-provider
supabase functions deploy reject-provider
supabase functions deploy approve-place
supabase functions deploy reject-place
supabase functions deploy suspend-provider
supabase functions deploy assign-role
supabase functions deploy sign-document-url
```

Set Vercel env vars: `SUPABASE_URL`, `SUPABASE_ANON_KEY`,
`SUPABASE_SERVICE_ROLE_KEY` (server-side only), `ALLOWED_ORIGINS`.
