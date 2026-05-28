# Incident response checklist

## If a secret leaks

1. Rotate the secret immediately
2. Revoke the old credential
3. Check Git history, CI logs, Vercel logs, and issue attachments
4. Purge the secret from the repo if it was committed
5. Force re-deploy affected services
6. Review access logs for abuse
7. Document root cause and prevention

## If a Supabase key leaks

- Revoke the exposed key or rotate the Supabase project credentials
- Confirm no service-role key remains in frontend code
- Check Edge Function secrets and Vercel server envs

## If an admin account is compromised

- Disable the account
- Revoke sessions
- Reset MFA
- Review `admin_logs`
- Review `user_roles` changes
- Review recent Edge Function activity

## If the dashboard is compromised

- Pause production deploys
- Remove affected GitHub tokens and Vercel tokens
- Invalidate all admin sessions
- Compare deployed artifact hash against last known-good build
- Re-deploy from a clean commit after triage

