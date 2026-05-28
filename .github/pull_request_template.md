## Security checklist

- [ ] No secrets, tokens, or `.env` values are committed
- [ ] No `service_role` or admin bypass leaked into frontend code
- [ ] Supabase migrations are backwards-safe
- [ ] RLS or Edge Function changes were reviewed carefully
- [ ] Vercel / GitHub environment variables were updated if needed
- [ ] I ran the relevant build/lint checks
- [ ] I included rollback notes for risky changes

## Summary

Describe the change and why it is safe.

## Testing

List the commands you ran.

## Rollback

Describe how to revert if needed.
