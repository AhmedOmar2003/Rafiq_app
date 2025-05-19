import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/model/review_model.dart';
import '../../../core/design/title_text.dart';
import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';

class EvaluationItem extends StatelessWidget {
  final EvaluationsItemModel model;
  const EvaluationItem({super.key, required this.model});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'avatar_${model.name}',
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 26.r,
                    backgroundImage: AssetImage(model.image),
                  ),
                ),
              ),
              horizontalSpace(16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextWidget(
                      label: model.name,
                      style: TextStyleTheme.textStyle16Medium.copyWith(
                        color: AppColor.black,
                        height: 1.2,
                      ),
                    ),
                    verticalSpace(8.h),
                    Row(
                      children: [
                        Row(
                          children: List.generate(
                            5,
                            (index) => Padding(
                              padding: EdgeInsets.only(right: 3.w),
                              child: Icon(
                                Icons.star_rounded,
                                size: 20.w,
                                color: Colors.amber,
                              ),
                            ),
                          ),
                        ),
                        horizontalSpace(12.w),
                        CustomTextWidget(
                          label: model.date,
                          style: TextStyleTheme.textStyle11Medium.copyWith(
                            color: AppColor.black.withOpacity(0.6),
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          verticalSpace(16.h),
          CustomTextWidget(
            label: model.body,
            style: TextStyleTheme.textStyle12Regular.copyWith(
              height: 1.6,
              color: AppColor.black.withOpacity(0.8),
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
