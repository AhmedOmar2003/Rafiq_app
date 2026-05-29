import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Surface container — the base for every card, tile and panel.
///
/// Centralizes radius + elevation + padding so cards across the app match.
/// Set [onTap] to make it tappable (adds ink + press feedback).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation = 1,
    this.color,
    this.radius,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;

  /// 0 = flat, 1 = resting, 2 = raised, 3 = floating (maps to AppShadows).
  final int elevation;
  final Color? color;
  final BorderRadius? radius;
  final BoxBorder? border;

  List<BoxShadow> get _shadow => switch (elevation) {
        0 => AppShadows.level0,
        2 => AppShadows.level2,
        3 => AppShadows.level3,
        _ => AppShadows.level1,
      };

  @override
  Widget build(BuildContext context) {
    final br = radius ?? AppRadii.rLg;
    final content = Container(
      padding: padding ?? EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: color ?? AppColor.surfaceCard,
        borderRadius: br,
        boxShadow: _shadow,
        border: border,
      ),
      child: child,
    );

    return Container(
      margin: margin,
      child: onTap == null
          ? content
          : Material(
              color: Colors.transparent,
              borderRadius: br,
              child: InkWell(
                onTap: onTap,
                borderRadius: br,
                splashColor: AppColor.primary.withValues(alpha: 0.06),
                highlightColor: AppColor.primary.withValues(alpha: 0.04),
                child: content,
              ),
            ),
    );
  }
}
