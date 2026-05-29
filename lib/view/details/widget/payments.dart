import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/app_image.dart';
import '../../../core/utils/spacing.dart';
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
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      margin: EdgeInsets.only(bottom: 16.h, right: 33.w, left: 33.w),
      height: 47.h,
      width: 326.w,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        color: AppColor.white,
        border: Border.all(
          color: const Color(0xff000061).withValues(alpha: .38),
          width: 0.3,
        ),
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
                color: const Color(0xff85847D),
                width: 1,
              ),
            ),
          ),
          horizontalSpace(7),
          Text(
            model.text,
            style: AppText.titleMd.copyWith(
              color: AppColor.black,
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
