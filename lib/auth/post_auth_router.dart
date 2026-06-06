import 'package:flutter/material.dart';

import 'package:rafiq_app/service/api_service.dart';
import 'package:rafiq_app/service/profile_image_store.dart';
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
  static Future<void> replaceWithHome(BuildContext context) async {
    final store = UserRoleStore.instance;
    await ProfileImageStore.instance.refresh();
    await store.ensureLoaded();
    await store.refreshFromBackend();
    if (!context.mounted) return;
    if (!store.hasChosenRole.value) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ChoiceScreen(
            onPlanSelected: () {},
            onNoPlanSelected: () {},
            onNext: () {},
          ),
        ),
        (_) => false,
      );
      return;
    }

    if (store.isProvider.value) {
      final providerId = await ApiService().ensureCurrentProviderId();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => ProviderHubScreen(providerId: providerId),
        ),
        (_) => false,
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeView()),
      (_) => false,
    );
  }
}
