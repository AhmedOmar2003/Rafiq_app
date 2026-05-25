import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';

/// The "this screen has no normal content right now" surface.
///
/// One component covers empty / error / offline / search-empty so they all look
/// and speak the same. Friendly Egyptian-Arabic copy by default; pass an
/// [onAction] to show a retry/CTA button.
///
/// Use the named constructors for the common cases:
///   AppStateView.empty()      AppStateView.error(onAction: ...)
///   AppStateView.offline(onAction: ...)   AppStateView.search()
class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.iconColor,
    this.iconBg,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? iconColor;
  final Color? iconBg;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  factory AppStateView.empty({String? title, String? message, VoidCallback? onAction}) =>
      AppStateView(
        icon: Icons.inbox_outlined,
        title: title ?? AppCopy.emptyResultsTitle,
        message: message ?? AppCopy.emptyResultsBody,
        actionLabel: onAction != null ? AppCopy.retry : null,
        onAction: onAction,
      );

  factory AppStateView.search({String? title, String? message, VoidCallback? onAction}) =>
      AppStateView(
        icon: Icons.search_off_rounded,
        title: title ?? AppCopy.emptySearchTitle,
        message: message ?? AppCopy.emptySearchBody,
        actionLabel: onAction != null ? AppCopy.retry : null,
        onAction: onAction,
      );

  factory AppStateView.error({String? title, String? message, VoidCallback? onAction}) =>
      AppStateView(
        icon: Icons.sentiment_dissatisfied_rounded,
        iconColor: AppColor.error,
        iconBg: AppColor.errorBg,
        title: title ?? AppCopy.errorTitle,
        message: message ?? AppCopy.errorBody,
        actionLabel: AppCopy.errorRetry,
        onAction: onAction,
      );

  factory AppStateView.offline({VoidCallback? onAction}) => AppStateView(
        icon: Icons.wifi_off_rounded,
        iconColor: AppColor.warning,
        iconBg: AppColor.warningBg,
        title: AppCopy.offlineTitle,
        message: AppCopy.offlineBody,
        actionLabel: AppCopy.retry,
        onAction: onAction,
      );

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(AppSpacing.xxl.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: (compact ? 72 : 96).w,
              height: (compact ? 72 : 96).w,
              decoration: BoxDecoration(
                color: iconBg ?? AppColor.sand200,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: (compact ? 34 : 44).sp, color: iconColor ?? AppColor.primary),
            ),
            gapV(AppSpacing.xl),
            Text(title, textAlign: TextAlign.center, style: AppText.headingSm),
            gapV(AppSpacing.sm),
            Text(message, textAlign: TextAlign.center, style: AppText.bodyMd),
            if (onAction != null) ...[
              gapV(AppSpacing.xxl),
              AppButton(
                text: actionLabel ?? AppCopy.retry,
                onPress: onAction!,
                variant: AppButtonVariant.outline,
                size: AppButtonSize.md,
                isFullWidth: false,
                icon: Icons.refresh_rounded,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
