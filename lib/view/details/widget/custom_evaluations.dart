import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/spacing.dart';
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

  ImageProvider? _resolveAvatarProvider() {
    if (kIsWeb) {
      if (userImage != null && userImage!.isNotEmpty) {
        try {
          return MemoryImage(base64Decode(userImage!));
        } catch (_) {}
      }
      if (lastEvaluation != null && lastEvaluation!.image.isNotEmpty) {
        if (lastEvaluation!.image.startsWith('http')) {
          return NetworkImage(lastEvaluation!.image);
        }
        if (lastEvaluation!.image.contains("assets")) {
          return AssetImage(lastEvaluation!.image);
        }
      }
      return null;
    }

    if (userImage != null &&
        userImage!.isNotEmpty &&
        File(userImage!).existsSync()) {
      return FileImage(File(userImage!));
    }
    if (lastEvaluation != null && lastEvaluation!.image.isNotEmpty) {
      if (lastEvaluation!.image.startsWith('http')) {
        return NetworkImage(lastEvaluation!.image);
      }
      if (lastEvaluation!.image.contains("assets")) {
        return AssetImage(lastEvaluation!.image);
      }
      if (File(lastEvaluation!.image).existsSync()) {
        return FileImage(File(lastEvaluation!.image));
      }
    }
    return null;
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
                  Text(
                    "التقييمات",
                    style: AppText.titleLg,
                  ),
                  horizontalSpace(5),
                  Text(
                    "(تقييم 4.1K)", // عدد التقييمات
                    style: AppText.bodySm,
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
                  Text(
                    "الأكثر شعبية",
                    style: AppText.bodySm.copyWith(
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
                        Builder(builder: (context) {
                          final avatarProvider = _resolveAvatarProvider();
                          return CircleAvatar(
                            backgroundImage: avatarProvider ??
                                const AssetImage(
                                        'assets/images/default_profile.png')
                                    as ImageProvider,
                            radius: 20.w,
                            child: avatarProvider == null
                                ? Icon(Icons.person, color: AppColor.white)
                                : null,
                          );
                        }),
                        horizontalSpace(12.w),

                        /// تفاصيل التقييم (اسم المستخدم، تقييم النجوم، التاريخ)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            /// **اسم المستخدم**
                            Text(
                              lastEvaluation!.name,
                              style: AppText.titleMd.copyWith(
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
                                Text(
                                  formatDate(lastEvaluation!.date),
                                  style: AppText.caption,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                    verticalSpace(17),

                    /// **نص التقييم**
                    Text(
                      lastEvaluation!.body,
                      style: AppText.bodySm,
                    ),
                  ],
                )

              /// **عرض رسالة في حالة عدم وجود تقييمات**
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "لا توجد تقييمات بعد.",
                      style: AppText.titleMd.copyWith(
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
              child: Text(
                "شوف كل التقييمات",
                style: AppText.titleLg.copyWith(
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
