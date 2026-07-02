import 'package:flutter/material.dart';

/// "على فين؟" color tokens.
///
/// This is the single source of truth for color across the Flutter app.
/// Screens should use role and semantic tokens instead of raw color values.
class AppColor {
  AppColor._();

  // Brand primitives.
  static const brandPrimary = Color(0xff0F5D7A); // Nile Blue
  static const brandSecondary = Color(0xff1FA5A3); // Turquoise
  static const brandAccent = Color(0xffD9A441); // Golden Sand
  static const brandGreen = Color(0xff4E8B57); // Date Palm Green
  static const brandTerracotta = Color(0xffB85C38); // Terracotta

  // Neutral primitives.
  static const papyrus = Color(0xffF6F1E7);
  static const surfaceSoft = Color(0xffFAF7EF);
  static const mist = Color(0xffD9E1E5);
  static const charcoal = Color(0xff1F2933);
  static const accessibleBlack = Color(0xff0B1117);
  static const white = Color(0xffFFFFFF);

  // Brand scales retained for backwards-compatible component references.
  static const primary50 = Color(0xffEAF4F6);
  static const primary100 = Color(0xffD4E9ED);
  static const primary200 = Color(0xffA9D2DA);
  static const primary300 = Color(0xff73B2C1);
  static const primary400 = Color(0xff377F97);
  static const primary500 = brandPrimary;
  static const primary600 = Color(0xff0C526C);
  static const primary700 = Color(0xff09445A);
  static const primary800 = Color(0xff073747);
  static const primary900 = Color(0xff052936);

  // Warm surface scale.
  static const sand50 = surfaceSoft;
  static const sand100 = papyrus;
  static const sand200 = Color(0xffEFE8DA);
  static const sand300 = Color(0xffE5DAC6);
  static const sand400 = Color(0xffD7C7AA);

  // Neutral scale.
  static const neutral0 = white;
  static const neutral50 = Color(0xffFAFBFB);
  static const neutral100 = Color(0xffF3F5F6);
  static const neutral200 = mist;
  static const neutral300 = Color(0xffC2CDD2);
  static const neutral400 = Color(0xff9BA9B0);
  static const neutral500 = Color(0xff7C8990);
  static const neutral600 = Color(0xff6B7280);
  static const neutral700 = Color(0xff4B5563);
  static const neutral800 = charcoal;
  static const neutral900 = accessibleBlack;

  // Semantic states. Labels and icons must accompany color in UI.
  // Darkened for WCAG AA when used as small text on white.
  static const success = Color(0xff3F7448);
  static const successBg = Color(0xffEDF5EE);
  static const warning = Color(0xff7A5400);
  static const warningBg = Color(0xffF8EED9);
  static const error = brandTerracotta;
  static const errorBg = Color(0xffF8ECE7);
  static const info = brandPrimary;
  static const infoBg = Color(0xffEAF2F5);
  static const secondaryBg = Color(0xffE6F5F4);

  // Surface roles.
  static const surface = papyrus;
  static const surfaceVariant = surfaceSoft;
  static const surfaceCard = white;
  static const surfaceInverse = accessibleBlack;
  static const surfaceDefault = surface;
  static const surfaceElevated = surfaceCard;
  static const surfaceMuted = surfaceSoft;

  // Border and content roles.
  static const border = mist;
  static const borderStrong = neutral300;
  static const divider = Color(0x1FD9E1E5);
  static const textPrimary = charcoal;
  static const textSecondary = Color(0xff4B5563);
  static const textTertiary = Color(0xff6B7280);
  static const textMuted = textTertiary;
  static const textInverse = white;
  static const textOnPrimary = white;
  static const textDisabled = neutral400;

  // Interaction roles.
  static const focus = brandSecondary;
  static const overlay = Color(0x990B1117);
  static const overlaySoft = Color(0x520B1117);
  static const actionPrimary = brandPrimary;
  static const actionPrimaryHover = primary600;
  static const actionPrimaryActive = primary700;
  static const actionSecondary = brandSecondary;
  static const actionAccent = brandAccent;

  // Status aliases.
  static const statusSuccess = success;
  static const statusWarning = warning;
  static const statusDanger = error;
  static const statusInfo = info;

  // Compatibility aliases used by existing screens.
  static const primary = brandPrimary;
  static const black = accessibleBlack;
  static const ofWhite = papyrus;
  static const gray = textTertiary;
  static const greyColor = neutral500;
  static const lightGray = mist;
}
