import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_strings.dart';
import 'package:rafiq_app/core/utils/assets.dart';

/// High-contrast brand treatment for authentication and first-run surfaces.
class AppBrandMark extends StatelessWidget {
  const AppBrandMark({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: AppStrings.appName,
      child: Container(
        width: 244.w,
        constraints: BoxConstraints(minHeight: 124.h),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl.w,
          vertical: AppSpacing.lg.h,
        ),
        decoration: BoxDecoration(
          color: AppColor.surfaceCard,
          border: Border.all(color: AppColor.border),
          borderRadius: AppRadii.rXl,
          boxShadow: AppShadows.level2,
        ),
        child: AppImage(
          AppImages.logo,
          height: 92.h,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
