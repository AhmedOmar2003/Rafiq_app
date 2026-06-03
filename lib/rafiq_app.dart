import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:rafiq_app/auth/auth_gate.dart';
import 'package:rafiq_app/core/design/components/app_offline_banner.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/service/accessibility_preferences.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
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

  static const _sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        ErrorWidget.builder = (FlutterErrorDetails details) {
          final message = details.exception.toString();
          return Material(
            child: Container(
              color: Colors.red,
              child: Center(
                child: Text(
                  'حدث خطأ غير متوقع${const bool.fromEnvironment('dart.vm.product') ? '' : ': $message'}',
                  style: const TextStyle(color: Colors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        };

        return MaterialApp(
          title: AppStrings.appName,
          theme: ThemeServices().lightTheme,
          darkTheme: ThemeServices().darkTheme,
          // Brand light theme is canonical. Dark theme is fully token-wired and
          // ready — flip to ThemeMode.system once screens are dark-audited.
          themeMode: ThemeMode.light,
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            if (child == null) {
              return const SizedBox.shrink();
            }
            final mediaQuery = MediaQuery.of(context);
            return ValueListenableBuilder<double>(
              valueListenable: AccessibilityPreferences.instance.textScale,
              builder: (_, customTextScale, __) {
                final systemScale = mediaQuery.textScaler.scale(1);
                final effectiveScale =
                    (systemScale * customTextScale).clamp(1.0, 1.45);
                return Directionality(
                  textDirection: TextDirection.rtl,
                  child: MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaler: TextScaler.linear(effectiveScale),
                    ),
                    child: AppConnectivityScope(child: child),
                  ),
                );
              },
            );
          },
          navigatorKey: navigatorKey,
          navigatorObservers:
              _sentryDsn.isEmpty ? const [] : [SentryNavigatorObserver()],
          home: child,
        );
      },
      child: const AuthGate(),
    );
  }
}
