import 'package:flutter/material.dart';

import 'package:rafiq_app/core/design/tokens/app_typography.dart';

/// Legacy size-named text styles — kept as thin aliases over [AppText].
///
/// All new code should use `AppText.titleLg`, `AppText.bodyMd`, etc. directly.
/// This wrapper exists only to keep older call sites compiling while the rest
/// of the app finishes migrating.
@Deprecated('Use AppText (lib/core/design/tokens/app_typography.dart).')
class TextStyleTheme {
  TextStyleTheme._();

  // The original colors here were arbitrary; every call site uses copyWith()
  // to override anyway. The aliases below preserve sizing + weight intent
  // and drop the raw color so AppText's semantic defaults take over.

  static TextStyle get textStyle16Light => AppText.bodyLg;
  static TextStyle get textStyle18Medium => AppText.titleLg;
  static TextStyle get textStyle30Medium => AppText.displayMd;
  static TextStyle get textStyle35Medium => AppText.displayLg;
  static TextStyle get textStyle25Medium => AppText.headingLg;
  static TextStyle get textStyle24Medium => AppText.headingLg;
  static TextStyle get textStyle20Regular => AppText.headingSm;
  static TextStyle get textStyle20Medium => AppText.headingSm;
  static TextStyle get textStyle20Bold =>
      AppText.headingSm.copyWith(fontWeight: FontWeight.w700);
  static TextStyle get textStyle22Medium => AppText.headingMd;
  static TextStyle get textStyle15Regular => AppText.bodyMd;
  static TextStyle get textStyle15Medium => AppText.labelMd;
  static TextStyle get textStyle16Regular => AppText.bodyLg;
  static TextStyle get textStyle16Medium => AppText.labelLg;
  static TextStyle get textStyle14Regular => AppText.bodyMd;
  static TextStyle get textStyle12Regular => AppText.bodySm;
  static TextStyle get textStyle12Medium => AppText.labelSm;
  static TextStyle get textStyle11Medium =>
      AppText.caption.copyWith(fontWeight: FontWeight.w500);
}
