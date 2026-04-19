import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/on_boarding/cashe_helper.dart';
import 'package:rafiq_app/on_boarding/on_boarding_screen.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  bool _openedRecoveryPage = false;

  @override
  void initState() {
    super.initState();
    AuthService.ensureSupabaseInitialized().then((_) {
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
      future: Future.wait([
        AuthService.ensureSupabaseInitialized().then((_) => true),
        CacheHelper.getOnBoardingSeen(),
      ]),
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
