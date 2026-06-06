import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:rafiq_app/core/design/tokens/tokens.dart';
import 'package:rafiq_app/models/subscription/plan.dart';

/// Visual rendition of a [PlanTier].
///
/// Two sizes — a compact pill for cards and a larger header chip for hero
/// sections — share the same colour ladder so a tier reads the same
/// everywhere it appears.
enum PlanBadgeSize { compact, header }

class PlanBadge extends StatelessWidget {
  const PlanBadge({
    super.key,
    required this.tier,
    this.size = PlanBadgeSize.compact,
  });

  final PlanTier tier;
  final PlanBadgeSize size;

  static const Map<PlanTier, _PlanStyle> _styles = {
    PlanTier.free: _PlanStyle(
      label: 'مجاني',
      icon: Icons.bookmark_outline_rounded,
      color: AppColor.neutral700,
      bg: AppColor.neutral100,
    ),
    PlanTier.pro: _PlanStyle(
      label: 'برو · موثَّق',
      icon: Icons.verified_rounded,
      color: AppColor.primary,
      bg: AppColor.primary50,
    ),
    PlanTier.max: _PlanStyle(
      label: 'ماكس · بريميوم',
      icon: Icons.workspace_premium_rounded,
      color: AppColor.primary700,
      bg: AppColor.primary100,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final s = _styles[tier]!;
    final isHeader = size == PlanBadgeSize.header;
    final padH = (isHeader ? AppSpacing.md : AppSpacing.sm).w;
    final padV = (isHeader ? AppSpacing.sm : AppSpacing.xs).h;
    final iconSize = (isHeader ? 16 : 14).sp;
    final textStyle = (isHeader ? AppText.labelMd : AppText.labelSm).copyWith(
      color: s.color,
      fontWeight: FontWeight.w800,
    );

    return Semantics(
      label: 'الخطة ${s.label}',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        decoration: BoxDecoration(
          color: s.bg,
          borderRadius: AppRadii.rPill,
          border: Border.all(color: s.color.withValues(alpha: 0.24)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, color: s.color, size: iconSize),
            SizedBox(width: 4.w),
            Text(s.label, style: textStyle),
          ],
        ),
      ),
    );
  }
}

class _PlanStyle {
  const _PlanStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.bg,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
}
