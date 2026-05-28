import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:rafiq_app/core/utils/app_color.dart';

/// Semantic type scale (Rubik, RTL-friendly).
///
/// Replaces the ~20 size-named styles (textStyle16Light, textStyle24Medium...)
/// with role-based tokens so screens express intent, not pixels. One family
/// (Rubik) keeps Arabic + Latin consistent. Sizes use `.sp` (ScreenUtil) and
/// include sensible line-heights for Arabic legibility.
///
/// Roles (size / weight):
///   displayLg 34 bold · displayMd 30 bold
///   headingLg 24 semi · headingMd 22 semi · headingSm 20 semi
///   titleLg 18 medium · titleMd 16 medium
///   bodyLg 16 regular · bodyMd 14 regular · bodySm 12 regular
///   labelLg 16 medium · labelMd 14 medium · labelSm 12 medium
///   caption 11 regular
///
/// PERFORMANCE: Every style below is a `static final` (built once, on first
/// access) instead of a `static get` (rebuilt on every read). This avoids
/// re-allocating ~20 TextStyle objects on every widget build inside lists.
/// On the suggestions screen (~6 styles × 80 cards × N scrolls) this saves
/// thousands of TextStyle allocations per session.
///
/// `.sp` is read at *first* access — which happens after ScreenUtilInit is
/// already in place because every call site is inside `build()`. If you need
/// these before ScreenUtil is ready, use raw `Theme.of(context).textTheme`.
class AppText {
  AppText._();

  static TextStyle _rubik({
    required double size,
    required FontWeight weight,
    Color? color,
    double height = 1.4,
  }) =>
      GoogleFonts.rubik(
        fontSize: size.sp,
        fontWeight: weight,
        height: height,
        color: color ?? AppColor.textPrimary,
      );

  // Display ----------------------------------------------------------------
  static final TextStyle displayLg =
      _rubik(size: 34, weight: FontWeight.w700, height: 1.2);
  static final TextStyle displayMd =
      _rubik(size: 30, weight: FontWeight.w700, height: 1.25);

  // Headings ---------------------------------------------------------------
  static final TextStyle headingLg =
      _rubik(size: 24, weight: FontWeight.w600, height: 1.3);
  static final TextStyle headingMd =
      _rubik(size: 22, weight: FontWeight.w600, height: 1.3);
  static final TextStyle headingSm =
      _rubik(size: 20, weight: FontWeight.w600, height: 1.35);

  // Titles -----------------------------------------------------------------
  static final TextStyle titleLg =
      _rubik(size: 18, weight: FontWeight.w500, height: 1.4);
  static final TextStyle titleMd =
      _rubik(size: 16, weight: FontWeight.w500, height: 1.4);

  // Body -------------------------------------------------------------------
  static final TextStyle bodyLg =
      _rubik(size: 16, weight: FontWeight.w400, height: 1.55);
  static final TextStyle bodyMd = _rubik(
    size: 14,
    weight: FontWeight.w400,
    height: 1.55,
    color: AppColor.textSecondary,
  );
  static final TextStyle bodySm = _rubik(
    size: 12,
    weight: FontWeight.w400,
    height: 1.5,
    color: AppColor.textSecondary,
  );

  // Labels (controls, buttons, chips) --------------------------------------
  static final TextStyle labelLg =
      _rubik(size: 16, weight: FontWeight.w500, height: 1.2);
  static final TextStyle labelMd =
      _rubik(size: 14, weight: FontWeight.w500, height: 1.2);
  static final TextStyle labelSm =
      _rubik(size: 12, weight: FontWeight.w500, height: 1.2);

  // Caption / overline -----------------------------------------------------
  static final TextStyle caption = _rubik(
    size: 11,
    weight: FontWeight.w400,
    height: 1.4,
    color: AppColor.textTertiary,
  );
}
