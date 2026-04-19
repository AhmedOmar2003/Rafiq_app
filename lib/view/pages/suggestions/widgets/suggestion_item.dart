import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_app/core/design/app_button.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/title_text.dart';
import 'package:rafiq_app/core/utils/app_color.dart';
import 'package:rafiq_app/core/utils/assets.dart';
import 'package:rafiq_app/core/utils/spacing.dart';
import 'package:rafiq_app/core/utils/text_style_theme.dart';
import 'package:rafiq_app/view/pages/cubit.dart';

class SuggestionModel {
  final String text, icon;
  final List<String> answer;

  SuggestionModel({
    required this.answer,
    required this.text,
    required this.icon,
  });
}

List<SuggestionModel> suggestionList = [
  SuggestionModel(
    text: "النشاط",
    icon: AppImages.activitie,
    answer: [
      "ترفيه",
      "طعام",
      "سياحي",
      "فعايات ثقافية",
    ],
  ),
  SuggestionModel(
    text: "المكان",
    icon: AppImages.mapPin,
    answer: [
      "القاهرة",
      "الإسكندرية",
      "المنصورة",
      "طنطا",
    ],
  ),
  SuggestionModel(
    text: "الميزانية",
    icon: AppImages.money,
    answer: [
      "أقل من 100 جنيه",
      "100 إلى 500 جنيه",
      "500 إلى 1000 جنيه",
      "1000 إلى 1500 جنيه",
    ],
  ),
];

class SuggestionItem extends StatelessWidget {
  final SuggestionModel model;

  const SuggestionItem({
    Key? key,
    required this.model,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await showModalBottomSheet(
          context: context,
          builder: (context) {
            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 32.h),
              height: 460.h,
              decoration: BoxDecoration(
                color: AppColor.ofWhite,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(15.r),
                  topLeft: Radius.circular(15.r),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CustomTextWidget(
                        label: model.text,
                        style: TextStyleTheme.textStyle22Medium,
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: CustomTextWidget(
                          label: "شيل الفلتر",
                          style: TextStyleTheme.textStyle22Medium.copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                  verticalSpace(16),
                  ...model.answer.map(
                    (e) => GestureDetector(
                      onTap: () async {
                        if (model.text == "النشاط") {
                          context.read<FilterCubit>().updateActivity(e);
                        } else if (model.text == "المكان") {
                          context.read<FilterCubit>().updateCity(e);
                        } else if (model.text == "الميزانية") {
                          context.read<FilterCubit>().updateBudget(e);
                        }
                        Navigator.pop(context);
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 10.h, horizontal: 16.w),
                        margin: EdgeInsets.only(bottom: 20.h),
                        height: 52.h,
                        width: 358.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15.r),
                          color: _getSelectedFilter(model.text, context) == e
                              ? AppColor.primary
                              : AppColor.white,
                          border: Border.all(
                              color: const Color(0xff000000), width: 0.3),
                        ),
                        child: CustomTextWidget(
                          label: e,
                          style: TextStyleTheme.textStyle20Medium.copyWith(
                            color: _getSelectedFilter(model.text, context) == e
                                ? Colors.white
                                : const Color(0xff000000),
                          ),
                        ),
                      ),
                    ),
                  ),
                  AppButton(
                    text: "تطبيق",
                    textStyle: TextStyleTheme.textStyle24Medium,
                    buttonStyle: ElevatedButton.styleFrom(
                      fixedSize: Size(342.w, 55.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    onPress: () async {
                      await context.read<FilterCubit>().applyFilters();
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text("تم تطبيق الفلاتر بنجاح!")),
                      );
                    },
                  )
                ],
              ),
            );
          },
        );
      },
      child: BlocBuilder<FilterCubit, FilterState>(
        builder: (context, state) {
          final selectedFilter = _getSelectedFilterFromState(model.text, state);
          final isSelected = selectedFilter != null;
          return Container(
            margin: EdgeInsets.only(left: 12.w),
            height: 44.h,
            decoration: BoxDecoration(
              color: isSelected ? AppColor.primary : AppColor.white,
              borderRadius: BorderRadius.circular(24.r),
              border: Border.all(
                  color: isSelected ? AppColor.primary : Colors.grey.shade300,
                  width: 1),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: AppColor.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppImage(
                    model.icon,
                    height: 20.h,
                    width: 20.h,
                    color: isSelected ? AppColor.white : AppColor.primary,
                  ),
                  SizedBox(width: 8.w),
                  CustomTextWidget(
                    label: selectedFilter ?? model.text,
                    style: TextStyleTheme.textStyle16Regular.copyWith(
                      color: isSelected ? AppColor.white : AppColor.black,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isSelected ? AppColor.white : AppColor.primary,
                    size: 22.sp,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String? _getSelectedFilterFromState(
      String filterType, FilterState filterState) {
    if (filterType == "النشاط") {
      return filterState.activity;
    } else if (filterType == "المكان") {
      return filterState.city;
    } else if (filterType == "الميزانية") {
      return filterState.budget;
    }
    return null;
  }

  String? _getSelectedFilter(String filterType, BuildContext context) {
    final filterState = context.read<FilterCubit>().state;
    return _getSelectedFilterFromState(filterType, filterState);
  }
}
