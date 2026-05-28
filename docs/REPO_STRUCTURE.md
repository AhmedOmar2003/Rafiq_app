# Recommended repository structure

```text
/
├── .github/
│   ├── CODEOWNERS
│   ├── SECURITY.md
│   ├── dependabot.yml
│   ├── pull_request_template.md
│   └── workflows/
├── admin-dashboard-rafiq-app/
│   ├── .env.example
│   ├── .husky/
│   ├── package.json
│   └── src/
├── docs/
├── lib/
├── scripts/
├── supabase/
│   ├── .env.example
│   ├── config.toml
│   ├── functions/
│   ├── migrations/
│   ├── seed.sql
│   └── templates/
└── .env.example
```

## Security notes

- Keep `service_role` keys server-side only
- Keep browser-facing code on the anon key only
- Keep Supabase migrations reviewed like code
- Keep generated artifacts out of Git
- Keep all auth and role checks server-side for the dashboard
