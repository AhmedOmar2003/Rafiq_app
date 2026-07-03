import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/design/app_image.dart';
import '../../../../../core/utils/spacing.dart';
import '../utils/assets.dart';
import '../utils/app_microcopy.dart';

class MyAppMethods {
  static Future<void> showErrorORWarningDialog({
    required BuildContext context,
    required String subtitle,
    required VoidCallback onPress,
    bool isError = false,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: AppColor.overlay,
      builder: (context) {
        return Dialog(
          backgroundColor: AppColor.surfaceElevated,
          surfaceTintColor: AppColor.surfaceElevated,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
          insetPadding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72.w,
                    height: 72.w,
                    decoration: BoxDecoration(
                      color: (isError
                              ? AppColor.statusDanger
                              : AppColor.statusWarning)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AppImage(
                      AppImages.warning,
                      height: 40.h,
                      width: 40.w,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                verticalSpace(20),
                Text(
                  isError ? 'تنبيه' : 'تأكيد',
                  textAlign: TextAlign.center,
                  style: AppText.headingSm.copyWith(
                    color: AppColor.textPrimary,
                  ),
                ),
                verticalSpace(10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd.copyWith(color: AppColor.textSecondary),
                ),
                verticalSpace(24),
                if (!isError) ...[
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          text: "إلغاء",
                          variant: AppButtonVariant.ghost,
                          onPress: () => Navigator.pop(context),
                        ),
                      ),
                      horizontalSpace(12),
                      Expanded(
                        child: AppButton(
                          text: "تسجيل الخروج",
                          variant: AppButtonVariant.destructive,
                          onPress: onPress,
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  AppButton(
                    text: AppCopy.ok,
                    variant: AppButtonVariant.primary,
                    isFullWidth: true,
                    onPress: onPress,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
