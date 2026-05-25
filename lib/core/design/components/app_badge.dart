import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
  const AppBadge(this.label, {super.key, this.tone = AppTone.neutral, this.icon});

  final String label;
  final AppTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = toneColors(tone);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
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

/// Selectable filter chip (used in filters / category pickers).
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color bg = selected ? AppColor.primary : AppColor.sand200;
    final Color fg = selected ? AppColor.textOnPrimary : AppColor.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.rPill,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
          decoration: BoxDecoration(color: bg, borderRadius: AppRadii.rPill),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16.sp, color: fg),
                gapH(AppSpacing.xs),
              ],
              Text(label, style: AppText.labelMd.copyWith(color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
