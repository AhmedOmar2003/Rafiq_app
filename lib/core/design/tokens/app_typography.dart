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

  // Display
  static TextStyle get displayLg =>
      _rubik(size: 34, weight: FontWeight.w700, height: 1.2);
  static TextStyle get displayMd =>
      _rubik(size: 30, weight: FontWeight.w700, height: 1.25);

  // Headings
  static TextStyle get headingLg =>
      _rubik(size: 24, weight: FontWeight.w600, height: 1.3);
  static TextStyle get headingMd =>
      _rubik(size: 22, weight: FontWeight.w600, height: 1.3);
  static TextStyle get headingSm =>
      _rubik(size: 20, weight: FontWeight.w600, height: 1.35);

  // Titles
  static TextStyle get titleLg =>
      _rubik(size: 18, weight: FontWeight.w500, height: 1.4);
  static TextStyle get titleMd =>
      _rubik(size: 16, weight: FontWeight.w500, height: 1.4);

  // Body
  static TextStyle get bodyLg =>
      _rubik(size: 16, weight: FontWeight.w400, height: 1.55);
  static TextStyle get bodyMd =>
      _rubik(size: 14, weight: FontWeight.w400, height: 1.55, color: AppColor.textSecondary);
  static TextStyle get bodySm =>
      _rubik(size: 12, weight: FontWeight.w400, height: 1.5, color: AppColor.textSecondary);

  // Labels (controls, buttons, chips)
  static TextStyle get labelLg =>
      _rubik(size: 16, weight: FontWeight.w500, height: 1.2);
  static TextStyle get labelMd =>
      _rubik(size: 14, weight: FontWeight.w500, height: 1.2);
  static TextStyle get labelSm =>
      _rubik(size: 12, weight: FontWeight.w500, height: 1.2);

  // Caption / overline
  static TextStyle get caption =>
      _rubik(size: 11, weight: FontWeight.w400, height: 1.4, color: AppColor.textTertiary);
}
