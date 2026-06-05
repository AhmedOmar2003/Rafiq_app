import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import '../../../models/step_three_model/step_three_model.dart';

class StepThree extends StatefulWidget {
  final Function(String) onActivitySelected;
  const StepThree({super.key, required this.onActivitySelected});

  @override
  State<StepThree> createState() => _StepThreeState();
}

class _StepThreeState extends State<StepThree>
    with AutomaticKeepAliveClientMixin {
  int currentIndex = -1;
  String selectedActivity = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxl.w),
      children: [
        gapV(AppSpacing.lg),
        Text(AppCopy.stepActivityTitle, style: AppText.displayMd),
        gapV(AppSpacing.sm),
        Text(
          AppCopy.stepActivityBody,
          style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
        ),
        gapV(AppSpacing.xxxl),
        ...List.generate(
          stepThreeList.length,
          (index) => _ActivityOptionCard(
            label: stepThreeList[index].text,
            icon: stepThreeList[index].icon,
            isSelected: currentIndex == index,
            onTap: () {
              setState(() {
                currentIndex = index;
                selectedActivity = stepThreeList[index].text;
              });
              widget.onActivitySelected(selectedActivity);
            },
          ),
        ),
        gapV(AppSpacing.sm),
      ],
    );
  }
}

class _ActivityOptionCard extends StatelessWidget {
  final String label;
  final String? icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ActivityOptionCard({
    required this.label,
    required this.icon,
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
                if (icon != null && icon!.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColor.white.withValues(alpha: 0.2)
                          : AppColor.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadii.rSm,
                    ),
                    child: AppImage(
                      icon!,
                      width: 22.w,
                      height: 22.w,
                      color: isSelected ? AppColor.white : AppColor.primary,
                    ),
                  )
                else
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
