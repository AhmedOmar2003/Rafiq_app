import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/design/title_text.dart';
import '../../../core/utils/app_color.dart';
import '../../../core/utils/spacing.dart';
import '../../../core/utils/text_style_theme.dart';
import '../../evaluations/evaluations_page.dart';
import '../../../model/review_model.dart';

class CustomEvaluations extends StatelessWidget {
  final int placeId;
  final EvaluationsItemModel? lastEvaluation; // تعريف lastEvaluation هنا.
  final String? userImage; // إضافة معلمة userImage

  const CustomEvaluations({
    Key? key,
    required this.placeId,
    this.lastEvaluation, // يجب أن يكون معاملًا اختياريًا.
    this.userImage, // معلمة اختيارية لصورة المستخدم
  }) : super(key: key);

  /// **تنسيق التاريخ بشكل آمن**
  String formatDate(String? date) {
    if (date == null || date.isEmpty) {
      return "تاريخ غير متاح";
    }
    try {
      DateTime parsedDate = DateTime.parse(date);
      return DateFormat('yyyy-MM-dd').format(parsedDate);
    } catch (e) {
      return "تاريخ غير متاح";
    }
  }

  @override
  Widget build(BuildContext context) {
    print(
        "Building CustomEvaluations, userImage: $userImage, lastEvaluation.image: ${lastEvaluation?.image}");
    return SizedBox(
      width: 358.w,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// **العنوان وتصنيف التقييمات**
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CustomTextWidget(
                    label: "التقييمات",
                    style: TextStyleTheme.textStyle18Medium,
                  ),
                  horizontalSpace(5),
                  CustomTextWidget(
                    label: "(تقييم 4.1K)", // عدد التقييمات
                    style: TextStyleTheme.textStyle12Regular,
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.filter_list_outlined,
                    size: 19,
                    color: AppColor.black,
                  ),
                  horizontalSpace(5),
                  CustomTextWidget(
                    label: "الأكثر شعبية",
                    style: TextStyleTheme.textStyle12Regular.copyWith(
                      color: AppColor.black,
                    ),
                  ),
                ],
              ),
            ],
          ),

          /// **المسافة بين العنوان وآخر تقييم**
          verticalSpace(16),

          /// **عرض آخر تقييم إذا كان متوفراً**
          lastEvaluation != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// صورة المستخدم
                        CircleAvatar(
                          backgroundImage: userImage != null &&
                                  userImage!.isNotEmpty &&
                                  File(userImage!).existsSync()
                              ? FileImage(File(userImage!))
                              : lastEvaluation!.image.isNotEmpty &&
                                      lastEvaluation!.image.contains("assets")
                                  ? AssetImage(lastEvaluation!.image)
                                      as ImageProvider
                                  : lastEvaluation!.image.isNotEmpty
                                      ? FileImage(File(lastEvaluation!.image))
                                          as ImageProvider
                                      : AssetImage(
                                              'assets/images/default_profile.png')
                                          as ImageProvider,
                          radius: 20.w,
                          child: (userImage == null ||
                                      userImage!.isEmpty ||
                                      !File(userImage!).existsSync()) &&
                                  (lastEvaluation!.image.isEmpty ||
                                      !File(lastEvaluation!.image).existsSync())
                              ? Icon(Icons.person, color: AppColor.white)
                              : null,
                        ),
                        horizontalSpace(12.w),

                        /// تفاصيل التقييم (اسم المستخدم، تقييم النجوم، التاريخ)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// **اسم المستخدم**
                            CustomTextWidget(
                              label: lastEvaluation!.name,
                              style: TextStyleTheme.textStyle16Medium.copyWith(
                                color: AppColor.black,
                              ),
                            ),
                            verticalSpace(3),

                            /// **التقييم بالنجوم والتاريخ**
                            Row(
                              children: [
                                ...List.generate(
                                  5,
                                  (index) => const Icon(
                                    Icons.star,
                                    size: 15,
                                    color: Colors.yellow,
                                  ),
                                ),
                                horizontalSpace(8.w),
                                CustomTextWidget(
                                  label: formatDate(lastEvaluation!.date),
                                  style: TextStyleTheme.textStyle11Medium,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    verticalSpace(17),

                    /// **نص التقييم**
                    CustomTextWidget(
                      label: lastEvaluation!.body,
                      style: TextStyleTheme.textStyle12Regular,
                    ),
                  ],
                )

              /// **عرض رسالة في حالة عدم وجود تقييمات**
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CustomTextWidget(
                      label: "لا توجد تقييمات بعد.",
                      style: TextStyleTheme.textStyle16Medium.copyWith(
                        color: AppColor.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

          /// **زر "شوف كل التقييمات"**
          verticalSpace(20),
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EvaluationsPage(placeId: placeId),
                  ),
                );
              },
              child: CustomTextWidget(
                label: "شوف كل التقييمات",
                style: TextStyleTheme.textStyle18Medium.copyWith(
                  decoration: TextDecoration.underline,
                  color: AppColor.black,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
