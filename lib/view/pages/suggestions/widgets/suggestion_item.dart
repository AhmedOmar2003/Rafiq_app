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
    super.key,
    required this.model,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _openFilterSheet(context);
      },
      // PERFORMANCE: only rebuild this chip when *its own* slot in FilterState
      // changes. Without buildWhen, every state emit (loading toggle, places
      // update, error update) would rebuild all 3 chips needlessly.
      child: BlocBuilder<FilterCubit, FilterState>(
        buildWhen: (prev, curr) =>
            _getSelectedFilterFromState(model.text, prev) !=
            _getSelectedFilterFromState(model.text, curr),
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
                    color: AppColor.primary.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                else
                  BoxShadow(
                    color: AppColor.black.withValues(alpha: 0.04),
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
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
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

  /// Filter selector — opens an overflow-proof bottom sheet.
  ///
  /// Uses the spec-aligned modal structure:
  ///   - drag handle (top)
  ///   - header row (title + clear action)
  ///   - **scrollable** options body (never overflows)
  ///   - sticky apply button (bottom)
  ///
  /// Constrained to 85% of screen height and uses `isScrollControlled: true` so
  /// the sheet expands above the keyboard when needed.
  Future<void> _openFilterSheet(BuildContext parentContext) async {
    final cubit = parentContext.read<FilterCubit>();

    await showModalBottomSheet(
      context: parentContext,
      backgroundColor: AppColor.surfaceDefault,
      isScrollControlled: true,
      useSafeArea: true,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.topOnly(AppRadii.xl),
      ),
      builder: (sheetContext) {
        final maxH = MediaQuery.of(sheetContext).size.height * 0.85;
        final selected = _getSelectedFilterFromState(model.text, cubit.state);

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header row — drag handle is provided by the theme,
                // so we don't add a second one here.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppSpacing.xxl.w,
                    AppSpacing.sm.h,
                    AppSpacing.xxl.w,
                    AppSpacing.md.h,
                  ),
                  child: Row(
                    children: [
                      Text(model.text, style: AppText.headingMd),
                      const Spacer(),
                      if (selected != null)
                        TextButton(
                          onPressed: () {
                            _clearFilter(cubit);
                            Navigator.pop(sheetContext);
                          },
                          child: Text(
                            "شيل الفلتر",
                            style: AppText.labelMd.copyWith(
                              color: AppColor.statusDanger,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Hairline separator
                Container(height: 1, color: AppColor.border),

                // Scrollable options body — NEVER overflows, regardless of
                // option count or device size.
                Flexible(
                  child: ListView.separated(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.xxl.w,
                      AppSpacing.lg.h,
                      AppSpacing.xxl.w,
                      AppSpacing.lg.h,
                    ),
                    itemCount: model.answer.length,
                    separatorBuilder: (_, __) => gapV(AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final e = model.answer[i];
                      final isSelected = selected == e;
                      return _FilterOptionTile(
                        label: e,
                        isSelected: isSelected,
                        onTap: () {
                          _applyFilter(cubit, e);
                          Navigator.pop(sheetContext);
                        },
                      );
                    },
                  ),
                ),

                // Sticky apply button — wrapped in SafeArea so the Android
                // system nav (3-button bar / gesture pill) never covers it.
                Container(
                  decoration: const BoxDecoration(
                    color: AppColor.surfaceElevated,
                    border: Border(
                      top: BorderSide(color: AppColor.border, width: 1),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: EdgeInsets.only(bottom: AppSpacing.sm.h),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        AppSpacing.xxl.w,
                        AppSpacing.md.h,
                        AppSpacing.xxl.w,
                        AppSpacing.md.h,
                      ),
                      child: AppButton(
                        text: "تطبيق الفلتر",
                        onPress: () async {
                          await cubit.applyFilters();
                          if (sheetContext.mounted) Navigator.pop(sheetContext);
                          AppFeedback.success("تم تطبيق الفلاتر");
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _applyFilter(FilterCubit cubit, String value) {
    switch (model.text) {
      case "النشاط":
        cubit.updateActivity(value);
        break;
      case "المكان":
        cubit.updateCity(value);
        break;
      case "الميزانية":
        cubit.updateBudget(value);
        break;
    }
  }

  void _clearFilter(FilterCubit cubit) {
    switch (model.text) {
      case "النشاط":
        cubit.updateActivity('');
        break;
      case "المكان":
        cubit.updateCity('');
        break;
      case "الميزانية":
        cubit.updateBudget('');
        break;
    }
  }
}

/// Single selectable row inside the filter bottom sheet.
///
/// Has explicit `default` / `selected` states matching the design-system spec
/// (clear visual difference, primary tone for selected, neutral for default).
class _FilterOptionTile extends StatelessWidget {
  const _FilterOptionTile({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColor.actionPrimary : AppColor.surfaceElevated,
      borderRadius: AppRadii.rMd,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rMd,
        splashColor: AppColor.actionPrimary.withValues(alpha: 0.08),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.md.h,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.rMd,
            border: Border.all(
              color: isSelected ? AppColor.actionPrimary : AppColor.border,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppText.titleMd.copyWith(
                    color: isSelected ? AppColor.white : AppColor.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, color: AppColor.white, size: 20.sp),
            ],
          ),
        ),
      ),
    );
  }
}
