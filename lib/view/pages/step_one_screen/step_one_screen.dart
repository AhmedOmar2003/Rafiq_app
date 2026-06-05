import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import '../../../models/step_one_model/step_one_model.dart';

class StepOne extends StatefulWidget {
  final Function(String) onCitySelected;
  const StepOne({super.key, required this.onCitySelected});

  @override
  State<StepOne> createState() => _StepOneState();
}

class _StepOneState extends State<StepOne> with AutomaticKeepAliveClientMixin {
  int currentIndex = -1;
  String selectedCity = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
      children: [
        gapV(AppSpacing.lg),
        Text(AppCopy.stepCityTitle, style: AppText.displayMd),
        gapV(AppSpacing.sm),
        Text(
          AppCopy.stepCityBody,
          style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
        ),
        gapV(AppSpacing.xxxl),
        ...List.generate(
          stepOneList.length,
          (index) => _StepOptionCard(
            label: stepOneList[index].text,
            isSelected: currentIndex == index,
            onTap: () {
              setState(() {
                currentIndex = index;
                selectedCity = stepOneList[index].text;
              });
              widget.onCitySelected(selectedCity);
            },
          ),
        ),
        gapV(AppSpacing.sm),
      ],
    );
  }
}

class _StepOptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _StepOptionCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.md.h),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.rMd,
          splashColor: AppColor.primary.withValues(alpha: 0.1),
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.standard,
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xl.w,
              vertical: AppSpacing.lg.h,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadii.rMd,
              color: isSelected ? AppColor.primary : AppColor.surfaceCard,
              border: Border.all(
                color: isSelected ? AppColor.primary : AppColor.border,
                width: isSelected ? 1.5 : 1.0,
              ),
              boxShadow: isSelected ? AppShadows.primaryGlow : AppShadows.level1,
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: AppMotion.base,
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColor.white
                        : AppColor.primary.withValues(alpha: 0.3),
                  ),
                ),
                gapH(AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    style: AppText.headingSm.copyWith(
                      color: isSelected ? AppColor.white : AppColor.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (isSelected)
                  Icon(Icons.check_circle_rounded,
                      color: AppColor.surfaceCard, size: 20.sp),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
