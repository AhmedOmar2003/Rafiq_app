# Rafiq Design System & UX Architecture

> A complete, scalable design + UX + component system for the **Rafiq** product
> (Flutter mobile app — Android & iOS — plus the Admin Dashboard), built on the
> **existing brand identity**. Brand colors and personality are preserved; what
> changed is consistency, structure, accessibility, offline resilience, and
> developer handoff quality.

**Stack:** Flutter 3.41 · Dart 3.11 · `flutter_screenutil` (design size 390×844)
· `google_fonts` (Rubik) · `supabase_flutter` · RTL-first (Egyptian Arabic).

**Source of truth in code:**
- Tokens: `lib/core/design/tokens/` + `lib/core/utils/app_color.dart`
- Components: `lib/core/design/` and `lib/core/design/components/`
- Theme: `lib/core/themes/theme_services.dart`
- Microcopy: `lib/core/utils/app_microcopy.dart`
- Offline: `lib/service/connectivity_service.dart`

---

## 1. Product UX Audit

Rafiq is a **local discovery / recommendation app**: the user answers a 3-step
wizard (city → budget → activity) and receives place suggestions, with details,
reviews/evaluations, payments (Paymob/cash), an AI chat assistant, and auth.

### What was working
- Clear, friendly Egyptian-Arabic voice already present in places.
- Sensible information architecture (onboarding → choice → wizard → results → details).
- RTL handled globally; ScreenUtil for responsive sizing.
- Auth flow already had nice success moments and an OTP reset flow.

### What was broken (the real problems)
| # | Problem | Evidence in code (before) | Impact |
|---|---------|---------------------------|--------|
| 1 | **3 different button systems** | `AppButton`, `CustomStartButtonQuestionScreen`, theme `elevatedButtonTheme` — radii 8/12/15/25, font 15/24/25 | Inconsistent CTAs, no single source of truth |
| 2 | **2 conflicting input styles** | `AppInput` (radius 16 + shadow) vs `inputDecorationTheme` (radius 15 + border) | Forms look different screen to screen |
| 3 | **No spacing system** | only `verticalSpace()/horizontalSpace()`; magic numbers `15.h, 24.w, 32.h…` everywhere | Rhythm drifts; hard to maintain |
| 4 | **Size-named typography** | `textStyle16Light`, `textStyle24Medium` ×20 | Styles express pixels, not intent; duplication |
| 5 | **No semantic colors** | `Colors.red/green/yellow`, `Colors.redAccent`, `Colors.grey[500]`, `black.withOpacity()` inline | No success/warning/error language; off-brand reds |
| 6 | **Radius chaos** | 8, 12, 15, 16, 24, 25, 36 across files | Surfaces feel unrelated |
| 7 | **Inconsistent feedback** | mix of `Fluttertoast`, raw `SnackBar`, inline overlays; loading spinner was **red on black** | Jarring, off-brand, unpredictable |
| 8 | **No empty / error / offline components** | each screen invented its own, or showed raw `"...: $e"` to users | Technical errors leak; dead ends |
| 9 | **Broken dark mode** | `darkTheme` defined but commented out; `ThemeMode.system` would fall back to default dark | Random unusable screens on dark devices |
| 10 | **Duplicated success overlay** | login & register had ~80 identical lines each | Copy-paste drift |

### Audit verdict
The product had **good bones and good voice but no system**. The fix is not a
redesign — it is a **tokenization + componentization** pass that locks the
existing brand into reusable primitives.

---

## 2. Design System Strategy

**Principle:** *One brand, one token layer, one component layer, many screens.*

```
┌─────────────────────────────────────────────┐
│ Screens / Features (view/…, auth/…)          │  ← compose only
├─────────────────────────────────────────────┤
│ Components (AppButton, AppInput, AppCard…)    │  ← reusable, stateful UI
├─────────────────────────────────────────────┤
│ Theme (ThemeServices → ColorScheme)           │  ← Material defaults from tokens
├─────────────────────────────────────────────┤
│ Tokens (color/spacing/radius/type/motion…)    │  ← single source of truth
└─────────────────────────────────────────────┘
```

**Rules of the system**
1. Screens never hardcode a hex color, radius, font size, or spacing number.
   They reference tokens (`AppColor.*`, `AppSpacing.*`, `AppRadii.*`, `AppText.*`).
2. Semantic over raw: use `AppColor.error`, not `Colors.red`; `AppColor.textSecondary`, not `Colors.grey[600]`.
3. Components own their states (loading/disabled/error/pressed). Screens pass intent.
4. Microcopy lives in `AppCopy`, not inline strings.
5. Backward compatibility during migration: new `AppButton`/`AppInput` keep their
   old constructors, so the app keeps compiling while screens migrate incrementally.

---

## 3. Foundations

### 3.1 Color (brand preserved)
Base brand constants are **unchanged**: `primary #681F00`, `ofWhite #F7F3DA`,
`black #14171F`, plus the original grays. On top we derived scales + semantics.

| Role | Token | Value |
|------|-------|-------|
| Brand primary | `AppColor.primary` (=`primary500`) | `#681F00` |
| Primary tint (surfaces) | `primary50 / primary100` | `#FBEEE9 / #F3D4C7` |
| App background | `surface` (=`sand100`) | `#F7F3DA` |
| Card / input | `surfaceCard` | `#FFFFFF` |
| Text primary / secondary / tertiary | `textPrimary / textSecondary / textTertiary` | `#14171F / #707070 / #979797` |
| Border / divider | `border / divider` | `#E3E1DB / black@8%` |
| Success / Warning / Error / Info | `success / warning / error / info` | `#2E7D5B / #C9821E / #C5362F / #2C6E9B` |
| Each semantic soft bg | `*Bg` | tinted pastels |

Semantics are **warm-tuned** (no neon) so they sit beside the coffee-brown brand.
Dark-mode role tokens (`darkSurface*`, `darkText*`, `darkPrimary`) are defined for readiness.

### 3.2 Typography — Rubik, semantic scale
`AppText` (`tokens/app_typography.dart`) replaces 20 size-named styles with intent-named roles:

`displayLg/Md` · `headingLg/Md/Sm` · `titleLg/Md` · `bodyLg/Md/Sm` · `labelLg/Md/Sm` · `caption`.

Arabic legibility: generous line-height (1.4–1.55 body), medium weight for labels,
700 for display. One family (Rubik) keeps Arabic + Latin consistent.

### 3.3 Spacing — 4pt grid
`AppSpacing`: `xs4 · sm8 · md12 · lg16 · xl20 · xxl24 · xxxl32 · huge40 · giant48`.
Helpers `gapV(x)` / `gapH(x)` apply ScreenUtil. Page gutter = `xxl (24)`.

### 3.4 Radius
`AppRadii`: `sm8 (chips) · md12 (buttons/inputs) · lg16 (cards) · xl24 (sheets/dialogs) · xxl32 (hero/form tops) · pill`.
`AppRadii.topOnly(x)` for bottom-sheet/form panels.

### 3.5 Elevation
`AppShadows`: `level0` (flat) → `level3` (menus/dialogs), warm low-contrast,
plus `primaryGlow` for the single hero CTA. Cheap to render on low-end devices.

### 3.6 Motion, Breakpoints, A11y → see §10, §12, §13.

---

## 4. Component Library

All under `lib/core/design/` + `components/`. Import the barrel:
`import 'package:rafiq_app/core/design/components/components.dart';`

| Component | File | Purpose / variants |
|-----------|------|--------------------|
| **AppButton** | `app_button.dart` | variants: primary / secondary / outline / ghost / destructive; sizes sm/md/lg; `isLoading`, `isEnabled`, `icon`, `isFullWidth`; tactile press-scale |
| **AppInput** | `app_input.dart` | unified field: label/hint/helper, password toggle, validation states, RTL default |
| **AppCard** | `components/app_card.dart` | surface base; elevation 0–3; optional `onTap` with ink |
| **AppStateView** | `components/app_state_view.dart` | empty / search / error / offline — one component, friendly copy, optional retry |
| **AppSkeleton** | `components/app_skeleton.dart` | shimmer placeholders; `.card()`, `.list()`; respects reduce-motion |
| **LoadingManager** | `loading_manager.dart` | full-surface brand overlay + message (was red-on-black) |
| **AppFeedback** | `components/app_feedback.dart` | unified toasts: `success/error/warning/info`; context-free via navigator key |
| **AppBadge / AppChip** | `components/app_badge.dart` | status pill (tones) / selectable filter chip |
| **AppAvatar** | `components/app_avatar.dart` | image with initials fallback; never broken |
| **AppSuccessView** | `components/app_success_view.dart` | celebratory success moment (de-duped from login/register) |
| **AppConnectivityScope / offline banner** | `components/app_offline_banner.dart` | global friendly offline/online banner |
| **AppBottomSheet** | `core/logic/app_bottom_sheet.dart` | standardized sheet: handle, title, safe-area, xl radius |

### Still to build (specced, same patterns)
Dropdown, Tabs/segmented control, OTP field wrapper (around `pin_code_fields`),
Checkbox/Radio/Toggle wrappers, Date picker wrapper, File-upload tile,
Notification list item, Chat bubble, Table/DataGrid (dashboard), Charts (dashboard).
Each must consume tokens and expose explicit states (see §15).

---

## 5. Mobile UX Rules

1. **One primary action per screen.** Use `AppButton` primary; everything else is secondary/outline/ghost.
2. **Thumb-reachable CTAs.** Sticky bottom button bar (`level2` shadow) for wizard/forms.
3. **Forms:** label above field (optional), inline validation on submit, soft helper text, friendly errors (`AppCopy`). Never block typing.
4. **Lists:** skeletons while loading → content, or `AppStateView.empty` if none. Never a blank screen.
5. **Destructive actions** (logout, delete) use `destructive` variant + confirm dialog. Confirm color = `AppColor.error`.
6. **Feedback:** transient via `AppFeedback`; persistent state via `AppStateView`; blocking via `LoadingManager`.
7. **RTL everywhere.** Use `AlignmentDirectional`, `EdgeInsetsDirectional`; text defaults right.
8. **Tap targets ≥ 44×44.** Button min-heights: sm40/md52/lg58.

---

## 6. Dashboard UX Rules (Admin)

> There is no admin codebase yet. This is the architecture so the dashboard
> reuses the **same tokens & language** (build it in Flutter Web with this repo's
> `lib/core/design`, or mirror tokens 1:1 in a React/Tailwind theme — values in §14).

**Layout:** persistent left rail (RTL: right) nav, top bar (search + profile + env badge), content grid using `AppBreakpoints.columns()` (12 cols on `large`).

**Patterns**
- **Tables/DataGrid:** sticky header, zebra via `surfaceVariant`, row hover, status via `AppBadge` tones, right-aligned actions, pagination + page-size; empty → `AppStateView`.
- **Filters:** chip row (`AppChip`) + advanced filter sheet (`AppBottomSheet`) on mobile / inline popover on desktop.
- **Analytics cards:** `AppCard` (elevation 1) with metric (`displayMd`), label (`bodySm`), delta as `AppBadge` (success/error tone).
- **Bulk actions:** select-all + contextual action bar appears above the table; destructive bulk → confirm dialog.
- **Permissions UX:** hide actions the role can't perform; if shown-but-disabled, tooltip why. Gate routes, not just buttons.
- **Status systems:** standardized tones — `success`=نشط/مدفوع, `warning`=قيد المراجعة, `error`=مرفوض/متوقف, `neutral`=مسودة, `info`=جديد.
- **Admin forms:** same `AppInput`/`AppButton`; two-column on `expanded`+, single-column on `compact`.
- **Responsive:** rail collapses to icons on `medium`, becomes a drawer on `compact`; tables become stacked cards on `compact`.

---

## 7. Offline-first UX

**Goal:** the app stays usable and *kind* on weak/no internet.

**Implemented**
- `ConnectivityService` (`lib/service/connectivity_service.dart`): singleton with
  `ValueListenable<bool> online`, init + live updates via `connectivity_plus`, `refresh()`.
- `AppConnectivityScope` wraps the whole app (`rafiq_app.dart`): soft amber banner
  on disconnect with warm copy, brief green "رجع النت!" on reconnect, **never blocks** the UI.
- `AppStateView.offline(onAction:)` for full-screen offline-of-a-section.

**Strategy (recommended next steps)**
| Layer | Approach |
|-------|----------|
| Reads | Cache last successful results (e.g. suggestions, place details) via `shared_preferences`/local store; show cached + a "محفوظة" hint when offline. |
| Writes | **Optimistic updates**: apply locally, queue, sync on reconnect; on failure revert + `AppFeedback`. |
| Retry | Exponential backoff in `dio` interceptor; `AppStateView` retry buttons call the same loader. |
| Degradation | Disable only the actions that truly need network; keep navigation/cached content alive. |
| Sync | On `online → true`, flush the write queue; reconcile conflicts last-write-wins or prompt. |

**Tone example (already in `AppCopy`):**
> "النت واخد بريك صغير 😅 — أول ما يرجع هنكمّل علطول."

---

## 8. Error Handling System

**Layers**
1. **Validation (field):** soft, guiding — `AppCopy.fieldRequired`, `emailInvalid`, `passwordShort`. Shown inline under the field.
2. **Transient (action):** `AppFeedback.error/warning` — friendly, never raw `$e`.
3. **Sectional:** `AppStateView.error(onAction: retry)` when a whole view fails.
4. **Fatal:** global `ErrorWidget.builder` (in `rafiq_app.dart`) shows a friendly message; raw details only in debug.

**Hard rules**
- Never surface `Exception:`, stack traces, HTTP codes, or `$e` to users in release.
- Every error path offers a way forward (retry / go back / alternative) — **no dead ends**.
- Map technical → human at the boundary (services translate; UI shows `AppCopy`).

---

## 9. Microcopy Tone System

Centralized in `AppCopy` (`lib/core/utils/app_microcopy.dart`).

**Voice:** Egyptian colloquial, warm, light, respectful, human. The user should feel *"the app gets me."*

| Intent | Don't (robotic) | Do (Rafiq voice) |
|--------|------------------|------------------|
| Offline | "خطأ في الاتصال بالشبكة" | "النت واخد بريك صغير 😅 أول ما يرجع هنكمّل علطول" |
| Empty | "لا توجد نتائج" | "مفيش حاجة هنا لسه — جرّب تغيّر اختياراتك" |
| Error | "حدث خطأ: Exception…" | "حصل لخبطة بسيطة، جرّب تاني" |
| Validation | "حقل إلزامي" | "الحقل ده مهم، اكتبه عشان نكمّل" |
| Success | "تمت العملية بنجاح" | "تمام! اتعمل بنجاح ✅" |

**Rules:** short; one idea per message; emoji sparingly (max 1, only warm moments);
never blame the user; always say what happens next.

---

## 10. Accessibility System

- **Contrast:** body text on surfaces meets WCAG AA (textPrimary on sand/white ≈ 13:1; primary on white ≈ 9:1). Avoid text on `textTertiary` for body.
- **Tap targets:** ≥ 44×44 (enforced by button min-heights + icon-button padding).
- **Reduce motion:** `AppSkeleton` falls back to static; motion tokens expose `instant` — gate animations on `MediaQuery.disableAnimations`.
- **Dynamic type:** ScreenUtil `minTextAdapt: true`; `.sp` scales; avoid fixed-height text containers.
- **RTL:** full RTL via `Directionality` + directional insets/alignment.
- **Semantics:** give icon-only buttons `Semantics`/tooltip labels; inputs use real `labelText`/hint; decorative images `excludeSemantics`.
- **Focus:** brand focus ring on inputs (`focusedBorder` primary 1.5); ensure logical focus order in forms.

---

## 11. Performance Optimization Strategy

- **Image cache capped** already (`main.dart`: 120 items / 80MB). Keep network images sized; use `AppAvatar` loading/error builders.
- **Skeletons over spinners** for perceived speed; one shared `AnimationController` per skeleton.
- **Virtualize lists:** always `ListView.builder` / `Sliver*`; never build long lists eagerly.
- **Cheap shadows:** token shadows are single-layer, low-blur.
- **Const & small widgets:** prefer `const`, split big `build()` into methods/widgets (already a pattern).
- **Lazy init:** Supabase initializes lazily on first use (see `main.dart`).
- **Animations:** short durations (120–320ms), `easeOutCubic`; avoid continuous/decorative animation.
- **Avoid rebuild storms:** `ValueListenable` for connectivity; scope `setState`.

---

## 12. Responsive Behavior

`AppBreakpoints`: `compact <600 · medium <905 · expanded <1240 · large ≥1240`,
with `columns(context)` → 4/6/8/12. Helpers `isCompact/isMedium/isExpanded/isLarge`.

- **Mobile (compact):** single column, sticky bottom CTA, sheets for secondary flows.
- **Tablet (medium/expanded):** 2-column forms, wider content max-width, grid results.
- **Dashboard (large):** 12-col grid, persistent rail, multi-pane.
- ScreenUtil keeps proportional sizing on phones; breakpoints handle layout shape.

---

## 13. Motion System

`AppMotion`: `instant · fast 120ms · base 220ms · slow 320ms · toast 2.6s`;
curves `standard (easeOutCubic)`, `decelerate`, `emphasized (easeOutBack)`.

**Where motion is allowed:** press feedback (scale 0.97), state transitions
(`AnimatedSwitcher` base), banner slide-in, skeleton shimmer, success reveal.
**Where it's banned:** decorative loops, parallax, long hero animations on lists.
Principle: **motion clarifies, never decorates.**

---

## 14. Design Tokens (reference values)

> Mirror these exactly in any non-Flutter surface (dashboard React/Tailwind, email, Figma).

**Color (light)**
```
primary       #681F00   primary50 #FBEEE9   primary100 #F3D4C7
surface       #F7F3DA   surfaceCard #FFFFFF surfaceVariant #FDFCF4
textPrimary   #14171F   textSecondary #707070  textTertiary #979797
border        #E3E1DB   divider rgba(0,0,0,.08)
success #2E7D5B  warning #C9821E  error #C5362F  info #2C6E9B
successBg #E6F4EE  warningBg #FBF0DD  errorBg #FBE9E7  infoBg #E5F0F7
```
**Spacing (px):** 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40 · 48
**Radius (px):** 8 · 12 · 16 · 24 · 32 · 999
**Type (px / weight):** display 34/30·700 · heading 24/22/20·600 · title 18/16·500 · body 16/14/12·400 · label 16/14/12·500 · caption 11·400
**Shadow:** l1 `0 4 10 rgba(0,0,0,.06)` · l2 `0 6 16 rgba(0,0,0,.08)` · l3 `0 12 28 rgba(0,0,0,.12)`
**Motion (ms):** 120 · 220 · 320 · easeOutCubic

---

## 15. Component States

Every interactive component must define these explicitly:

| State | Button | Input | Card/Tile |
|-------|--------|-------|-----------|
| default | filled/variant | border `border` | elevation 1 |
| hover/pressed | scale 0.97, shadow off | — | ink highlight |
| focused | — | primary ring 1.5 | — |
| loading | spinner, no label | (disabled) | skeleton |
| disabled | opacity 0.5, no tap | opacity, no shadow | opacity |
| error | (destructive only) | error border + msg | — |
| empty/offline | — | — | `AppStateView` |

Naming convention for state booleans in widgets: `isLoading`, `isEnabled`, `isSelected`, `isError`.

---

## 16. Developer Handoff Structure

**Folder architecture**
```
lib/core/
  design/
    tokens/            ← app_spacing, app_radii, app_shadows, app_typography,
                         app_motion, app_breakpoints, tokens.dart (barrel)
    components/         ← app_card, app_state_view, app_skeleton, app_feedback,
                         app_badge, app_avatar, app_success_view, app_offline_banner,
                         components.dart (barrel)
    app_button.dart  app_input.dart  loading_manager.dart  …
  themes/theme_services.dart
  utils/app_color.dart  app_microcopy.dart  …
  logic/app_bottom_sheet.dart  helper_methods.dart
service/connectivity_service.dart
```

**Naming conventions**
- Tokens: `AppColor.*`, `AppSpacing.*`, `AppRadii.*`, `AppText.*`, `AppShadows.*`, `AppMotion.*`.
- Components: `App<Thing>`; variants via enums `App<Thing>Variant/Size/Tone`.
- Microcopy: `AppCopy.<intent>`.
- One import for everything UI: `components/components.dart` (+ `tokens/tokens.dart`).

**Migration recipe (per screen)**
1. Replace inline `ElevatedButton`/custom buttons → `AppButton(variant…)`.
2. Replace raw `SnackBar`/`Fluttertoast` → `AppFeedback.*`.
3. Replace magic numbers → `AppSpacing/AppRadii`; raw colors → `AppColor.*`; text styles → `AppText.*`.
4. Replace inline empty/error/loading → `AppStateView` / `LoadingManager` / `AppSkeleton`.
5. Move inline strings → `AppCopy`.
6. Run `flutter analyze` (target: no new errors).

---

## 17. Future Scalability Strategy

- **Theming:** dark mode is token-wired (`ThemeServices.darkTheme`); flip `ThemeMode.system` after a dark audit of screens. Multi-brand = swap the color scale, components unchanged.
- **Localization:** `AppCopy` is the single string surface → drop-in `intl`/ARB later (MSA vs Egyptian variants).
- **Shared core package:** extract `lib/core/design` into a Flutter package consumed by both app and (Flutter-web) dashboard.
- **Design tokens as data:** consider a `tokens.json` generated into Dart + CSS so design tools, app, and dashboard never drift (Style Dictionary).
- **Testing:** golden tests per component state; widget tests for forms; contract tests for services.

---

## 18. UX Problems Found + Solutions

| Problem (from §1) | Solution shipped |
|-------------------|------------------|
| 3 button systems | One `AppButton` with 5 variants/3 sizes; theme button defaults from tokens |
| 2 input styles | One token-driven `AppInput`; theme `inputDecorationTheme` aligned |
| No spacing/radius system | `AppSpacing` (4pt) + `AppRadii` ladders; `gapV/gapH` |
| Size-named type | Semantic `AppText` scale (Rubik) |
| Raw/off-brand colors | Full `AppColor` scales + semantics; warm-tuned status colors |
| Inconsistent feedback | `AppFeedback` + tokenized `LoadingManager` (brand spinner, not red-on-black) |
| Missing empty/error/offline | `AppStateView` (4 factories) + global offline banner |
| Broken dark mode | Coherent token-driven `darkTheme`; app pinned to brand light, dark ready |
| Duplicated success overlay | Single `AppSuccessView` reused by login/register/reset |
| Leaky technical errors | Friendly `AppCopy`; `$e` mapped at boundary; debug-only details |

---

## 19. Suggested Improvements (prioritized)

**P0 (consistency)**
- Migrate remaining screens (choice, onboarding, suggestions, details, evaluations, payments, chat, steps) using the §16 recipe.
- Replace deprecated `withOpacity` → `withValues` repo-wide (225 analyzer infos) in one sweep.

**P1 (resilience & UX)**
- Add read-caching for suggestions + place details (offline-first §7).
- Build the OTP/Checkbox/Radio/Toggle/Dropdown wrappers around existing deps.
- Standardize navigation (route table + typed args) instead of ad-hoc `MaterialPageRoute`.

**P2 (scale)**
- Extract `core/design` into a shared package; stand up the Flutter-web dashboard on it.
- Token pipeline (Style Dictionary) → Dart + CSS + Figma variables.
- Golden tests for every component state.

---

## 20. Final Unified System Architecture

```
                         ┌──────────────────────────────┐
                         │        Brand Identity         │  #681F00 · #F7F3DA · Rubik · RTL
                         └───────────────┬──────────────┘
                                         │
                    ┌────────────────────▼─────────────────────┐
                    │                TOKENS                      │
                    │ color · type · spacing · radius · shadow   │
                    │ motion · breakpoints  (+ microcopy AppCopy)│
                    └───────┬───────────────────────┬───────────┘
                            │                       │
              ┌─────────────▼──────┐      ┌─────────▼───────────┐
              │   THEME (Material)  │      │     COMPONENTS       │
              │ ColorScheme + button│      │ Button Input Card    │
              │ input sheet dialog… │      │ StateView Skeleton   │
              └─────────────┬──────┘      │ Feedback Badge Avatar │
                            │             │ SuccessView Offline   │
                            │             └─────────┬────────────┘
        ┌───────────────────┼────────────────────────┼──────────────────┐
        │                   │                        │                  │
   ┌────▼─────┐      ┌──────▼──────┐         ┌───────▼──────┐    ┌──────▼───────┐
   │  Auth     │      │  Discovery  │         │   Profile    │    │ Admin Dash.   │
   │ login/reg │      │ wizard/res. │         │  payments    │    │ (same tokens) │
   │ otp/reset │      │ details/AI  │         │  evaluations │    │ tables/charts │
   └───────────┘      └─────────────┘         └──────────────┘    └───────────────┘
        └───────────────── Offline-first scope (ConnectivityService) ──────────────┘
```

**The result:** one brand, one token layer, one component layer — unified, fast,
friendly, accessible, offline-aware, and ready to scale to the dashboard and beyond,
**without changing what makes Rafiq feel like Rafiq.**
