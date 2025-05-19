import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../utils/app_color.dart';

class ThemeServices {
  final lightTheme = ThemeData.light().copyWith(
    primaryColor: AppColor.primary,
    scaffoldBackgroundColor: AppColor.ofWhite,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: AppColor.white,
      elevation: 0.0,
      titleTextStyle: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        color: AppColor.primary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColor.primary,
        elevation: 0.0,
        fixedSize: Size.fromHeight(48.h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size(248.w, 48.h),
        textStyle: TextStyle(
          fontSize: 25.sp,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25.r),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.r),
        ),
        side: const BorderSide(
          color: AppColor.primary,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.r),
        borderSide: BorderSide(
          color: const Color(0xff000000).withOpacity(.79),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.r),
        borderSide: const BorderSide(
          color: AppColor.primary,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.r),
        borderSide: BorderSide(
          color: const Color(0xff000000).withOpacity(.79),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.r),
        borderSide: BorderSide(
          color: const Color(0xff000000).withOpacity(.79),
        ),
      ),
      fillColor: AppColor.ofWhite,
      filled: true,
    ),
    dividerColor: Colors.black12,
  );

  final darkTheme = ThemeData.dark().copyWith(
    appBarTheme: AppBarTheme(
      centerTitle: true,
      backgroundColor: AppColor.white,
      elevation: 0.0,
      titleTextStyle: TextStyle(
        fontSize: 20.sp,
        fontWeight: FontWeight.bold,
        color: AppColor.primary,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColor.primary,
        elevation: 0.0,
        fixedSize: Size.fromHeight(60.h),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: Size(343.w, 60.h),
        textStyle: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.r),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.r),
        ),
        side: const BorderSide(
          color: AppColor.primary,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.r),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.r),
        borderSide: const BorderSide(
          color: Color(0xffF3F3F3),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15.r),
        borderSide: const BorderSide(
          color: Color(0xffF3F3F3),
        ),
      ),
      fillColor: Colors.white,
      filled: true,
    ),
    dividerColor: Colors.white54,
  );
}
