# RAFIQ — Project Guide for Claude Code

## Project Overview
RAFIQ is a Flutter mobile app (user + provider roles) paired with a Next.js admin dashboard. Both surfaces share the same Supabase backend.

## Repository Layout

```
rafiq_master/
├── lib/                          # Flutter source (main app)
│   ├── auth/                     # Login, register, forgot-password, OTP
│   ├── core/
│   │   ├── design/               # DESIGN SYSTEM — start here for any UI work
│   │   │   ├── tokens/           # colors, typography, spacing, radii, shadows, motion
│   │   │   ├── components/       # shared widgets (AppButton, AppCard, AppChip…)
│   │   │   ├── app_button.dart
│   │   │   ├── app_input.dart
│   │   │   ├── app_image.dart
│   │   │   └── loading_manager.dart
│   │   ├── utils/
│   │   │   ├── app_color.dart    # color tokens (also exported from tokens/)
│   │   │   └── app_microcopy.dart # ALL Egyptian-Arabic UI strings live here
│   │   ├── logic/                # helper methods, navigation
│   │   └── themes/               # ThemeData wiring
│   ├── model/ & models/          # data models
│   ├── service/                  # API calls, Supabase, auth, subscription
│   ├── view/                     # screens grouped by feature
│   │   ├── home/                 # multi-step preference picker
│   │   ├── details/              # place detail page
│   │   ├── evaluations/          # reviews
│   │   ├── pages/                # profile, choice, legal, step screens, suggestions
│   │   └── provider/             # hub, analytics, promotions, subscription
│   └── on_boarding/              # splash / onboarding
├── admin-dashboard-rafiq-app/    # Next.js 15 admin dashboard
│   └── src/
│       ├── app/
│       │   ├── globals.css       # CSS design tokens (:root variables)
│       │   └── dashboard/        # all admin pages (Server Components)
│       │       └── shared.module.css  # shared table/badge/filter/chip styles
│       ├── components/ui/        # reusable React components
│       └── lib/                  # Supabase clients, admin helpers
├── supabase/                     # migrations
└── assets/                       # images, SVG icons
```

## Design System

### Flutter tokens (import via `tokens.dart`)
| Token class | File | Purpose |
|-------------|------|---------|
| `AppColor` | `core/utils/app_color.dart` | All colors — use semantic tokens, not raw scale steps |
| `AppText` | `tokens/app_typography.dart` | Type scale: `bodyMd`, `titleLg`, `headingSm`… |
| `AppSpacing` | `tokens/app_spacing.dart` | 4pt grid: `xs=4 sm=8 md=12 lg=16 xl=20 xxl=24 xxxl=32` |
| `AppRadii` | `tokens/app_radii.dart` | `sm=8 md=12 lg=16 xl=24 xxl=32 pill=999` |
| `AppShadows` | `tokens/app_shadows.dart` | `level0..3`, `primaryGlow` |
| `AppMotion` | `tokens/app_motion.dart` | durations + curves |

### Flutter shared components (`components/components.dart`)
- `AppButton` — 5 variants (primary/secondary/outline/ghost/destructive), 3 sizes
- `AppCard` — surface container with elevation levels 0–3
- `AppChip` — selectable pill chip for filters and range selectors
- `AppInput` — unified text field (replaces all raw `TextField` usage)
- `AppStateView` — empty / error / offline / search-empty
- `AppSkeleton` — shimmer loading placeholder
- `AppFeedback` — toast/snackbar (success / warning / error / info)
- `AppCountdownBadge` — live HH:MM:SS pill countdown (for SLA timers)
- `AppBadge`, `PlanBadge`, `ProfilePill`, `AppAvatar`, `AppPageHeader`, `AppPageScaffold`
- `AppOfflineBanner`, `AppConfirmDialog`, `AppSuccessView`

### Admin CSS tokens (`globals.css` `:root`)
- `--color-primary: #681F00`, `--color-primary-alpha`, `--color-primary-hover`
- `--color-background: var(--sand-100)`, `--color-surface: #fff`
- `--radius-sm/md/lg/xl/pill`, `--space-xs/sm/md/lg/xl/2xl`
- Status: `--color-success/error/warning` + `-bg` / `-alpha` variants

### Admin shared UI
- `shared.module.css` — `.badge`, `.badgeSuccess`, `.badgeDanger`, `.badgeGold`, `.badgePurple`, `.badgeGray`, `.chip`, `.chipActive`, `.filterBar`, `.table`, `.emptyState`
- `StatusBadge` component at `components/ui/StatusBadge.tsx`

## Key Conventions

### Flutter
- **Copy**: All user-facing Arabic strings go in `AppCopy` (`app_microcopy.dart`). Never hardcode Arabic inline.
- **Layout**: Use `AppSpacing.*` tokens for margins/padding. Never use raw numbers.
- **Radius**: Always `AppRadii.rPill / rSm / rMd / rLg / rXl`. Never `BorderRadius.circular(N)`.
- **Colors**: Use semantic tokens (`AppColor.textSecondary`, `AppColor.surface`). Never raw hex.
- **RTL**: App is RTL. Directional padding uses `.w`/`.h` via ScreenUtil. Icons auto-mirror with Material RTL support.
- **Touch targets**: minimum 44×44pt. Chips/buttons use `48.h` height.
- **Loading**: use `AppSkeleton` for list/card loading, `CircularProgressIndicator` only inside tight containers.
- **Error/empty**: use `AppStateView.error()` / `.empty()` / `.search()` / `.offline()`.

### Admin (Next.js)
- Pages are Server Components; client components are isolated to interactive islands.
- Use CSS Modules (`shared.module.css` for shared patterns, page-local `.module.css` for one-offs).
- Never hardcode `#681F00` or hex colors inline — use `var(--color-primary)` etc.
- Status display: always use `<StatusBadge status={row.status} />` from `components/ui/StatusBadge`.
- No fake/placeholder data visible to users (no hardcoded counts, badges, or demo rows).

## Running the Apps

```bash
# Flutter mobile
cd D:\rafiq_master
flutter pub get
flutter run                     # debug on connected device/emulator
flutter analyze                 # lint check
flutter test                    # unit/widget tests

# Admin dashboard
cd D:\rafiq_master\admin-dashboard-rafiq-app
npm install
npm run dev                     # local dev server
npm run build                   # production build check
```

## Environment Setup
- Flutter: copy `.env.example` → `.env` and fill Supabase URL/anon key
- Admin: copy `.env.example` → `.env.local` and fill Supabase service key

## Do NOT
- Hardcode Supabase URLs or API keys anywhere
- Change Supabase schema or RLS policies without a migration file
- Remove working features or Supabase real-time subscriptions
- Introduce fake/mock data visible in production
- Use raw hex colors, magic radius numbers, or inline Arabic strings
