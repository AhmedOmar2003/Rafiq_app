import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        children: [
          SizedBox(height: 16.h),
          Text("ميزانيتك كام؟", style: AppText.displayMd),
          gapV(AppSpacing.sm),
          Text(
            "اختار الميزانية المناسبة لك",
            style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
          ),
          SizedBox(height: 28.h),
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
          SizedBox(height: 8.h),
        ],
      ),
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
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        splashColor: AppColor.primary.withOpacity(0.1),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14.r),
            color: isSelected ? AppColor.primary : AppColor.surfaceCard,
            border: Border.all(
              color: isSelected ? AppColor.primary : AppColor.border,
              width: isSelected ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColor.primary.withOpacity(0.15)
                    : AppColor.black.withOpacity(0.04),
                blurRadius: isSelected ? 12 : 6,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? AppColor.white
                      : AppColor.primary.withOpacity(0.3),
                ),
              ),
              SizedBox(width: 14.w),
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
                Icon(Icons.check_circle_rounded, color: AppColor.surfaceCard, size: 20.w),
            ],
          ),
        ),
      ),
    );
  }
}
