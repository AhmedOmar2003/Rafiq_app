import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/design/app_image.dart';
import '../../../core/utils/app_color.dart';

/// A custom stepper component that displays a series of steps with icons and connecting lines.
/// Each step can be tapped to navigate to that step.
class StepperComponent extends StatelessWidget {
  /// The index of this step in the sequence
  final int index;

  /// The icon to display for this step
  final String icon;

  /// The current active step index
  final int currentIndex;

  /// Callback function when the step is tapped
  final VoidCallback onTap;

  /// Whether this is the last step in the sequence
  final bool isLast;

  /// The size of the step circle
  final double stepSize;

  /// The color of the active step
  final Color activeColor;

  /// The color of the inactive step
  final Color inactiveColor;

  /// The color of the active line
  final Color activeLineColor;

  /// The color of the inactive line
  final Color inactiveLineColor;

  const StepperComponent({
    super.key,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.icon,
    this.isLast = false,
    this.stepSize = 50,
    this.activeColor = AppColor.primary,
    this.inactiveColor = AppColor.ofWhite,
    this.activeLineColor = AppColor.primary,
    this.inactiveLineColor = AppColor.lightGray,
  });

  /// Builds the step circle with the icon
  Widget _buildStepCircle(BuildContext context) {
    final bool isActive = currentIndex >= index;
    final bool isCurrent = index == currentIndex;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: stepSize.h,
        width: stepSize.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(100.r),
          color: isActive ? activeColor : inactiveColor,
          border: Border.all(
            color: isActive ? activeColor : inactiveLineColor,
          ),
        ),
        child: AppImage(
          icon,
          color: isCurrent ? AppColor.ofWhite : AppColor.white,
        ),
      ),
    );
  }

  /// Builds the connecting line between steps
  Widget _buildConnectingLine() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 5.w),
      height: 2.h,
      color: currentIndex >= index + 1 ? activeLineColor : inactiveLineColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLast) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStepCircle(context),
              _buildConnectingLine(),
            ],
          ),
        ],
      );
    }

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStepCircle(context),
              Expanded(child: _buildConnectingLine()),
            ],
          ),
        ],
      ),
    );
  }
}
