import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/components/app_badge.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';

/// Unified, token-driven transient feedback (snackbars).
///
/// One voice for success / error / warning / info: a floating, rounded, tinted
/// bar with an icon — instead of the previous raw red/yellow/green SnackBars
/// scattered across screens. Uses the global navigator so it can be called from
/// anywhere (services, cubits) without a BuildContext.
class AppFeedback {
  AppFeedback._();

  static void success(String message) => _show(message, AppTone.success, Icons.check_circle_rounded);
  static void error(String message) => _show(message, AppTone.error, Icons.error_rounded);
  static void warning(String message) => _show(message, AppTone.warning, Icons.warning_amber_rounded);
  static void info(String message) => _show(message, AppTone.info, Icons.info_rounded);

  static void _show(String message, AppTone tone, IconData icon) {
    if (message.trim().isEmpty) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final c = toneColors(tone);

    ScaffoldMessenger.of(ctx)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          duration: AppMotion.toast,
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColor.surfaceInverse,
          elevation: 0,
          margin: EdgeInsets.all(AppSpacing.lg.w),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
          content: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.xs.w),
                decoration: BoxDecoration(color: c.bg, borderRadius: AppRadii.rSm),
                child: Icon(icon, color: c.fg, size: 18.sp),
              ),
              gapH(AppSpacing.md),
              Expanded(
                child: Text(message, style: AppText.bodyMd.copyWith(color: AppColor.white)),
              ),
            ],
          ),
        ),
      );
  }
}
