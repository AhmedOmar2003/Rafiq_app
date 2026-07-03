import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/app_image.dart';
import '../../../models/payments/payments_model.dart';

class Payments extends StatelessWidget {
  final PaymentsModel model;
  final Color color;

  const Payments({
    super.key,
    required this.model,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
      margin: EdgeInsets.only(
        bottom: AppSpacing.lg.h,
        right: AppSpacing.xxxl.w,
        left: AppSpacing.xxxl.w,
      ),
      constraints: BoxConstraints(minHeight: 48.h),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: AppRadii.rMd,
        color: AppColor.surfaceCard,
        border: Border.all(color: AppColor.border),
      ),
      child: Row(
        children: [
          Container(
            height: 12.h,
            width: 12.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              border: Border.all(
                color: AppColor.borderStrong,
                width: 1,
              ),
            ),
          ),
          gapH(AppSpacing.sm),
          Text(
            model.text,
            style: AppText.titleMd.copyWith(
              color: AppColor.textPrimary,
            ),
          ),
          const Spacer(),
          AppImage(
            model.icon,
            height: 28.h,
            width: 75.w,
          ),
        ],
      ),
    );
  }
}
