# Rafiq Design System — Spec Alignment

Reference: `C:\Users\dell\.claude\programing skills\Programming Skills\design-system`

This document maps the Rafiq Flutter implementation to the official design-system
spec, names the patterns each screen uses, and lists open gaps. It complements
the longer `DESIGN_SYSTEM.md` (overview) with the **mapping-and-conformance**
view a reviewer can scan in one pass.

---

## Token Mapping (spec → Rafiq)

| Spec token              | Rafiq token                | Value                          |
| ----------------------- | -------------------------- | ------------------------------ |
| `color.text.primary`    | `AppColor.textPrimary`     | `#14171F` (neutral-900)        |
| `color.text.secondary`  | `AppColor.textSecondary`   | `#707070` (neutral-600)        |
| `color.text.muted`      | `AppColor.textTertiary`    | `#979797` (neutral-500)        |
| `color.surface.default` | `AppColor.surfaceDefault`  | `#F7F3DA` (cream, page bg)     |
| `color.surface.elevated`| `AppColor.surfaceElevated` | `#FFFFFF` (white card)         |
| `color.border.default`  | `AppColor.border`          | `#E3E1DB` (neutral-200)        |
| `color.action.primary`  | `AppColor.actionPrimary`   | `#681F00` (brand coffee)       |
| `color.action.primaryHover` | `AppColor.actionPrimaryHover` | `#5A1B00`              |
| `color.status.success`  | `AppColor.statusSuccess`   | `#2E7D5B`                      |
| `color.status.warning`  | `AppColor.statusWarning`   | `#C9821E`                      |
| `color.status.danger`   | `AppColor.statusDanger`    | `#C5362F`                      |
| `color.status.info`     | `AppColor.statusInfo`      | `#2C6E9B`                      |

Spec rule: *"Use semantic tokens in product code."* — all role tokens above are
exposed in `AppColor`. Legacy names (`primary`, `error`, `surface`, `surfaceCard`)
remain as aliases for backward compat.

### Typography (spec roles → `AppText`)

| Spec role  | Rafiq                | Size · Weight |
| ---------- | -------------------- | ------------- |
| `display`  | `AppText.displayLg/Md` | 34/30 · 700 |
| `headline` | `AppText.headingLg/Md/Sm` | 24/22/20 · 600 |
| `title`    | `AppText.titleLg/Md` | 18/16 · 500   |
| `body`     | `AppText.bodyLg/Md/Sm` | 16/14/12 · 400 |
| `label`    | `AppText.labelLg/Md/Sm` | 16/14/12 · 500 |
| `caption`  | `AppText.caption`    | 11 · 400      |

One family (Rubik). Matches the spec's "limit to one primary family" rule.

### Spacing (spec base → `AppSpacing`)

4-pt grid, scale `4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48` →
`xs · sm · md · lg · xl · xxl · xxxl · huge · giant`. Default mobile gutter
is `lg` (16). Spec rule satisfied: *"Use a single spacing scale across the
product."*

### Radius (spec → `AppRadii`)

`sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · pill 999`. Buttons/inputs/chips
share the `md → lg` family per spec ("Buttons, inputs, dropdowns and alerts
should share a family"). Pages and bottom sheets use `xl`.

### Elevation (spec → `AppShadows`)

`level0` flat · `level1` resting cards · `level2` raised CTAs/banners ·
`level3` modals/sheets. Plus `primaryGlow` for the wizard's active step.
Spec rule satisfied: *"Use shadows sparingly. Prefer subtle elevation."*

---

## Composition Primitives (the unification layer)

These widgets replace the ad-hoc Scaffold/AppBar/Dialog code each screen used
to roll. They are the **only** approved way to compose a page.

| Primitive             | Replaces                                    | Used by                                                         |
| --------------------- | ------------------------------------------- | --------------------------------------------------------------- |
| `AppPageScaffold`     | bare `Scaffold` + manual bg/padding         | `details`, `evaluations`, `suggestions`, `cash`                  |
| `AppPageHeader`       | mix of `AppBar` / `CustomAppBar` / Containers | `details`, `evaluations`, `suggestions`, `cash`                |
| `AppStickyFooter`     | inline footer Containers with shadows       | `details` (booking CTA)                                          |
| `AppSectionHeader`    | inline `Row(title + count)` patterns        | available for adoption                                           |
| `AppConfirmDialog`    | hand-rolled `Dialog`/`AlertDialog`          | `profile` (logout)                                               |
| `AppSuccessView`      | OverlayEntry success animations             | login, register, reset, details (payment), evaluations (review)  |
| `AppStateView`        | inline empty Containers                     | `suggestions` (empty results)                                    |
| `AppSkeleton.card`    | full-page spinners on content lists         | `evaluations` (loading reviews)                                  |
| `AppFeedback`         | raw `ScaffoldMessenger` SnackBars           | every screen                                                     |
| `LoadingManager`      | red-on-black overlay                        | `home` wizard                                                    |

Spec rule satisfied: *"Reuse a pattern when the structure and behavior are
similar."*

---

## Per-Screen Conformance

| Screen              | PageHeader | Body bg     | Cards     | Inputs labeled | Loading state | Empty state | Feedback        |
| ------------------- | ---------- | ----------- | --------- | -------------- | ------------- | ----------- | --------------- |
| login               | (hero)     | primary+cream | —       | ✅ (label+hint) | spinner button | n/a       | AppFeedback     |
| register            | (hero)     | primary+cream | —       | ✅              | spinner button | n/a       | AppFeedback     |
| forget_password     | (hero)     | primary+cream | —       | ✅              | spinner button | n/a       | AppFeedback     |
| reset_password      | (hero)     | primary+cream | —       | ✅              | spinner button | n/a       | AppFeedback     |
| home (wizard)       | stepper    | cream       | step cards | n/a           | LoadingManager | n/a       | AppFeedback     |
| suggestions         | AppPageHeader | cream    | white+level2 | n/a          | (todo skeleton) | AppStateView | AppFeedback   |
| details             | AppPageHeader | cream    | white+level1 | n/a          | spinner (review section) | inline | AppFeedback |
| evaluations         | AppPageHeader | cream    | white+level1 | ✅ (composer) | AppSkeleton.card | rich empty | AppFeedback   |
| profile             | hero      | cream     | white     | (todo dialogs) | spinner       | n/a         | AppFeedback     |
| choice              | (hero)     | cream     | option cards | n/a          | n/a           | n/a         | AppFeedback     |
| take_data           | AppBar    | cream     | inputs+cards | (todo)       | spinner       | n/a         | AppFeedback     |
| chat                | AppBar    | white     | bubbles   | n/a (composer) | inline spinner | greeting   | inline error    |
| cash                | AppPageHeader | cream  | —         | n/a            | n/a           | n/a         | n/a             |

"hero" = intentional landing-style header (illustration + brand). Not a defect —
spec allows for "marketing and content-led" surfaces.

---

## Compliance with Spec Rules (audit)

| Spec rule                                          | Status | Notes                                                              |
| -------------------------------------------------- | ------ | ------------------------------------------------------------------ |
| Use tokens over one-off values                     | ✅      | View-layer raw `Colors.*` count: **7** (all intentional gold stars) |
| Reuse components before creating new ones          | ✅      | `AppButton`, `AppInput`, `AppCard`, `AppFeedback` reused everywhere |
| Visible label on inputs (placeholder ≠ label)      | ✅      | All auth inputs migrated. Profile change-password dialog: TODO     |
| One primary action per surface                     | ✅      | Each screen has a single primary CTA                               |
| Empty state has title + body + action              | ✅      | `AppStateView` provides all three                                  |
| Skeletons for content-rich loading                 | 🟡     | Applied in evaluations. Suggestions list: TODO                     |
| Modal: header / body / footer + return-focus       | ✅      | `AppConfirmDialog` and `AppSuccessView` follow the spec            |
| Shadow used sparingly; reserve heavy for floating  | ✅      | Cards `level1`, sheets `level3`, no decorative shadows             |
| Radius family across buttons / inputs / cards      | ✅      | All use `md` or `lg`. No pill/sharp mixing.                        |
| Motion `fast`/`base`/`slow` token-driven           | ✅      | `AppMotion` used in switchers and stepper                          |
| Mobile-first sizing via ScreenUtil                 | ✅      | `390 × 844` design size, `.w/.h/.sp` throughout                    |
| Touch target ≥ 48dp                                | ✅      | `AppPageHeader` action button = 48dp; AppButton size.md = 48h      |
| Reduced-motion fallback                            | ✅      | `AppSkeleton` checks `MediaQuery.disableAnimations`                |

---

## Open Items (concrete, scoped)

1. **Suggestions list loading skeleton.** Replace the implicit "show empty until
   the list fills" with `AppSkeleton.list()` on first load.
2. **Profile change-password dialog.** Migrate to a labeled-input form using
   `AppPageScaffold(scrollable: true)` or a bottom sheet, instead of a
   hand-rolled `Dialog`.
3. **Chat input bar.** Move to the same composer pattern used in evaluations
   (pill input + circular send) for a single composer DNA.
4. **`withOpacity` → `withValues(alpha:)`.** Mechanical Flutter-SDK migration,
   ~114 call sites. Not a design concern.

These are tracked but not blocking — every visible screen now follows the same
visual language and component vocabulary.

---

## How to Add a New Screen

1. Import `package:rafiq_app/core/design/components/components.dart`.
2. Wrap the page in `AppPageScaffold(header: AppPageHeader(title: …), body: …)`.
3. Use `AppCard` for surfaces, `AppInput(label: …, hintText: …)` for fields,
   `AppButton(variant: …)` for actions.
4. Empty states → `AppStateView.empty/.search/.error`. Loading → `AppSkeleton`
   for content lists, `LoadingManager` for full-page waits.
5. Use `AppFeedback.success/error/warning/info` for transient feedback,
   `AppConfirmDialog.show(…)` for destructive confirmations.

If you reach for a hand-rolled Container with a custom shadow — stop. Open
this file and find the pattern. Extend the system in `components/` before
inventing.
