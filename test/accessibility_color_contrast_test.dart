import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rafiq_app/core/utils/app_color.dart';

void main() {
  test('core text and status colors meet WCAG AA for normal text', () {
    final pairs = <(String, Color, Color)>[
      ('primary action', AppColor.textOnPrimary, AppColor.primary),
      ('primary text', AppColor.textPrimary, AppColor.surfaceCard),
      ('secondary text', AppColor.textSecondary, AppColor.surfaceCard),
      ('tertiary text', AppColor.textTertiary, AppColor.surfaceCard),
      ('success text', AppColor.success, AppColor.surfaceCard),
      ('warning text', AppColor.warning, AppColor.surfaceCard),
      ('warning surface', AppColor.warning, AppColor.warningBg),
      ('error text', AppColor.error, AppColor.surfaceCard),
      ('info text', AppColor.info, AppColor.surfaceCard),
    ];

    for (final pair in pairs) {
      expect(
        _contrastRatio(pair.$2, pair.$3),
        greaterThanOrEqualTo(4.5),
        reason: '${pair.$1} must stay readable for small Arabic text',
      );
    }
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
