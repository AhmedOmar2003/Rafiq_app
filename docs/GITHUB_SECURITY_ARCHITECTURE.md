# GitHub security architecture for Rafiq

## Recommended repository structure

```text
/
├── .github/
│   ├── CODEOWNERS
│   ├── SECURITY.md
│   ├── dependabot.yml
│   ├── pull_request_template.md
│   └── workflows/
├── admin-dashboard-rafiq-app/
├── docs/
├── lib/
├── scripts/
├── supabase/
│   ├── migrations/
│   ├── functions/
│   ├── templates/
│   └── seed.sql
├── .env.example
└── .gitignore
```

## GitHub settings to enforce

- Require 2FA for every collaborator
- Keep the repository private unless there is a hard business reason to open it
- Protect `main`
- Require pull requests before merge
- Require at least 1-2 approving reviews
- Dismiss stale approvals on new commits
- Block force pushes
- Block branch deletion
- Restrict who can push to protected branches
- Require status checks before merge
- Require conversation resolution
- Require signed commits for maintainers if the team can support it
- Use CODEOWNERS for `supabase/`, `.github/`, `admin-dashboard-rafiq-app/`, and `lib/`

## Branch protection recommendation

- `main` is the only protected release branch
- No direct pushes to `main`
- No merge without CI passing
- No merge without dependency review on PRs that touch lockfiles
- No merge without one reviewer from the security or platform owner group
- No bypasses for admins unless there is a documented emergency process

## Deployment guardrails

- Production deploys should only come from protected `main`
- Preview deploys should use isolated Vercel env vars
- Service role secrets must never be present in browser-facing bundles
- Supabase migrations must be reviewed separately from app code
- Any change touching auth, roles, RLS, or Edge Functions requires security review

## Safe contributor workflow

1. Branch from `main`
2. Keep changes small and scoped
3. Run local checks before pushing
4. Open a PR
5. Wait for CI, dependency review, and security scan
6. Require reviewer approval from code owners
7. Merge only after checks pass

