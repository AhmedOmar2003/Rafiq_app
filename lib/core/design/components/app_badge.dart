import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/app_image.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Status / semantic tone shared by badges and chips.
enum AppTone { neutral, primary, success, warning, error, info }

({Color fg, Color bg}) toneColors(AppTone tone) => switch (tone) {
      AppTone.neutral => (fg: AppColor.textSecondary, bg: AppColor.neutral100),
      AppTone.primary => (fg: AppColor.primary, bg: AppColor.primary50),
      AppTone.success => (fg: AppColor.success, bg: AppColor.successBg),
      AppTone.warning => (fg: AppColor.warning, bg: AppColor.warningBg),
      AppTone.error => (fg: AppColor.error, bg: AppColor.errorBg),
      AppTone.info => (fg: AppColor.info, bg: AppColor.infoBg),
    };

/// Small status pill (e.g. "مفتوح", "مدفوع", "قيد المراجعة").
class AppBadge extends StatelessWidget {
  const AppBadge(this.label,
      {super.key, this.tone = AppTone.neutral, this.icon});

  final String label;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
      decoration: BoxDecoration(color: c.bg, borderRadius: AppRadii.rPill),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14.sp, color: c.fg),
            gapH(AppSpacing.xs),
          ],
          Text(label, style: AppText.labelSm.copyWith(color: c.fg)),
        ],
      ),
    );
  }
}

/// Selectable pill chip — filter bars, range selectors, place selectors.
///
/// Touch target is always ≥ 48 logical pixels tall (WCAG 2.5.5).
///
/// ```dart
/// // Text-only (analytics range/place chips)
/// AppChip(label: 'آخر 7 أيام', selected: true, onTap: () {});
///
/// // With leading asset icon + trailing chevron (filter chips)
/// AppChip(
///   label: selectedFilter ?? 'النشاط',
///   selected: selectedFilter != null,
///   onTap: _openSheet,
///   leadingAsset: AppImages.activitie,
///   trailingIcon: Icons.keyboard_arrow_down_rounded,
/// );
/// ```
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leadingAsset,
    this.leadingAssetColor,
    this.trailingIcon,
    this.semanticLabel,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Optional asset path for a leading icon (SVG or raster).
  final String? leadingAsset;

  /// Tint applied to [leadingAsset]. Defaults to white when selected,
  /// primary when unselected.
  final Color? leadingAssetColor;

  /// Optional trailing icon (e.g. `Icons.keyboard_arrow_down_rounded`).
  final IconData? trailingIcon;

  /// Overrides the default Semantics label (label + selected state).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? AppColor.white : AppColor.textPrimary;
    final iconFg = leadingAssetColor ??
        (selected ? AppColor.white : AppColor.primary);

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rPill,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          constraints: BoxConstraints(minHeight: 48.h),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.lg.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            color: selected ? AppColor.primary : AppColor.surfaceCard,
            borderRadius: AppRadii.rPill,
            border: Border.all(
              color: selected ? AppColor.primary : AppColor.border,
            ),
            boxShadow: selected ? AppShadows.primaryGlow : AppShadows.level0,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leadingAsset != null) ...[
                AppImage(
                  leadingAsset!,
                  height: 20.h,
                  width: 20.h,
                  color: iconFg,
                ),
                SizedBox(width: AppSpacing.sm.w),
              ],
              Text(
                label,
                style: AppText.labelMd.copyWith(
                  color: fg,
                  fontWeight:
                      selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (trailingIcon != null) ...[
                SizedBox(width: AppSpacing.xs.w),
                Icon(trailingIcon, color: fg, size: 22.sp),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
