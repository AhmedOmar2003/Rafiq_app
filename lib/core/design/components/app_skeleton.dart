import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/components/app_card.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Lightweight shimmer skeleton.
///
/// Perceived-performance tool: show content-shaped placeholders while data
/// loads instead of a spinner. One shared animation controller keeps it cheap.
/// Respects OS "reduce motion" (falls back to a static tint).
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius,
    this.isCircle = false,
  });

  final double? width;
  final double height;
  final double? radius;
  final bool isCircle;

  /// A ready-made card-shaped skeleton (image + two text lines).
  static Widget card({double? height}) => _SkeletonCard(height: height);

  /// A vertical list of [count] card skeletons.
  static Widget list({int count = 6, double? itemHeight}) => Column(
        children: List.generate(
          count,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: AppSpacing.lg.h),
            child: _SkeletonCard(height: itemHeight),
          ),
        ),
      );

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final shape = widget.isCircle ? BoxShape.circle : BoxShape.rectangle;
    final br = widget.isCircle
        ? null
        : (widget.radius != null
            ? BorderRadius.circular(widget.radius!.r)
            : AppRadii.rSm);

    if (reduceMotion) {
      return Container(
        width: widget.width,
        height: widget.height.h,
        decoration: BoxDecoration(
            color: AppColor.neutral200, shape: shape, borderRadius: br),
      );
    }

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          width: widget.width,
          height: widget.height.h,
          decoration: BoxDecoration(
            shape: shape,
            borderRadius: br,
            gradient: LinearGradient(
              begin: Alignment(-1 - t, 0),
              end: Alignment(1 - t, 0),
              colors: const [
                AppColor.neutral100,
                AppColor.neutral200,
                AppColor.neutral100
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({this.height});
  final double? height;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      elevation: 1,
      child: Row(
        children: [
          AppSkeleton(width: 64.w, height: height ?? 64, radius: AppRadii.md),
          gapH(AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppSkeleton(width: double.infinity, height: 14),
                gapV(AppSpacing.sm),
                const AppSkeleton(width: 140, height: 12),
                gapV(AppSpacing.sm),
                const AppSkeleton(width: 90, height: 12),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
