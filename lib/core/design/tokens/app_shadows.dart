import 'package:flutter/widgets.dart';
import 'package:rafiq_app/core/utils/app_color.dart';

/// Elevation tokens.
///
/// Three soft, brand-tinted levels. Shadows are intentionally low-contrast
/// (warm neutral, not pure black) to keep the calm, cream feel and to render
/// cheaply. Prefer these over ad-hoc BoxShadow lists.
///
///   level0 = flat (no shadow)
///   level1 = resting cards, inputs
///   level2 = raised cards, sticky bars, FAB
///   level3 = menus, dialogs, bottom sheets
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> level0 = [];

  static List<BoxShadow> get level1 => const [
        BoxShadow(
          color: Color(0x0F000000), // ~6%
          blurRadius: 10,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get level2 => const [
        BoxShadow(
          color: Color(0x14000000), // ~8%
          blurRadius: 16,
          offset: Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get level3 => const [
        BoxShadow(
          color: Color(0x1F000000), // ~12%
          blurRadius: 28,
          offset: Offset(0, 12),
        ),
      ];

  /// Brand-tinted glow for primary CTAs (used sparingly).
  static List<BoxShadow> get primaryGlow => [
        BoxShadow(
          color: AppColor.primary.withOpacity(0.28),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}
