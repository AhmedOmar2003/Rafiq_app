import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:rafiq_app/core/design/tokens/tokens.dart';

/// App themes derived entirely from design tokens.
///
/// Both themes share one type family (Rubik) and one radius/spacing language so
/// the product feels unified. The brand coffee-brown stays the primary in both.
/// `lightTheme` is the production theme; `darkTheme` is a coherent, token-driven
/// scaffold so dark mode is a config flip rather than a rewrite.
class ThemeServices {
  ThemeData get lightTheme => _build(_lightScheme, Brightness.light);
  ThemeData get darkTheme => _build(_darkScheme, Brightness.dark);

  static const ColorScheme _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: AppColor.primary,
    onPrimary: AppColor.textOnPrimary,
    primaryContainer: AppColor.primary100,
    onPrimaryContainer: AppColor.primary900,
    secondary: AppColor.primary400,
    onSecondary: AppColor.white,
    secondaryContainer: AppColor.sand200,
    onSecondaryContainer: AppColor.primary800,
    error: AppColor.error,
    onError: AppColor.white,
    errorContainer: AppColor.errorBg,
    onErrorContainer: AppColor.error,
    surface: AppColor.surfaceCard,
    onSurface: AppColor.textPrimary,
    surfaceContainerHighest: AppColor.sand200,
    onSurfaceVariant: AppColor.textSecondary,
    outline: AppColor.border,
    outlineVariant: AppColor.borderStrong,
    shadow: Color(0x14000000),
  );

  static const ColorScheme _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: AppColor.darkPrimary,
    onPrimary: AppColor.primary900,
    primaryContainer: AppColor.primary700,
    onPrimaryContainer: AppColor.primary50,
    secondary: AppColor.primary200,
    onSecondary: AppColor.primary900,
    secondaryContainer: AppColor.primary800,
    onSecondaryContainer: AppColor.primary50,
    error: Color(0xffE6857F),
    onError: AppColor.primary900,
    errorContainer: Color(0xff5A1B17),
    onErrorContainer: Color(0xffFBE9E7),
    surface: AppColor.darkSurfaceCard,
    onSurface: AppColor.darkTextPrimary,
    surfaceContainerHighest: AppColor.darkSurfaceVariant,
    onSurfaceVariant: AppColor.darkTextSecondary,
    outline: AppColor.darkBorder,
    outlineVariant: AppColor.darkBorder,
    shadow: Color(0x33000000),
  );

  ThemeData _build(ColorScheme scheme, Brightness brightness) {
    final bool isLight = brightness == Brightness.light;
    final Color pageBg = isLight ? AppColor.surface : AppColor.darkSurface;
    final Color fieldFill =
        isLight ? AppColor.surfaceCard : AppColor.darkSurfaceVariant;

    final base = ThemeData(brightness: brightness, useMaterial3: true);

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: pageBg,
      primaryColor: scheme.primary,
      dividerColor: isLight ? AppColor.divider : AppColor.darkBorder,
      textTheme: GoogleFonts.rubikTextTheme(base.textTheme).apply(
        bodyColor: scheme.onSurface,
        displayColor: scheme.onSurface,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: AppText.headingSm.copyWith(color: scheme.primary),
        iconTheme: IconThemeData(color: scheme.onSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: scheme.primary.withValues(alpha: 0.4),
          disabledForegroundColor: scheme.onPrimary.withValues(alpha: 0.8),
          elevation: 0,
          minimumSize: Size(double.infinity, 52.h),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: AppText.labelLg,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: Size(double.infinity, 52.h),
          side: BorderSide(color: scheme.primary, width: 1.5),
          textStyle: AppText.labelLg,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
          textStyle: AppText.labelMd,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fieldFill,
        contentPadding: EdgeInsets.symmetric(
            horizontal: AppSpacing.xl.w, vertical: AppSpacing.lg.h),
        hintStyle: AppText.bodyMd.copyWith(color: AppColor.textTertiary),
        labelStyle: AppText.labelMd.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.rMd,
          borderSide: BorderSide(color: scheme.error, width: 1.5),
        ),
        errorStyle: AppText.bodySm.copyWith(color: scheme.error),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rLg),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: AppRadii.topOnly(AppRadii.xl)),
        showDragHandle: true,
        dragHandleColor: AppColor.borderStrong,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rXl),
        titleTextStyle: AppText.headingSm.copyWith(color: scheme.onSurface),
        contentTextStyle: AppText.bodyLg.copyWith(color: scheme.onSurface),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.onSurface,
        contentTextStyle: AppText.bodyMd.copyWith(color: scheme.surface),
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rMd),
      ),
      chipTheme: ChipThemeData(
        backgroundColor:
            isLight ? AppColor.sand200 : AppColor.darkSurfaceVariant,
        selectedColor: scheme.primary,
        labelStyle: AppText.labelMd.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: AppText.labelMd.copyWith(color: scheme.onPrimary),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.rPill),
        padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w, vertical: AppSpacing.xs.h),
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? AppColor.divider : AppColor.darkBorder,
        thickness: 1,
        space: AppSpacing.lg,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
    );
  }
}
