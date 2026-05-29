import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/on_boarding/cashe_helper.dart';
import 'package:rafiq_app/on_boarding/on_boarding_screen.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/service/user_role_store.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';
import 'package:rafiq_app/view/provider/hub/provider_hub_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Max time the splash will wait for Supabase/local prefs before falling
  /// back. After this, we let the user proceed (treat them as logged out)
  /// instead of spinning forever on a bad network.
  static const Duration _bootstrapTimeout = Duration(seconds: 10);

  StreamSubscription<AuthState>? _authSubscription;
  late final Future<List<Object>> _bootstrapFuture;
  bool _openedRecoveryPage = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = Future.wait<Object>([
      AuthService.ensureSupabaseInitialized().then((_) => true),
      CacheHelper.getOnBoardingSeen(),
      UserRoleStore.instance.ensureLoaded().then((_) => true),
    ]).timeout(
      _bootstrapTimeout,
      onTimeout: () => const <Object>[false, false, false],
    );

    _bootstrapFuture.then((_) {
      if (!mounted) {
        return;
      }
      _authSubscription =
          Supabase.instance.client.auth.onAuthStateChange.listen((data) {
        if (!mounted) {
          return;
        }

        if (data.event == AuthChangeEvent.passwordRecovery) {
          _openResetPasswordPage();
        }
      });

      _openRecoveryFromIncomingUrlIfNeeded();
    });
  }

  void _openResetPasswordPage() {
    if (_openedRecoveryPage || !mounted) return;
    _openedRecoveryPage = true;
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (_) => const ResetPasswordPage(),
      ),
    );
  }

  void _openRecoveryFromIncomingUrlIfNeeded() {
    if (_openedRecoveryPage || !mounted) return;
    final uri = Uri.base;
    final fragmentParams = Uri.splitQueryString(
      uri.fragment,
      encoding: utf8,
    );
    final queryParams = uri.queryParameters;
    final typeValue = (fragmentParams['type'] ?? queryParams['type'] ?? '')
        .toLowerCase()
        .trim();

    if (typeValue == 'recovery') {
      _openResetPasswordPage();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(
                'حدث خطأ أثناء تشغيل التطبيق: ${snapshot.error}',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        final results = snapshot.data ?? const [];
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          if (UserRoleStore.instance.isProvider.value) {
            return const ProviderHubScreen();
          }
          return ChoiceScreen(
            onPlanSelected: () {},
            onNoPlanSelected: () {},
            onNext: () {},
          );
        }

        final hasSeenOnBoarding = results.isNotEmpty && results[1] == true;
        if (!hasSeenOnBoarding) {
          return const OnBoardingScreen();
        }

        return const LoginScreen();
      },
    );
  }
}
