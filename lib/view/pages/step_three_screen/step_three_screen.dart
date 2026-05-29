import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';
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
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      children: [
        SizedBox(height: 16.h),
        Text("عايز تعمل ايه؟", style: AppText.displayMd),
        gapV(AppSpacing.sm),
        Text(
          "اختار نوع النشاط اللي تفضله",
          style: AppText.bodyLg.copyWith(color: AppColor.textSecondary),
        ),
        SizedBox(height: 28.h),
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
        SizedBox(height: 8.h),
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
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14.r),
        splashColor: AppColor.primary.withValues(alpha: 0.1),
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
                    ? AppColor.primary.withValues(alpha: 0.15)
                    : AppColor.black.withValues(alpha: 0.04),
                blurRadius: isSelected ? 12 : 6,
                offset: Offset(0, isSelected ? 4 : 2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (icon != null && icon!.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColor.white.withValues(alpha: 0.2)
                        : AppColor.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
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
                  duration: const Duration(milliseconds: 250),
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColor.white
                        : AppColor.primary.withValues(alpha: 0.3),
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
                Icon(Icons.check_circle_rounded,
                    color: AppColor.surfaceCard, size: 20.w),
            ],
          ),
        ),
      ),
    );
  }
}
