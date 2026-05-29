import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// Standardized modal bottom sheet.
///
/// Token-driven shape (xl top radius), drag handle, safe-area padding, and an
/// optional title row — so every sheet in the app looks and behaves the same.
class AppBottomSheet {
  AppBottomSheet._();

  static Future<T?> display<T>(
    BuildContext context,
    Widget widget, {
    String? title,
    bool isScrollControlled = true,
    bool showHandle = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      backgroundColor: AppColor.surfaceCard,
      barrierColor: AppColor.overlay,
      useSafeArea: true,
      // Drag handle is delivered by the global BottomSheetThemeData
      // (`showDragHandle: true`). Suppress it here when callers explicitly
      // pass `showHandle: false` so the helper still wins.
      showDragHandle: showHandle,
      shape:
          RoundedRectangleBorder(borderRadius: AppRadii.topOnly(AppRadii.xl)),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xxl.w,
              AppSpacing.md.h,
              AppSpacing.xxl.w,
              AppSpacing.xxl.h + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (title != null) ...[
                  Text(title,
                      style: AppText.headingSm, textAlign: TextAlign.center),
                  gapV(AppSpacing.lg),
                ],
                Flexible(child: widget),
              ],
            ),
          ),
        );
      },
    );
  }
}
