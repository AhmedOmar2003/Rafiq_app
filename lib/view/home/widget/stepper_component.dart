import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/design/app_image.dart';
import '../../../core/design/tokens/tokens.dart';

/// One node + connector in the home step indicator.
///
/// Visual states:
///   * `done`     → filled brand circle, white icon, brand connector ahead.
///   * `current`  → filled brand circle with soft glow + scale-up.
///   * `upcoming` → cream surface circle, muted icon, faint connector.
///
/// Optional [label] appears under the circle as `labelSm`.
class StepperComponent extends StatelessWidget {
  const StepperComponent({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.icon,
    this.label,
    this.isLast = false,
    this.stepSize = 52,
  });

  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final String icon;
  final String? label;
  final bool isLast;
  final double stepSize;

  bool get _isDone => currentIndex > index;
  bool get _isCurrent => currentIndex == index;
  bool get _isActive => _isDone || _isCurrent;

  Widget _buildCircle() {
    const activeColor = AppColor.primary;
    return Semantics(
      button: true,
      label: label,
      selected: _isCurrent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          scale: _isCurrent ? 1.05 : 1.0,
          duration: AppMotion.base,
          curve: AppMotion.standard,
          child: AnimatedContainer(
            duration: AppMotion.base,
            curve: AppMotion.standard,
            height: stepSize.h,
            width: stepSize.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isActive ? activeColor : AppColor.surfaceCard,
              border: Border.all(
                color: _isActive ? activeColor : AppColor.border,
                width: 1.5,
              ),
              boxShadow:
                  _isCurrent ? AppShadows.primaryGlow : AppShadows.level0,
            ),
            child: Center(
              child: _isDone
                  ? Icon(
                      Icons.check_rounded,
                      color: AppColor.white,
                      size: 22.sp,
                    )
                  : AppImage(
                      icon,
                      color: _isActive ? AppColor.white : AppColor.textTertiary,
                      height: 22.h,
                      width: 22.w,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConnector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xs.w),
      child: AnimatedContainer(
        duration: AppMotion.base,
        curve: AppMotion.standard,
        height: 2.h,
        color: _isDone ? AppColor.primary : AppColor.border,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final node = Column(
      children: [
        _buildCircle(),
        if (label != null) ...[
          gapV(AppSpacing.xs),
          AnimatedDefaultTextStyle(
            duration: AppMotion.base,
            style: AppText.labelSm.copyWith(
              color: _isActive ? AppColor.textPrimary : AppColor.textTertiary,
              fontWeight: _isCurrent ? FontWeight.w700 : FontWeight.w500,
            ),
            child: Text(label!, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ],
    );

    if (isLast) return node;

    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          node,
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: (stepSize / 2).h - 1),
              child: _buildConnector(),
            ),
          ),
        ],
      ),
    );
  }
}
