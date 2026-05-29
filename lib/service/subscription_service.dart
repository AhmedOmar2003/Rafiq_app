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

  /// Transition the caller to [plan].
  ///
  /// Goes through the `apply_demo_subscription` SECURITY DEFINER RPC so the
  /// chosen tier becomes a real row in `provider_subscriptions`. That keeps
  /// `provider_current_plan` and the local notifier in sync — the bug where
  /// the plan reverted to Free on the next bootstrap (because the DB still
  /// reported Free) is fixed at the source.
  ///
  /// Returns the entitlement that is now live for the session. UI updates
  /// instantly — the round-trip to the DB happens in the background and only
  /// gates persistence, not the local broadcast.
  Future<ProviderEntitlement> applyDemoUpgrade({
    required SubscriptionPlan plan,
    bool yearly = false,
    String? providerId,
    Duration period = const Duration(days: 30),
  }) async {
    final now = DateTime.now();
    final ent = _buildDemoEntitlement(plan: plan, periodEnd: now.add(period));

    // 1. Publish locally first so the UI flips immediately.
    final pid = providerId ?? _entitlementProviderId;
    _entitlementFetchedAt = now;
    if (pid != null && pid != 'demo') _entitlementProviderId = pid;
    entitlement.value = ent;
    unawaited(_persistDemoTier(plan.tier, ent.periodEnd));

    // 2. Persist to the DB so the row is real. If this fails (offline,
    //    auth race), the local override + SharedPrefs still hold until the
    //    next online attempt.
    try {
      await ApiService.ensureSupabaseInitialized();
      await _client.rpc<dynamic>(
        'apply_demo_subscription',
        params: {'_tier': plan.tier.wire, '_yearly': yearly},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('apply_demo_subscription RPC failed: $e');
    }

    return ent;
  }

  /// Drop to Free both locally and in the DB (cancels any active row).
  Future<void> applyDemoFree({String? providerId}) async {
    entitlement.value = ProviderEntitlement.freeFallback;
    unawaited(_clearDemoTier());
    try {
      await ApiService.ensureSupabaseInitialized();
      await _client.rpc<dynamic>(
        'apply_demo_subscription',
        params: {'_tier': 'free', '_yearly': false},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('apply_demo_subscription(free) failed: $e');
    }
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

      // Reconcile with the DB only when needed. If the previous upgrade
      // crashed between the local publish and the RPC, the DB still
      // reports a different (usually Free) tier. We check first to avoid
      // resetting period_start on every app launch — the RPC cancels and
      // re-inserts, which would restart the 30-day timer each restore.
      unawaited(_reconcilePersistedTierWithDb(tier));
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

  /// Read the live tier from `provider_current_plan` and, if it doesn't
  /// match the persisted demo tier, replay the RPC. Cheap no-op in the
  /// happy path (one SELECT, no write).
  Future<void> _reconcilePersistedTierWithDb(PlanTier persistedTier) async {
    try {
      await ApiService.ensureSupabaseInitialized();
      final uid = _client.auth.currentUser?.id;
      if (uid == null) return; // Not signed in yet — nothing to reconcile.

      final row = await _client
          .from('provider_current_plan')
          .select('tier, provider_id')
          .maybeSingle();

      final dbTierStr = row?['tier'] as String?;
      final dbTier = dbTierStr == null
          ? PlanTier.free
          : PlanTierX.fromWire(dbTierStr);

      if (dbTier == persistedTier) return; // Already in sync.

      // Mismatch → the last upgrade never persisted. Re-issue the RPC.
      await _client.rpc<dynamic>(
        'apply_demo_subscription',
        params: {'_tier': persistedTier.wire, '_yearly': false},
      );
      if (kDebugMode) {
        debugPrint(
          'Reconciled persisted demo tier ${persistedTier.wire} '
          'against DB tier ${dbTier.wire}.',
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('reconcile persisted demo tier failed: $e');
      }
    }
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
