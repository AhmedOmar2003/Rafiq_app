import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';

/// Celebratory success moment shown as a full-screen scrim with a centered card.
///
/// Extracted from the duplicated login/register overlays so the "you did it!"
/// moment is identical everywhere. Tapping the scrim or the continue button
/// fires [onContinue].
class AppSuccessView extends StatelessWidget {
  const AppSuccessView({
    super.key,
    required this.title,
    required this.onContinue,
    this.message,
    this.imageAsset,
  });

  final String title;
  final String? message;
  final String? imageAsset;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
        onTap: onContinue,
        child: Container(
          color: AppColor.overlay,
          alignment: Alignment.center,
          child: Container(
            width: 320.w,
            padding: EdgeInsets.all(AppSpacing.xxl.w),
            decoration: BoxDecoration(
              color: AppColor.surfaceCard,
              borderRadius: AppRadii.rXl,
              boxShadow: AppShadows.level3,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageAsset != null)
                  AppImage(imageAsset!, width: 150.w, height: 150.w)
                else
                  Container(
                    width: 96.w,
                    height: 96.w,
                    decoration: const BoxDecoration(color: AppColor.successBg, shape: BoxShape.circle),
                    child: Icon(Icons.check_rounded, size: 52.sp, color: AppColor.success),
                  ),
                gapV(AppSpacing.xl),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppText.headingMd.copyWith(color: AppColor.primary, fontWeight: FontWeight.w700),
                ),
                if (message != null) ...[
                  gapV(AppSpacing.sm),
                  Text(message!, textAlign: TextAlign.center, style: AppText.bodyMd),
                ],
                gapV(AppSpacing.xxl),
                AppButton(
                  text: AppCopy.done,
                  onPress: onContinue,
                  icon: Icons.arrow_forward_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}
