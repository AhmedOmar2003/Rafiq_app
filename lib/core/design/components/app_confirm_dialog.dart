import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';

/// Unified confirm/cancel dialog.
///
/// Follows the design-system modal spec exactly:
///   - Header: title + optional small icon (tone-aware).
///   - Body: short, specific message.
///   - Footer: cancel (ghost) + primary action (variant follows `tone`).
///
/// One implementation, one set of states, one return path. Resolves the
/// scattered AlertDialog patterns previously used for logout / delete / etc.
enum AppConfirmTone { neutral, danger, success }

class AppConfirmDialog {
  AppConfirmDialog._();

  /// Show the dialog and return `true` if the user confirmed.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    String confirmLabel = AppCopy.confirm,
    String cancelLabel = AppCopy.cancel,
    AppConfirmTone tone = AppConfirmTone.neutral,
    IconData? icon,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: AppColor.overlay,
      builder: (ctx) => _AppConfirmDialogContent(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        tone: tone,
        icon: icon,
      ),
    );
    return result ?? false;
  }
}

class _AppConfirmDialogContent extends StatelessWidget {
  const _AppConfirmDialogContent({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.tone,
    required this.icon,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String cancelLabel;
  final AppConfirmTone tone;
  final IconData? icon;

  Color get _accent {
    switch (tone) {
      case AppConfirmTone.danger:
        return AppColor.statusDanger;
      case AppConfirmTone.success:
        return AppColor.statusSuccess;
      case AppConfirmTone.neutral:
        return AppColor.actionPrimary;
    }
  }

  AppButtonVariant get _confirmVariant {
    switch (tone) {
      case AppConfirmTone.danger:
        return AppButtonVariant.destructive;
      case AppConfirmTone.success:
      case AppConfirmTone.neutral:
        return AppButtonVariant.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColor.surfaceElevated,
      surfaceTintColor: AppColor.surfaceElevated,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: AppRadii.rLg),
      insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xxxl.w),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.xl.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            if (icon != null) ...[
              Center(
                child: Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: _accent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: _accent, size: 28.sp),
                ),
              ),
              gapV(AppSpacing.lg),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.headingSm.copyWith(
                color: AppColor.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              gapV(AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
              ),
            ],
            gapV(AppSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    text: cancelLabel,
                    variant: AppButtonVariant.ghost,
                    onPress: () => Navigator.of(context).pop(false),
                  ),
                ),
                gapH(AppSpacing.md),
                Expanded(
                  child: AppButton(
                    text: confirmLabel,
                    variant: _confirmVariant,
                    onPress: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }
}
