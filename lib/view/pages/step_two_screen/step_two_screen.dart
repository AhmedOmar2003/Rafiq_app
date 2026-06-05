import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import '../../../models/step_two_model/step_two_model.dart';

class StepTwo extends StatefulWidget {
  final Function(String) onBudgetSelected;
  const StepTwo({super.key, required this.onBudgetSelected});

  @override
  State<StepTwo> createState() => _StepTwoState();
}

class _StepTwoState extends State<StepTwo> with AutomaticKeepAliveClientMixin {
  int currentIndex = -1;
  String selectedBudget = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
      children: [
        gapV(AppSpacing.lg),
        Text(AppCopy.stepBudgetTitle, style: AppText.displayMd),
        gapV(AppSpacing.sm),
        Text(
          AppCopy.stepBudgetBody,
          style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
        ),
        gapV(AppSpacing.xxxl),
        ...List.generate(
          stepTwoList.length,
          (index) => _BudgetOptionCard(
            label: stepTwoList[index].text,
            isSelected: currentIndex == index,
            onTap: () {
              setState(() {
                currentIndex = index;
                selectedBudget = stepTwoList[index].text;
              });
              if (selectedBudget.isNotEmpty) {
                widget.onBudgetSelected(selectedBudget);
              }
            },
          ),
        ),
        gapV(AppSpacing.sm),
      ],
    );
  }
}

class _BudgetOptionCard extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _BudgetOptionCard({
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
