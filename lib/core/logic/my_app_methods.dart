import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/design/app_image.dart';
import '../../../../../core/utils/spacing.dart';
import '../utils/assets.dart';

class MyAppMethods {
  static Future<void> showErrorORWarningDialog({
    required BuildContext context,
    required String subtitle,
    required VoidCallback onPress,
    bool isError = false,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0.r),
          ),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppImage(
                AppImages.warning,
                height: 164.h,
                width: 190.w,
              ),
              verticalSpace(16),
              Text(
                subtitle,
                style: AppText.titleLg,
              ),
              verticalSpace(16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Visibility(
                    visible: !isError,
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: Text(
                        "إلغاء",
                        style: AppText.titleLg.copyWith(
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  horizontalSpace(20),
                  TextButton(
                    onPressed: onPress,
                    child: Text(
                      "تسجيل الخروج",
                      style: AppText.titleLg.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
