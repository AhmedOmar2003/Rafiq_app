import 'package:flutter/material.dart';

import 'package:rafiq_app/service/user_role_store.dart';
import 'package:rafiq_app/view/home/home_view.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';
import 'package:rafiq_app/view/provider/hub/provider_hub_screen.dart';

/// Shared post-authentication routing.
///
/// Used by `LoginScreen`, `RegisterScreen`, and the verify-OTP flow so the
/// app behaves consistently after auth: returning users skip the picker,
/// brand-new users see it. Mirrors the logic in [AuthGate].
///
///   * Has session + role chosen + provider → ProviderHub
///   * Has session + role chosen + regular  → HomeView
///   * Has session + no role chosen yet     → ChoiceScreen
class PostAuthRouter {
  PostAuthRouter._();

  /// Replaces the current route with the right home for this user.
  ///
  /// The role state is read from [UserRoleStore]; the caller is expected to
  /// have already restored it via `ensureLoaded()` (handled at app start).
  static void replaceWithHome(BuildContext context) {
    final store = UserRoleStore.instance;
    final WidgetBuilder builder;
    if (!store.hasChosenRole.value) {
      builder = (_) => ChoiceScreen(
            onPlanSelected: () {},
            onNoPlanSelected: () {},
            onNext: () {},
          );
    } else if (store.isProvider.value) {
      builder = (_) => const ProviderHubScreen();
    } else {
      builder = (_) => const HomeView();
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: builder),
      (_) => false,
    );
  }
}
