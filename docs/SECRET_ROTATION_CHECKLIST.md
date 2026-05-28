# Secret rotation checklist

## Rotate immediately when

- a secret appears in Git history
- a secret is posted in a ticket, log, or chat
- a contributor leaves the team
- a third-party integration is changed
- a key has not been rotated for 90-365 days, depending on sensitivity

## Rotation order

1. Generate new secret
2. Add it to the target secret store
3. Deploy consumers with the new secret
4. Verify the new secret is working
5. Revoke the old secret
6. Revoke any derived sessions/tokens if needed
7. Record the rotation date and owner

## High-priority secrets

- Supabase service role key
- Supabase access token
- Vercel token
- SMTP password
- Google OAuth client secret
- JWT signing secret

## Verification

- The old secret no longer works
- The new secret works in preview and production where intended
- No client bundle contains server-only secrets
- GitHub Actions secrets are updated where required

