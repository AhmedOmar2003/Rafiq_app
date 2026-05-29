import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// App-wide connectivity state.
///
/// Offline-first foundation: a single source of truth for "are we online?" that
/// any widget, service or cubit can listen to. Exposes a [ValueListenable] so UI
/// can react (offline banner, disabling actions, queueing) without polling.
///
/// Note: this reflects *network reachability*, not server reachability. Pair it
/// with optimistic updates + cached reads for true offline-first behavior.
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final ValueNotifier<bool> _online = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _started = false;

  /// Listen to this to rebuild UI on connectivity changes.
  ValueListenable<bool> get online => _online;
  bool get isOnline => _online.value;

  Future<void> init() async {
    if (_started) return;
    _started = true;
    _apply(await _connectivity.checkConnectivity());
    _sub = _connectivity.onConnectivityChanged.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final bool connected = results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
    if (_online.value != connected) _online.value = connected;
  }

  /// Re-check on demand (e.g. from a "حاول تاني" button).
  Future<bool> refresh() async {
    _apply(await _connectivity.checkConnectivity());
    return _online.value;
  }

  void dispose() {
    _sub?.cancel();
    _online.dispose();
  }
}
