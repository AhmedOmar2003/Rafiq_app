import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight flag that records whether the signed-in user has chosen the
/// **provider** track in the choice screen.
///
/// Why a dedicated store?
///   • The provider track unlocks a different IA (Provider Hub, Subscription,
///     Promotions). Profile screens need to react instantly when the flag
///     flips — ValueNotifier gives us that for free.
///   • Persisting the choice (SharedPreferences) means we don't re-ask after
///     a cold start; the same user keeps the same surfaces.
///   • Logout / role downgrade clears the flag.
///
/// Note: this is the *client-side intent*. The authoritative role check still
/// happens server-side via the `provider` row + RLS policies.
class UserRoleStore {
  UserRoleStore._();
  static final UserRoleStore instance = UserRoleStore._();

  static const _kIsProviderKey = 'is_provider_role';
  static const _kRoleChosenKey = 'role_chosen';
  static const _kEverProviderKey = 'ever_chosen_provider_role';

  final ValueNotifier<bool> isProvider = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasChosenRole = ValueNotifier<bool>(false);
  final ValueNotifier<bool> hasProviderHistory = ValueNotifier<bool>(false);

  bool _loaded = false;
  Future<void>? _loadInFlight;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    final inFlight = _loadInFlight;
    if (inFlight != null) return inFlight;
    final f = _load();
    _loadInFlight = f;
    return f;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isProvider.value = prefs.getBool(_kIsProviderKey) ?? false;
      hasChosenRole.value = prefs.getBool(_kRoleChosenKey) ?? false;
      hasProviderHistory.value =
          prefs.getBool(_kEverProviderKey) ?? isProvider.value;
    } catch (_) {
      // Treat as regular user on failure.
    } finally {
      _loaded = true;
      _loadInFlight = null;
    }
  }

  Future<void> setProvider(bool value) async {
    isProvider.value = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      final hadProviderHistory =
          prefs.getBool(_kEverProviderKey) ?? hasProviderHistory.value;
      final nextProviderHistory = hadProviderHistory || value;
      await prefs.setBool(_kIsProviderKey, value);
      await prefs.setBool(_kRoleChosenKey, true);
      await prefs.setBool(_kEverProviderKey, nextProviderHistory);
      hasChosenRole.value = true;
      hasProviderHistory.value = nextProviderHistory;
    } catch (_) {/* swallow */}
  }

  Future<void> chooseRegularUser() async => setProvider(false);

  Future<void> chooseProvider() async => setProvider(true);

  Future<void> resetRoleChoice() async {
    isProvider.value = false;
    hasChosenRole.value = false;
    hasProviderHistory.value = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kIsProviderKey);
      await prefs.remove(_kRoleChosenKey);
      await prefs.remove(_kEverProviderKey);
    } catch (_) {/* swallow */}
  }

  Future<void> clear() => resetRoleChoice();
}
