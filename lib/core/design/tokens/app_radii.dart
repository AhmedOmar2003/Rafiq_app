import 'package:flutter/widgets.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Border-radius scale.
///
/// The codebase currently mixes 8 / 12 / 15 / 16 / 24 / 25 / 36 radii. This
/// collapses them into one ladder so every surface feels related:
///
///   sm=8 (chips, small controls)
///   md=12 (buttons, inputs, list tiles)
///   lg=16 (cards)
///   xl=24 (bottom sheets, dialogs)
///   xxl=32 (hero / form top corners)
///   pill = fully rounded
class AppRadii {
  AppRadii._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double pill = 999;

  static BorderRadius get rSm => BorderRadius.circular(sm.r);
  static BorderRadius get rMd => BorderRadius.circular(md.r);
  static BorderRadius get rLg => BorderRadius.circular(lg.r);
  static BorderRadius get rXl => BorderRadius.circular(xl.r);
  static BorderRadius get rXxl => BorderRadius.circular(xxl.r);
  static BorderRadius get rPill => BorderRadius.circular(pill.r);

  /// Top-only radius for bottom sheets / form panels.
  static BorderRadius topOnly(double value) => BorderRadius.only(
        topLeft: Radius.circular(value.r),
        topRight: Radius.circular(value.r),
      );
}
