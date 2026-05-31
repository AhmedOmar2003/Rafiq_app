import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rafiq_app/service/api_service.dart';

/// Lightweight flag that records whether the signed-in user has chosen the
/// **provider** track in the choice screen.
///
/// Why a dedicated store?
///   • The provider track unlocks a different IA (Provider Hub, Subscription,
///     Promotions). Profile screens need to react instantly when the flag
///     flips — ValueNotifier gives us that for free.
///   • SharedPreferences keeps the last known state available instantly, while
///     the backend `profiles.account_mode` is the cross-device source of truth.
///   • Logout / role downgrade clears the flag.
///
/// The authoritative provider history still comes from the backend
/// (`providers` row + subscriptions). This store mirrors that into fast local
/// notifiers and keeps the current surface choice in sync with Supabase.
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
  Future<void>? _refreshInFlight;

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
      _publish(
        isProviderMode: prefs.getBool(_kIsProviderKey) ?? false,
        hasChosen: prefs.getBool(_kRoleChosenKey) ?? false,
        hasHistory: prefs.getBool(_kEverProviderKey) ??
            (prefs.getBool(_kIsProviderKey) ?? false),
      );

      // Cross-device truth lives in Supabase. If this request fails (offline,
      // transient auth race), we still keep the last-known local state so the
      // UI remains usable.
      await refreshFromBackend();
    } catch (_) {
      // Treat as regular user on failure.
    } finally {
      _loaded = true;
      _loadInFlight = null;
    }
  }

  Future<void> refreshFromBackend() {
    final inFlight = _refreshInFlight;
    if (inFlight != null) return inFlight;
    final f = _refresh();
    _refreshInFlight = f;
    return f;
  }

  Future<void> _refresh() async {
    try {
      final snapshot = await ApiService().fetchAccountModeSnapshot();
      if (snapshot == null) return;

      if (snapshot.hasChosenRole) {
        await _persistState(
          isProviderMode: snapshot.isProviderMode,
          hasChosen: true,
          hasHistory: snapshot.hasProviderHistory,
        );
        return;
      }

      // Legacy installs may still know the choice locally while the backend
      // column is null. Seed the backend exactly once from the device state.
      if (hasChosenRole.value) {
        await ApiService().persistAccountMode(
          isProviderMode: isProvider.value,
        );
        await _persistState(
          isProviderMode: isProvider.value,
          hasChosen: true,
          hasHistory: snapshot.hasProviderHistory || hasProviderHistory.value,
        );
        return;
      }

      await _persistState(
        isProviderMode: false,
        hasChosen: false,
        hasHistory: snapshot.hasProviderHistory,
      );
    } catch (_) {
      // Keep local last-known state.
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<void> setProvider(bool value) async {
    final nextHistory = hasProviderHistory.value || value;
    await _persistState(
      isProviderMode: value,
      hasChosen: true,
      hasHistory: nextHistory,
    );
    try {
      await ApiService().persistAccountMode(isProviderMode: value);
    } catch (_) {
      // Local state stays updated; next backend refresh will retry.
    }
  }

  Future<void> chooseRegularUser() async => setProvider(false);

  Future<void> chooseProvider() async => setProvider(true);

  Future<void> resetRoleChoice() async {
    _publish(
      isProviderMode: false,
      hasChosen: false,
      hasHistory: false,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kIsProviderKey);
      await prefs.remove(_kRoleChosenKey);
      await prefs.remove(_kEverProviderKey);
    } catch (_) {/* swallow */}
  }

  Future<void> clear() => resetRoleChoice();

  Future<void> _persistState({
    required bool isProviderMode,
    required bool hasChosen,
    required bool hasHistory,
  }) async {
    _publish(
      isProviderMode: isProviderMode,
      hasChosen: hasChosen,
      hasHistory: hasHistory,
    );
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kIsProviderKey, isProviderMode);
      await prefs.setBool(_kRoleChosenKey, hasChosen);
      await prefs.setBool(_kEverProviderKey, hasHistory);
    } catch (_) {
      // Keep in-memory state even if local persistence fails.
    }
  }

  void _publish({
    required bool isProviderMode,
    required bool hasChosen,
    required bool hasHistory,
  }) {
    isProvider.value = isProviderMode;
    hasChosenRole.value = hasChosen;
    hasProviderHistory.value = hasHistory;
  }
}
