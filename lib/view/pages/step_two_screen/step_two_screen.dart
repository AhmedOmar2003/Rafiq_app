// import 'package:flutter/material.dart';
// import 'package:flutter_screenutil/flutter_screenutil.dart';
// import '../../../core/design/title_text.dart';
// import '../../../core/utils/app_color.dart';
// import '../../../core/utils/spacing.dart';
// import '../../../core/utils/text_style_theme.dart';
// import '../../../models/step_two_model/step_two_model.dart';

// class StepTwo extends StatefulWidget {
//   // إضافة دالة Callback لتمرير الميزانية المختارة
//   final Function(String) onBudgetSelected;

//   const StepTwo({super.key, required this.onBudgetSelected});

//   @override
//   State<StepTwo> createState() => _StepTwoState();
// }

// class _StepTwoState extends State<StepTwo> {
//   int currentIndex = -1;
//   String selectedBudget = ''; // متغير لتخزين الميزانية المختارة

//   @override
//   Widget build(BuildContext context) {
//     return ListView(
//       padding: EdgeInsets.symmetric(horizontal: 24.w),
//       children: [
//         CustomTextWidget(
//           label: "ميزانيتك كام ؟",
//           style: TextStyleTheme.textStyle30Medium,
//         ),
//         verticalSpace(50),
//         ...List.generate(
//           stepTwoList.length,
//           (index) {
//             return GestureDetector(
//               onTap: () {
//                 setState(() {
//                   currentIndex = index;
//                   selectedBudget =
//                       stepTwoList[index].text; // تخزين الميزانية المختارة
//                 });
//                 // استدعاء دالة Callback لتمرير الميزانية المختارة
//                 widget.onBudgetSelected(selectedBudget);
//               },
//               child: Container(
//                 padding: EdgeInsets.only(right: 20.w, top: 15.h),
//                 margin: EdgeInsets.only(bottom: 20.h),
//                 height: 60.h,
//                 width: 342.w,
//                 decoration: BoxDecoration(
//                   borderRadius: BorderRadius.circular(15.r),
//                   color:
//                       currentIndex == index ? AppColor.primary : AppColor.white,
//                   border: Border.all(
//                     color: currentIndex == index
//                         ? AppColor.primary
//                         : const Color(0xff000000),
//                     width: 0.3,
//                   ),
//                 ),
//                 child: CustomTextWidget(
//                   label: stepTwoList[index].text,
//                   style: TextStyleTheme.textStyle20Medium.copyWith(
//                     color: currentIndex == index
//                         ? AppColor.white
//                         : const Color(0xff000000),
//                   ),
//                 ),
//               ),
//             );
//           },
//         ),
//       ],
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/title_text.dart';
import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';
import '../../../models/step_two_model/step_two_model.dart';

class StepTwo extends StatefulWidget {
  final Function(String) onBudgetSelected;

  const StepTwo({super.key, required this.onBudgetSelected});

  @override
  State<StepTwo> createState() => _StepTwoState();
}

class _StepTwoState extends State<StepTwo> {
  int currentIndex = -1;
  String selectedBudget = ''; // لتخزين الميزانية المختارة

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl, // جعل النصوص والعناصر من اليمين لليسار
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomTextWidget(
              label: "ميزانيتك كام؟",
              style: TextStyleTheme.textStyle30Medium,
            ),
            verticalSpace(50),
            ListView.builder(
              itemCount: stepTwoList.length,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      currentIndex = index;
                      selectedBudget = stepTwoList[index].text;
                    });

                    // التحقق من صحة القيمة وتمريرها
                    if (selectedBudget.isNotEmpty) {
                      widget.onBudgetSelected(selectedBudget);
                      print("الميزانية المختارة: $selectedBudget");
                    } else {
                      print("لم يتم اختيار ميزانية.");
                    }
                  },
                  child: Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 20.w, vertical: 15.h),
                    margin: EdgeInsets.only(bottom: 20.h),
                    height: 60.h,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.r),
                      color: currentIndex == index
                          ? AppColor.primary
                          : AppColor.white,
                      border: Border.all(
                        color: currentIndex == index
                            ? AppColor.primary
                            : const Color(0xff000000),
                        width: 0.3,
                      ),
                    ),
                    child: CustomTextWidget(
                      label: stepTwoList[index].text,
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
        ),
      ),
    );
  }
}
