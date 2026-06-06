import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Shared layout for the three preference steps.
///
/// Keeps headings, options, and page gutters identical across every step.
class PreferenceStepLayout extends StatelessWidget {
  const PreferenceStepLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg.w,
        AppSpacing.md.h,
        AppSpacing.lg.w,
        AppSpacing.xl.h,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: AppText.headingMd.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        gapV(AppSpacing.xs),
        Text(
          subtitle,
          style: AppText.bodyMd.copyWith(
            color: AppColor.textSecondary,
            height: 1.45,
          ),
        ),
        gapV(AppSpacing.xl),
        ...children,
      ],
    );
  }
}

class PreferenceOptionCard extends StatelessWidget {
  const PreferenceOptionCard({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.icon,
    this.iconAsset,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? iconAsset;

  @override
  Widget build(BuildContext context) {
    final foreground = isSelected ? AppColor.white : AppColor.textPrimary;
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.md.h),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: Material(
          color: isSelected ? AppColor.primary : AppColor.surfaceCard,
          borderRadius: AppRadii.rLg,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.rLg,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.standard,
              constraints: BoxConstraints(minHeight: 64.h),
              padding: EdgeInsets.symmetric(
                horizontal: AppSpacing.lg.w,
                vertical: AppSpacing.md.h,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.rLg,
                border: Border.all(
                  color: isSelected ? AppColor.primary : AppColor.border,
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow:
                    isSelected ? AppShadows.primaryGlow : AppShadows.level0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColor.white.withValues(alpha: 0.18)
                          : AppColor.primary50,
                      borderRadius: AppRadii.rMd,
                    ),
                    child: iconAsset != null && iconAsset!.isNotEmpty
                        ? AppImage(
                            iconAsset!,
                            width: 22.w,
                            height: 22.w,
                            color:
                                isSelected ? AppColor.white : AppColor.primary,
                          )
                        : Icon(
                            icon ?? Icons.circle_outlined,
                            size: 20.sp,
                            color:
                                isSelected ? AppColor.white : AppColor.primary,
                          ),
                  ),
                  gapH(AppSpacing.md),
                  Expanded(
                    child: Text(
                      label,
                      style: AppText.titleMd.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  gapH(AppSpacing.sm),
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? AppColor.white : AppColor.textTertiary,
                    size: 22.sp,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
