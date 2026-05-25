import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/components/components.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/assets.dart';
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
          backgroundColor: AppColor.surface,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadii.topOnly(AppRadii.xl),
          ),
          builder: (context) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xxl.w, AppSpacing.xxl.h,
                AppSpacing.xxl.w, AppSpacing.xxl.h,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36.w, height: 4.h,
                    margin: EdgeInsets.only(bottom: AppSpacing.xl.h),
                    decoration: BoxDecoration(
                      color: AppColor.border,
                      borderRadius: AppRadii.rPill,
                    ),
                  ),
                  Row(
                    children: [
                      Text(model.text, style: AppText.headingMd),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          "شيل الفلتر",
                          style: AppText.labelMd.copyWith(
                            color: AppColor.primary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColor.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  gapV(AppSpacing.lg),
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
                        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: AppSpacing.lg.w),
                        margin: EdgeInsets.only(bottom: AppSpacing.md.h),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: AppRadii.rMd,
                          color: _getSelectedFilter(model.text, context) == e
                              ? AppColor.primary
                              : AppColor.surfaceCard,
                          border: Border.all(color: AppColor.border, width: 1),
                        ),
                        child: Text(
                          e,
                          style: AppText.headingSm.copyWith(
                            fontWeight: FontWeight.w500,
                            color: _getSelectedFilter(model.text, context) == e
                                ? AppColor.white
                                : AppColor.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  gapV(AppSpacing.sm),
                  AppButton(
                    text: "تطبيق الفلتر",
                    onPress: () async {
                      await context.read<FilterCubit>().applyFilters();
                      Navigator.pop(context);
                      AppFeedback.success("تم تطبيق الفلاتر");
                    },
                  ),
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
                  color: isSelected ? AppColor.primary : AppColor.border,
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
                    color: AppColor.black.withOpacity(0.04),
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
                  Text(
                    selectedFilter ?? model.text,
                    style: AppText.labelMd.copyWith(
                      color: isSelected ? AppColor.white : AppColor.textPrimary,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
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
