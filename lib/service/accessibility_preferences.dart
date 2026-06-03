import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityPreferences {
  AccessibilityPreferences._();
  static final AccessibilityPreferences instance =
      AccessibilityPreferences._();

  static const _textScaleKey = 'accessibility_text_scale';

  final ValueNotifier<double> textScale = ValueNotifier<double>(1.0);

  bool _loaded = false;
  Future<void>? _loadInFlight;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    final existing = _loadInFlight;
    if (existing != null) return existing;
    final future = _load();
    _loadInFlight = future;
    return future;
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getDouble(_textScaleKey) ?? 1.0;
      textScale.value = _normalizeScale(stored);
    } catch (_) {
      textScale.value = 1.0;
    } finally {
      _loaded = true;
      _loadInFlight = null;
    }
  }

  Future<void> setTextScale(double value) async {
    final normalized = _normalizeScale(value);
    textScale.value = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_textScaleKey, normalized);
    } catch (_) {
      // Keep the in-memory value even if persistence fails.
    }
  }

  double _normalizeScale(double value) => value.clamp(0.95, 1.35);
}
