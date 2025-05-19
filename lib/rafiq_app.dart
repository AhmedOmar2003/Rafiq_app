import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/on_boarding/on_boarding_screen.dart';
import 'core/themes/theme_services.dart';
import 'core/utils/app_strings.dart';

/// The main application widget that sets up the app's configuration and theme.
///
/// This widget is responsible for:
/// - Setting up the app's theme
/// - Configuring screen utilities
/// - Setting up RTL support
/// - Initializing device preview
/// - Setting up navigation
class RafiqApp extends StatelessWidget {
  /// Creates a new instance of [RafiqApp].
  ///
  /// The [key] parameter is passed to the superclass constructor.
  const RafiqApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        // Set up error handling
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Material(
            child: Container(
              color: Colors.red,
              child: Center(
                child: Text(
                  'An error occurred: ${details.exception}',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          );
        };

        return MaterialApp(
          title: AppStrings.appName,
          theme: ThemeServices().lightTheme,
          //  darkTheme: ThemeServices().darkTheme,
          themeMode: ThemeMode
              .system, // Automatically switch between light and dark theme
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            if (child == null) {
              return const SizedBox.shrink();
            }
            return Directionality(
              textDirection: TextDirection.rtl,
              child: child,
            );
          },
          locale: DevicePreview.locale(context),
          navigatorKey: navigatorKey,
          home: child,
        );
      },
      child: const OnBoardingScreen(),
    );
  }
}
