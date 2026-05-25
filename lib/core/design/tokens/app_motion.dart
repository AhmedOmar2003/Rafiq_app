import 'package:flutter/animation.dart';

/// Motion tokens.
///
/// Principle: motion clarifies, never decorates. Durations are short so the app
/// feels fast on low-end devices. Use [fast] for taps/toggles, [base] for most
/// transitions, [slow] only for full-screen or hero changes.
///
/// Accessibility: when MediaQuery.disableAnimations is true (OS "reduce motion"),
/// callers should fall back to [instant].
class AppMotion {
  AppMotion._();

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 120); // press, ripple
  static const Duration base = Duration(milliseconds: 220); // most transitions
  static const Duration slow = Duration(milliseconds: 320); // page / hero
  static const Duration toast = Duration(milliseconds: 2600);

  /// Standard easing for entering/moving elements.
  static const Curve standard = Curves.easeOutCubic;

  /// Decelerate — elements entering the screen.
  static const Curve decelerate = Curves.easeOutQuart;

  /// Emphasized — playful spring-like settle for friendly moments.
  static const Curve emphasized = Curves.easeOutBack;
}
