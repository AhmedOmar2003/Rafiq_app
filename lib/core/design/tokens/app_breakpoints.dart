import 'package:flutter/widgets.dart';

/// Responsive breakpoints.
///
/// The mobile app targets a 390x844 design (see ScreenUtilInit). These
/// breakpoints let shared widgets (and the future admin dashboard built on the
/// same tokens) adapt: phones stack, tablets/web go multi-column.
///
///   compact  < 600   phones
///   medium   < 905   large phones / small tablets (portrait)
///   expanded < 1240  tablets landscape / small desktop
///   large    >= 1240 desktop / dashboard
class AppBreakpoints {
  AppBreakpoints._();

  static const double medium = 600;
  static const double expanded = 905;
  static const double large = 1240;

  static bool isCompact(BuildContext c) => MediaQuery.sizeOf(c).width < medium;
  static bool isMedium(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= medium && w < expanded;
  }

  static bool isExpanded(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    return w >= expanded && w < large;
  }

  static bool isLarge(BuildContext c) => MediaQuery.sizeOf(c).width >= large;

  /// Number of grid columns appropriate for the current width.
  static int columns(BuildContext c) {
    final w = MediaQuery.sizeOf(c).width;
    if (w >= large) return 12;
    if (w >= expanded) return 8;
    if (w >= medium) return 6;
    return 4;
  }
}
