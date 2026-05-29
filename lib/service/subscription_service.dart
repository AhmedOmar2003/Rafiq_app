import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// SharedPreferences keys for the **demo** entitlement.
  /// They survive an app kill so the user keeps seeing the plan they
  /// "subscribed" to during the demo period.
  static const _kDemoTierKey = 'demo_entitlement_tier';
  static const _kDemoPeriodEndKey = 'demo_entitlement_period_end_iso';

  final ValueNotifier<List<SubscriptionPlan>> catalog =
      ValueNotifier<List<SubscriptionPlan>>(const []);
  final ValueNotifier<ProviderEntitlement> entitlement =
      ValueNotifier<ProviderEntitlement>(ProviderEntitlement.freeFallback);

  Future<List<SubscriptionPlan>>? _catalogInFlight;
  Future<ProviderEntitlement>? _entitlementInFlight;
  DateTime? _entitlementFetchedAt;
  String? _entitlementProviderId;
  bool _persistedRestored = false;

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

  // ---------------------------------------------------------------------------
  // DEMO: in-memory entitlement override
  // ---------------------------------------------------------------------------
  //
  // While the real payment gateway is being wired, the UI needs a way to
  // *show* what changes for each tier. [applyDemoUpgrade] takes a catalog
  // plan and synthesizes a [ProviderEntitlement] with a 30-day period and
  // the limits/flags from the catalog, then broadcasts it through the same
  // ValueNotifier the production path uses. This lets every screen react
  // (badges, manage section, current-plan highlight) without touching the
  // database.
  //
  // Remove the call site once the webhook flips real entitlement rows.

  /// Synthesize an entitlement from a catalog plan and publish it locally.
  /// Returns the entitlement that is now live for the rest of the session.
  ProviderEntitlement applyDemoUpgrade({
    required SubscriptionPlan plan,
    Duration period = const Duration(days: 30),
  }) {
    final now = DateTime.now();
    final ent = _buildDemoEntitlement(plan: plan, periodEnd: now.add(period));
    // Reset cache markers so the next real `loadEntitlement` call refreshes
    // from Supabase (production wins over demo).
    _entitlementFetchedAt = now;
    _entitlementProviderId = _entitlementProviderId ?? 'demo';
    entitlement.value = ent;
    unawaited(_persistDemoTier(plan.tier, ent.periodEnd));
    return ent;
  }

  /// Reset to Free baseline (demo helper for "downgrade" or "cancel").
  void applyDemoFree() {
    entitlement.value = ProviderEntitlement.freeFallback;
    unawaited(_clearDemoTier());
  }

  /// Restore a previously persisted demo upgrade. Idempotent — safe to call
  /// at every app start. Resolves immediately if the catalog isn't loaded
  /// yet (Free fallback stays until the catalog arrives, then this is
  /// re-attempted).
  Future<void> restorePersistedDemo() async {
    if (_persistedRestored) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final tierStr = prefs.getString(_kDemoTierKey);
      if (tierStr == null) {
        _persistedRestored = true;
        return;
      }
      final tier = PlanTierX.fromWire(tierStr);
      if (tier == PlanTier.free) {
        _persistedRestored = true;
        return;
      }

      // Resolve the matching plan in the catalog (load it if not cached).
      var plans = catalog.value;
      if (plans.isEmpty) {
        plans = await loadCatalog();
      }
      final plan =
          plans.firstWhere((p) => p.tier == tier, orElse: () => plans.first);

      final endIso = prefs.getString(_kDemoPeriodEndKey);
      final end = endIso != null
          ? DateTime.tryParse(endIso) ??
              DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30));

      // Expired demo → drop to free silently.
      if (end.isBefore(DateTime.now())) {
        await _clearDemoTier();
        _persistedRestored = true;
        return;
      }

      entitlement.value = _buildDemoEntitlement(plan: plan, periodEnd: end);
    } catch (_) {
      // Don't surface a startup failure for a demo nicety.
    } finally {
      _persistedRestored = true;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  ProviderEntitlement _buildDemoEntitlement({
    required SubscriptionPlan plan,
    required DateTime? periodEnd,
  }) {
    return ProviderEntitlement(
      tier: plan.tier,
      maxGalleryImages: plan.maxGalleryImages,
      maxVideos: plan.maxVideos,
      maxPlaces: plan.maxPlaces,
      maxCoverImages: plan.maxCoverImages,
      isVerified: plan.isVerified,
      hasAnalyticsBasic: plan.hasAnalyticsBasic,
      hasAnalyticsPro: plan.hasAnalyticsPro,
      hasPromotions: plan.hasPromotions,
      hasFeaturedSlot: plan.hasFeaturedSlot,
      hasPushCampaigns: plan.hasPushCampaigns,
      hasHomepageSpotlight: plan.hasHomepageSpotlight,
      hasPrioritySupport: plan.hasPrioritySupport,
      badgeLabel: plan.badgeLabel,
      periodEnd: periodEnd,
      cancelAtPeriodEnd: false,
    );
  }

  Future<void> _persistDemoTier(PlanTier tier, DateTime? end) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kDemoTierKey, tier.wire);
      if (end != null) {
        await prefs.setString(_kDemoPeriodEndKey, end.toIso8601String());
      } else {
        await prefs.remove(_kDemoPeriodEndKey);
      }
    } catch (_) {/* swallow */}
  }

  Future<void> _clearDemoTier() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDemoTierKey);
      await prefs.remove(_kDemoPeriodEndKey);
    } catch (_) {/* swallow */}
  }
}
