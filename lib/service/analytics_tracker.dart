import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:rafiq_app/service/api_service.dart';

/// Wire-level event kind — mirrors the `analytics_event_kind` Postgres enum.
enum AnalyticsKind {
  placeImpression,
  placeOpen,
  placeFavorite,
  placeUnfavorite,
  placeShare,
  placeMapOpen,
  placePhoneCall,
  placeWebsiteClick,
  placeReviewSubmit,
  providerProfileView,
  recommendationShown,
  recommendationClick,
}

extension AnalyticsKindX on AnalyticsKind {
  /// Snake_case form Postgres accepts as the enum literal.
  String get wire {
    switch (this) {
      case AnalyticsKind.placeImpression: return 'place_impression';
      case AnalyticsKind.placeOpen: return 'place_open';
      case AnalyticsKind.placeFavorite: return 'place_favorite';
      case AnalyticsKind.placeUnfavorite: return 'place_unfavorite';
      case AnalyticsKind.placeShare: return 'place_share';
      case AnalyticsKind.placeMapOpen: return 'place_map_open';
      case AnalyticsKind.placePhoneCall: return 'place_phone_call';
      case AnalyticsKind.placeWebsiteClick: return 'place_website_click';
      case AnalyticsKind.placeReviewSubmit: return 'place_review_submit';
      case AnalyticsKind.providerProfileView: return 'provider_profile_view';
      case AnalyticsKind.recommendationShown: return 'recommendation_shown';
      case AnalyticsKind.recommendationClick: return 'recommendation_click';
    }
  }
}

/// In-memory event waiting to be flushed to Supabase.
@immutable
class _PendingEvent {
  const _PendingEvent({
    required this.kind,
    required this.occurredAt,
    this.placeId,
    this.providerId,
    this.cityId,
    this.categoryId,
    this.context = const <String, dynamic>{},
  });

  final AnalyticsKind kind;
  final DateTime occurredAt;
  final String? placeId;
  final String? providerId;
  final String? cityId;
  final String? categoryId;
  final Map<String, dynamic> context;

  Map<String, dynamic> toWire(String sessionId) {
    return {
      'kind': kind.wire,
      'session_id': sessionId,
      if (placeId != null) 'place_id': placeId,
      if (providerId != null) 'provider_id': providerId,
      if (cityId != null) 'city_id': cityId,
      if (categoryId != null) 'category_id': categoryId,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'context': context,
    };
  }
}

/// Fire-and-forget analytics emitter.
///
/// Buffers events in a bounded queue and ships them via the
/// `insert_event_batch` Postgres RPC every [_flushInterval] or whenever the
/// queue crosses [_batchSize] / the app pauses.
///
/// Guarantees:
///   * Calls to [track] never throw and never block (work happens async).
///   * Queue is bounded — under burst the oldest events are dropped, never
///     allowed to leak memory.
///   * Network failures don't lose user-visible work; events are kept in the
///     queue and retried on the next flush window.
class AnalyticsTracker with WidgetsBindingObserver {
  AnalyticsTracker._();
  static final AnalyticsTracker instance = AnalyticsTracker._();

  static const Duration _flushInterval = Duration(seconds: 5);
  static const int _batchSize = 25;
  static const int _maxQueue = 500;

  final Queue<_PendingEvent> _queue = Queue<_PendingEvent>();
  final String _sessionId = _generateSessionId();

  Timer? _flushTimer;
  bool _flushing = false;
  bool _attached = false;

  SupabaseClient get _client => Supabase.instance.client;

  /// Attach to widget binding to flush on app background.
  void attach() {
    if (_attached) return;
    WidgetsBinding.instance.addObserver(this);
    _startTimer();
    _attached = true;
  }

  void detach() {
    if (!_attached) return;
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _flushTimer = null;
    _attached = false;
  }

  /// Enqueue a single event. Returns instantly.
  void track(
    AnalyticsKind kind, {
    String? placeId,
    String? providerId,
    String? cityId,
    String? categoryId,
    Map<String, dynamic> context = const <String, dynamic>{},
  }) {
    final event = _PendingEvent(
      kind: kind,
      occurredAt: DateTime.now(),
      placeId: placeId,
      providerId: providerId,
      cityId: cityId,
      categoryId: categoryId,
      context: context,
    );

    // Bound the queue — drop oldest under back-pressure.
    if (_queue.length >= _maxQueue) {
      _queue.removeFirst();
    }
    _queue.addLast(event);

    if (_queue.length >= _batchSize) {
      // Fire a flush soon without blocking caller.
      unawaited(_flush());
    }
  }

  /// Force a synchronous flush attempt (best-effort). Useful before
  /// navigating away from a screen you want to be sure was logged.
  Future<void> flushNow() => _flush();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_flush());
    }
  }

  // ---------------------------------------------------------------------------
  // Internal
  // ---------------------------------------------------------------------------

  void _startTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer.periodic(_flushInterval, (_) => _flush());
  }

  Future<void> _flush() async {
    if (_flushing) return;
    if (_queue.isEmpty) return;
    _flushing = true;

    final batch = <_PendingEvent>[];
    while (batch.length < _batchSize && _queue.isNotEmpty) {
      batch.add(_queue.removeFirst());
    }

    try {
      await ApiService.ensureSupabaseInitialized();
      await _client.rpc(
        'insert_event_batch',
        params: {
          '_events': batch.map((e) => e.toWire(_sessionId)).toList(),
        },
      );
    } catch (_) {
      // Re-queue front so we don't lose the batch — capped at _maxQueue
      // so this can't grow unbounded across long offline periods.
      for (var i = batch.length - 1; i >= 0; i--) {
        if (_queue.length >= _maxQueue) break;
        _queue.addFirst(batch[i]);
      }
    } finally {
      _flushing = false;
    }
  }

  static String _generateSessionId() {
    // Lightweight UUIDv4-ish — no crypto dep. Good enough as a session
    // dimension; collisions across users are not a security concern.
    final ms = DateTime.now().millisecondsSinceEpoch;
    final rand = ms.hashCode ^ identityHashCode(Object());
    return '${ms.toRadixString(16)}-${rand.toUnsigned(32).toRadixString(16)}';
  }
}
