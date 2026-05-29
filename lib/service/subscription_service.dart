import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/models/subscription/plan.dart';
import 'package:rafiq_app/service/api_service.dart';

/// Reads the subscription catalog + the current provider's entitlement.
///
/// Design:
///   * Singleton — every screen uses [instance] so plan fetches are dedup'd.
///   * Catalog is loaded once per session (rarely changes). Force refresh via
///     [refreshCatalog].
///   * Entitlement is keyed by provider_id and cached for 60s — short enough
///     that upgrade flows feel instant, long enough that gating checks during
///     a form session don't hammer the DB.
///   * Every public read funnels through ValueNotifier so widgets can use
///     `ValueListenableBuilder` without manual rebuilds.
class SubscriptionService {
  SubscriptionService._();
  static final SubscriptionService instance = SubscriptionService._();

  static const Duration _entitlementTtl = Duration(seconds: 60);

  final ValueNotifier<List<SubscriptionPlan>> catalog =
      ValueNotifier<List<SubscriptionPlan>>(const []);
  final ValueNotifier<ProviderEntitlement> entitlement =
      ValueNotifier<ProviderEntitlement>(ProviderEntitlement.freeFallback);

  Future<List<SubscriptionPlan>>? _catalogInFlight;
  Future<ProviderEntitlement>? _entitlementInFlight;
  DateTime? _entitlementFetchedAt;
  String? _entitlementProviderId;

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // Catalog
  // ---------------------------------------------------------------------------

  Future<List<SubscriptionPlan>> loadCatalog({bool force = false}) {
    if (!force && catalog.value.isNotEmpty) return Future.value(catalog.value);
    final inFlight = _catalogInFlight;
    if (inFlight != null) return inFlight;
    final f = _fetchCatalog();
    _catalogInFlight = f;
    f.whenComplete(() => _catalogInFlight = null);
    return f;
  }

  Future<List<SubscriptionPlan>> refreshCatalog() => loadCatalog(force: true);

  Future<List<SubscriptionPlan>> _fetchCatalog() async {
    await ApiService.ensureSupabaseInitialized();
    final rows = await _client
        .from('subscription_plans')
        .select()
        .eq('is_public', true)
        .order('sort_order', ascending: true);
    final plans = (rows as List)
        .map((r) => SubscriptionPlan.fromRow(Map<String, dynamic>.from(r)))
        .toList(growable: false);
    catalog.value = plans;
    return plans;
  }

  // ---------------------------------------------------------------------------
  // Entitlement (current plan + limits)
  // ---------------------------------------------------------------------------

  /// Returns the entitlement for [providerId], cached for [_entitlementTtl].
  /// Falls back to [ProviderEntitlement.freeFallback] on any error so the
  /// UI never blocks because billing is down.
  Future<ProviderEntitlement> loadEntitlement(
    String providerId, {
    bool force = false,
  }) {
    final cachedFresh = !force &&
        _entitlementProviderId == providerId &&
        _entitlementFetchedAt != null &&
        DateTime.now().difference(_entitlementFetchedAt!) < _entitlementTtl;
    if (cachedFresh) return Future.value(entitlement.value);

    final inFlight = _entitlementInFlight;
    if (inFlight != null && _entitlementProviderId == providerId) {
      return inFlight;
    }

    final f = _fetchEntitlement(providerId);
    _entitlementInFlight = f;
    f.whenComplete(() => _entitlementInFlight = null);
    return f;
  }

  Future<ProviderEntitlement> _fetchEntitlement(String providerId) async {
    try {
      await ApiService.ensureSupabaseInitialized();
      final row = await _client
          .from('provider_current_plan')
          .select()
          .eq('provider_id', providerId)
          .maybeSingle();
      final ent = row == null
          ? ProviderEntitlement.freeFallback
          : ProviderEntitlement.fromRow(Map<String, dynamic>.from(row));
      _publish(providerId, ent);
      return ent;
    } catch (_) {
      _publish(providerId, ProviderEntitlement.freeFallback);
      return ProviderEntitlement.freeFallback;
    }
  }

  void _publish(String providerId, ProviderEntitlement ent) {
    _entitlementProviderId = providerId;
    _entitlementFetchedAt = DateTime.now();
    entitlement.value = ent;
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Stub for the real checkout flow. Production should hit an Edge Function
  /// that creates a Paymob/Stripe checkout session and returns a redirect URL.
  /// This call ONLY marks the intent so the rest of the UI can show the
  /// "pending" state — the entitlement won't change until the gateway
  /// webhook confirms payment and our `billing_events` row processes.
  Future<void> startCheckout({
    required String providerId,
    required PlanTier targetTier,
    required bool yearly,
  }) async {
    await ApiService.ensureSupabaseInitialized();
    await _client.rpc(
      'start_subscription_checkout',
      params: {
        '_provider_id': providerId,
        '_target_tier': targetTier.wire,
        '_yearly': yearly,
      },
    );
  }

  /// Cancel at end of current billing period (keeps benefits till period_end).
  Future<void> cancelAtPeriodEnd(String providerId) async {
    await ApiService.ensureSupabaseInitialized();
    await _client.rpc(
      'cancel_subscription_at_period_end',
      params: {'_provider_id': providerId},
    );
    await loadEntitlement(providerId, force: true);
  }
}
