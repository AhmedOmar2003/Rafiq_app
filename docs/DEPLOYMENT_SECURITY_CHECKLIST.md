# Deployment security checklist

## Before merge

- [ ] No secrets in code, comments, or screenshots
- [ ] `.env.example` updated when env vars change
- [ ] Supabase migrations are backwards-safe
- [ ] RLS policies reviewed
- [ ] Edge Functions reject unauthenticated requests
- [ ] Dashboard auth still verifies role server-side
- [ ] Google Sign-In redirect URLs are allowed in Supabase Auth
- [ ] No hardcoded admin passwords or bypass cookies exist

## Before production deploy

- [ ] `main` is protected
- [ ] CI passed
- [ ] Dependency review passed
- [ ] Secret scan passed
- [ ] Vercel preview/prod env vars are separated
- [ ] `SUPABASE_SERVICE_ROLE_KEY` exists only in server-side envs
- [ ] `ALLOWED_ORIGINS` is set to production domains only
- [ ] MFA is enabled for admin accounts
- [ ] Rollback plan is known

## Production runtime checks

- [ ] `X-Frame-Options`, `CSP`, and `HSTS` are active
- [ ] Server actions do not trust client role claims
- [ ] Edge Functions log privileged writes via `logAdmin(...)`
- [ ] Rate limiting is enabled on login and sensitive endpoints
- [ ] Public clients only use the anon key

