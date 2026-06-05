import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Live HH:MM:SS countdown badge.
///
/// Ticks every second. Computes the remaining time from [createdAt] + [sla]
/// and shows it in a pill-shaped container. When the deadline passes it shows
/// [expiredLabel] ("انتهت المهلة" by default).
///
/// Used for:
///   - Place moderation SLA ("خلال 24 ساعة")
///   - Campaign review SLA ("خلال 6 ساعات")
///
/// ```dart
/// AppCountdownBadge(
///   createdAt: place.createdAt,
///   sla: const Duration(hours: 24),
///   color: AppColor.warning,
/// )
/// ```
class AppCountdownBadge extends StatefulWidget {
  const AppCountdownBadge({
    super.key,
    required this.createdAt,
    required this.sla,
    required this.color,
    this.expiredLabel = 'انتهت المهلة',
    this.unknownLabel = 'جارٍ الاحتساب',
    this.leadingIcon = Icons.timer_outlined,
  });

  final DateTime? createdAt;
  final Duration sla;
  final Color color;

  /// Shown when `createdAt` is null.
  final String unknownLabel;

  /// Shown when the countdown has passed zero.
  final String expiredLabel;

  /// Icon shown before the countdown text.
  final IconData leadingIcon;

  @override
  State<AppCountdownBadge> createState() => _AppCountdownBadgeState();
}

class _AppCountdownBadgeState extends State<AppCountdownBadge> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _formatted() {
    final createdAt = widget.createdAt;
    if (createdAt == null) return widget.unknownLabel;
    final remaining = createdAt.add(widget.sla).difference(DateTime.now());
    if (remaining.isNegative) return widget.expiredLabel;
    final h = remaining.inHours.toString().padLeft(2, '0');
    final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
    final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final text = _formatted();
    final isExpired = text == widget.expiredLabel;

    return Semantics(
      label: 'الوقت المتبقي: $text',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.sm.w,
          vertical: 3.h,
        ),
        decoration: BoxDecoration(
          color: isExpired ? AppColor.errorBg : AppColor.surfaceCard,
          borderRadius: AppRadii.rPill,
          border: Border.all(
            color: (isExpired ? AppColor.error : widget.color)
                .withValues(alpha: 0.28),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isExpired ? Icons.timer_off_outlined : widget.leadingIcon,
              size: 12.sp,
              color: isExpired ? AppColor.error : widget.color,
            ),
            SizedBox(width: AppSpacing.xs.w),
            Text(
              text,
              style: AppText.labelSm.copyWith(
                color: isExpired ? AppColor.error : widget.color,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
