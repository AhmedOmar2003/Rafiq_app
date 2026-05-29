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

  final ValueNotifier<bool> isProvider = ValueNotifier<bool>(false);

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
      await prefs.setBool(_kIsProviderKey, value);
    } catch (_) {/* swallow */}
  }

  Future<void> clear() => setProvider(false);
}
