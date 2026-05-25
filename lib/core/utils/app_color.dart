import 'package:flutter/material.dart';

/// Rafiq color tokens.
///
/// Single source of truth for every color in the product. The brand identity
/// (coffee-brown primary + warm cream surfaces + near-black text) is preserved
/// exactly — the original constants below are unchanged. Everything added on top
/// is a *scale* or a *semantic* token so screens stop hardcoding raw colors.
///
/// Naming:
///   - Brand scales:   primaryNN / sandNN / neutralNN  (50 = lightest .. 900 = darkest)
///   - Semantic:       success / warning / error / info (+ `*Bg` soft surface)
///   - Roles:          surface*, border*, text*, overlay, focus
///
/// Rule of thumb for screens: use SEMANTIC/ROLE tokens, not raw scale steps.
class AppColor {
  AppColor._();

  // ---------------------------------------------------------------------------
  // Original brand constants — DO NOT change values (visual identity contract).
  // ---------------------------------------------------------------------------
  static const black = Color(0xff14171F);
  static const white = Color(0xffFFFFFF);
  static const primary = Color(0xff681F00);
  static const ofWhite = Color(0xffF7F3DA);
  static const gray = Color(0xff707070);
  static const greyColor = Color(0xff979797);
  static const lightGray = Color(0xffCDC9C9);

  // ---------------------------------------------------------------------------
  // Primary scale — derived around the brand coffee-brown (#681F00 == primary500)
  // ---------------------------------------------------------------------------
  static const primary50 = Color(0xffFBEEE9);
  static const primary100 = Color(0xffF3D4C7);
  static const primary200 = Color(0xffE0A78F);
  static const primary300 = Color(0xffC97A57);
  static const primary400 = Color(0xff9C4A26);
  static const primary500 = primary; // #681F00 brand base
  static const primary600 = Color(0xff5A1B00);
  static const primary700 = Color(0xff4A1600);
  static const primary800 = Color(0xff3A1100);
  static const primary900 = Color(0xff240B00);

  // ---------------------------------------------------------------------------
  // Sand / cream scale — the warm app background family (#F7F3DA, #F2EFD6)
  // ---------------------------------------------------------------------------
  static const sand50 = Color(0xffFDFCF4);
  static const sand100 = ofWhite; // #F7F3DA app background
  static const sand200 = Color(0xffF2EFD6); // adaptive icon bg
  static const sand300 = Color(0xffE9E3BF);
  static const sand400 = Color(0xffDED7A8);

  // ---------------------------------------------------------------------------
  // Neutral scale — text, borders, dividers, disabled states
  // ---------------------------------------------------------------------------
  static const neutral0 = white;
  static const neutral50 = Color(0xffF7F6F2);
  static const neutral100 = Color(0xffF0EEE9);
  static const neutral200 = Color(0xffE3E1DB);
  static const neutral300 = lightGray; // #CDC9C9
  static const neutral400 = Color(0xffB4B0AC);
  static const neutral500 = greyColor; // #979797
  static const neutral600 = gray; // #707070
  static const neutral700 = Color(0xff4C4F57);
  static const neutral800 = Color(0xff2A2D35);
  static const neutral900 = black; // #14171F

  // ---------------------------------------------------------------------------
  // Semantic — warm-tuned so they sit naturally beside the brand (no neon).
  // ---------------------------------------------------------------------------
  static const success = Color(0xff2E7D5B);
  static const successBg = Color(0xffE6F4EE);
  static const warning = Color(0xffC9821E);
  static const warningBg = Color(0xffFBF0DD);
  static const error = Color(0xffC5362F);
  static const errorBg = Color(0xffFBE9E7);
  static const info = Color(0xff2C6E9B);
  static const infoBg = Color(0xffE5F0F7);

  // ---------------------------------------------------------------------------
  // Role tokens (light theme) — what screens & components should reference.
  // ---------------------------------------------------------------------------
  static const surface = sand100; // page background
  static const surfaceVariant = sand50; // subtle alt background
  static const surfaceCard = white; // cards / sheets / inputs
  static const surfaceInverse = neutral900;

  static const border = neutral200;
  static const borderStrong = neutral300;
  static const divider = Color(0x14000000); // black @ ~8%

  static const textPrimary = neutral900;
  static const textSecondary = neutral600;
  static const textTertiary = neutral500;
  static const textInverse = white;
  static const textOnPrimary = white;
  static const textDisabled = neutral400;

  static const focus = primary400;
  static const overlay = Color(0x99000000); // scrims / modal backdrop @ 60%
  static const overlaySoft = Color(0x52000000); // @ 32%

  // ---------------------------------------------------------------------------
  // Role tokens (dark theme readiness) — referenced by the dark ThemeData.
  // ---------------------------------------------------------------------------
  static const darkSurface = Color(0xff14110E);
  static const darkSurfaceVariant = Color(0xff1E1A16);
  static const darkSurfaceCard = Color(0xff241F1A);
  static const darkBorder = Color(0xff3A332C);
  static const darkTextPrimary = Color(0xffF5F1E8);
  static const darkTextSecondary = Color(0xffB9B2A6);
  static const darkPrimary = primary200; // lighter brand for contrast on dark
}
