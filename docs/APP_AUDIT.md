# Rafiq — App Audit (Senior-engineer pass)

A focused review of the current state of the app, separating **real bugs**
from cosmetics, and listing what I changed in this round.

---

## 🔴 Critical — Navigation / IA

### 1. Profile is unreachable from the two primary screens

| Screen | How a user reaches Profile today |
|---|---|
| `HomeView` (regular user main) | ❌ No path. You'd have to complete 3 steps → fetch suggestions → tap an avatar in the suggestions header. |
| `ProviderHubScreen` (provider main) | ❌ No path. Provider can't log out without navigating *back to ChoiceScreen*. |

That's a fundamental SaaS-quality break. Profile is where logout, delete
account, change password, and subscription management live. It must be
reachable in 1 tap from any "home" surface.

**Fix:** added a top-right **profile pill** to both `HomeView` and
`ProviderHubScreen` headers. One tap → Profile.

---

### 2. Login / Register force you through ChoiceScreen

Even though `AuthGate` correctly routes based on `UserRoleStore.hasChosenRole`,
both `LoginScreen` and `RegisterScreen` `pushReplacement(ChoiceScreen(...))`
unconditionally on success. That means:
- A returning provider who has already subscribed sees the choice screen
  again after re-login. They have to tap "تابع خدمتك" → tap continue
  → land in the hub.
- A returning regular user sees the same friction.

**Fix:** post-auth routing now mirrors `AuthGate`: if the user has a saved
role, go directly to their home; otherwise show `ChoiceScreen`.

---

### 3. Back / exit goes to ChoiceScreen

Both `HomeView._exitToChoice` and `ProviderHubScreen._goBackToChoice` push
`ChoiceScreen` with `pushAndRemoveUntil`. Semantically wrong:
- The user already chose; bouncing them to the picker is confusing.
- Doing it as the **back action** breaks the OS-level expectation that
  hardware back / gesture back closes the top-level surface (or backgrounds
  the app).

**Fix:** hardware back from the two main surfaces now backgrounds the app
(`SystemNavigator.pop`). Switching role is an explicit action inside
Profile (see #5).

---

### 4. No way to switch role without logging out

If a regular user wants to add their business, the only path today is:
logout → login → choose role. That's hostile.

**Fix:** added a "Switch role" entry in Profile. Tapping it:
- toggles `UserRoleStore.isProvider`
- navigates to the appropriate home (`HomeView` or `ProviderHubScreen`)
- preserves their session, their subscription state, everything

---

## 🟠 High — Feature completeness

### 5. Promotions screen has a fake CTA

`PromotionsScreen` shows an empty state with a button **"اعمل حملة جديدة"**.
On tap it calls `AppFeedback.info(AppCopy.loadingSuggestions)` — i.e. it
shows "بندوّرلك على أحلى أماكن..." which is the loading copy from another
flow. Completely disconnected.

**Status:** unchanged in this round (real campaign form requires a creator
screen which is its own scope). I've made the CTA a clear "coming soon"
inline note instead of a broken handler. → Fixed below.

### 6. Analytics screen is decorative

`AnalyticsScreen` shows synthetic numbers that scale by tier. That sells
the upgrade story but doesn't show *the user's own data*. Until the
rollups job is wired, the screen labels itself as "demo data" so the
provider isn't confused.

### 7. `chat.dart` (Bot screen) is mounted in the bottom bar of HomeView

It uses Google Generative AI directly with an API key configured in the
client. That's a **security issue** for production (the key ships with the
APK) and a UX gap if the key isn't set. Out of scope for this round but
flagged.

---

## 🟡 Medium — Consistency

### 8. HomeView gates everything behind 3 mandatory steps

A regular user can't browse, can't see featured places, can't see anything
until they fill all 3 inputs. No discovery flow, no "popular near you".
This is product-level scope; flagging it but not fixing.

### 9. Some dialog/sheet copies still inline

- `provider_hub_screen.dart` line 151-153: `'حذف المكان'`, `'هل تريد حذف "${place.name}"؟'`, `'حذف'` — inline strings, should be in `AppCopy`.
- `provider_hub_screen.dart` line 182, 190: hardcoded `'تابع خدماتك'` and `'رجوع'`.

Fixed inline in this round where I touched the file.

### 10. Asset weight

`assets/` is **6.8 MB**. That's mostly two onboarding/choice images at
multi-MB each. Re-encoded as WebP they'd drop to under 1 MB total. Flagged.

---

## 🟢 Low — Cosmetics

- The HomeView title still uses an unstyled "step counter" line; should
  read as a subhead.
- The ProviderHub plan-summary card and KPI strip duplicate information.

---

## ✅ What I fixed in this round

1. Added profile pill to `HomeView` and `ProviderHubScreen` headers.
2. Rewrote `_handleNavigation` on login/register to honor the saved role.
3. Replaced `_exitToChoice` / `_goBackToChoice` with `SystemNavigator.pop`
   on the two main surfaces. The user backgrounds the app instead of
   bouncing.
4. Added a **Switch role** row in Profile that flips role + jumps to
   the correct home.
5. Centralized hub copy (`hubBackLabel`, `hubSwitchRole`, the delete-place
   dialog strings) into `AppCopy`.
6. Made the Promotions "create" CTA disable + show a clear "coming soon"
   pill instead of firing the wrong toast.

---

## 🟥 Known and not-yet-fixed

- Payment gateway wiring (`startCheckout` RPC needs an Edge Function).
- `BotScreen` API key shipped in client.
- HomeView gating (3-step requirement before any content).
- Real campaign form for Promotions.
- Asset compression.

These are listed so they're not forgotten, but they each need their own
focused PR.
