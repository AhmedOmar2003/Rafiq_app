import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/spacing.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import '../../../models/step_one_model/step_one_model.dart';

class StepOne extends StatefulWidget {
  // إضافة دالة Callback لتمرير المدينة المختارة
  final Function(String) onCitySelected;

  const StepOne({super.key, required this.onCitySelected});

  @override
  State<StepOne> createState() => _StepOneState();
}

class _StepOneState extends State<StepOne> {
  int currentIndex = -1;
  String selectedCity = ''; // متغير لتخزين المدينة المختارة

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      children: [
        CustomTextWidget(
          label: "عايز تخرج فين ؟",
          style: TextStyleTheme.textStyle30Medium,
        ),
        verticalSpace(50),
        ...List.generate(
          stepOneList.length,
          (index) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  currentIndex = index;
                  selectedCity =
                      stepOneList[index].text; // تخزين المدينة المختارة
                });
                // استدعاء دالة Callback لتمرير المدينة إلى HomeView
                widget.onCitySelected(selectedCity);
              },
              child: Container(
                padding: EdgeInsets.only(right: 20.w, top: 15.h),
                margin: EdgeInsets.only(bottom: 15.h),
                height: 60.h,
                width: 342.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.r),
                  color:
                      currentIndex == index ? AppColor.primary : AppColor.white,
                  border: Border.all(
                    color: currentIndex == index
                        ? AppColor.primary
                        : const Color(0xff000000),
                    width: 0.3,
                  ),
                ),
                child: CustomTextWidget(
                  label: stepOneList[index].text,
                  style: TextStyleTheme.textStyle20Medium.copyWith(
                    color: currentIndex == index
                        ? AppColor.white
                        : const Color(0xff000000),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
