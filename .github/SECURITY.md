# Security policy

## Reporting a vulnerability

If you discover a security issue in Rafiq, report it privately to the
maintainers instead of opening a public issue or PR.

Include:
- affected component
- impact
- reproduction steps
- possible fix
- whether secrets, auth, RLS, or deployment access are involved

## Handling sensitive findings

- Do not post secrets, tokens, or database credentials in issues.
- Rotate any exposed credentials immediately.
- Treat Supabase service-role keys, Vercel tokens, SMTP credentials, and
  private keys as high-severity secrets.

## Response targets

- Acknowledge: within 1 business day
- Triage: within 2 business days
- Containment or rollback: immediately for active exposure
