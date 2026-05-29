import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';

/// Full-surface loading overlay.
///
/// Wrap any screen body; flip [isLoading] to show a brand-tinted scrim with a
/// brand spinner (was a harsh red on black). Optional [message] uses friendly
/// Egyptian-Arabic copy.
class LoadingManager extends StatelessWidget {
  const LoadingManager({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  final bool isLoading;
  final Widget child;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                color: AppColor.overlaySoft,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.all(AppSpacing.xl.w),
                    decoration: BoxDecoration(
                      color: AppColor.surfaceCard,
                      borderRadius: AppRadii.rLg,
                      boxShadow: AppShadows.level3,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(
                            color: AppColor.primary),
                        gapV(AppSpacing.lg),
                        Text(message ?? AppCopy.loading, style: AppText.bodyMd),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
