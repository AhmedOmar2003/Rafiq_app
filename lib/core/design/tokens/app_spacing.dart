import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Spacing scale (4pt base grid).
///
/// Every margin / padding / gap in the app should come from this scale instead
/// of magic numbers. Values are raw doubles; call `.w` / `.h` at the use-site,
/// or use the [gapH] / [gapV] helpers which already apply ScreenUtil.
///
///   xs=4  sm=8  md=12  lg=16  xl=20  xxl=24  xxxl=32  huge=40  giant=48
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16; // default screen gutter
  static const double xl = 20;
  static const double xxl = 24; // default page horizontal padding
  static const double xxxl = 32;
  static const double huge = 40;
  static const double giant = 48;

  /// Standard horizontal page padding used across screens.
  static EdgeInsets get pagePadding =>
      EdgeInsets.symmetric(horizontal: xxl.w, vertical: lg.h);

  static EdgeInsets get pageHorizontal =>
      EdgeInsets.symmetric(horizontal: xxl.w);
}

/// Vertical gap from the spacing scale (ScreenUtil-aware).
SizedBox gapV(double value) => SizedBox(height: value.h);

/// Horizontal gap from the spacing scale (ScreenUtil-aware).
SizedBox gapH(double value) => SizedBox(width: value.w);
