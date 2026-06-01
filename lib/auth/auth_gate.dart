import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rafiq_app/auth/login/login_screen.dart';
import 'package:rafiq_app/auth/forget%20password/reset_password.dart';
import 'package:rafiq_app/core/logic/helper_methods.dart';
import 'package:rafiq_app/core/utils/app_microcopy.dart';
import 'package:rafiq_app/on_boarding/cashe_helper.dart';
import 'package:rafiq_app/on_boarding/on_boarding_screen.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/service/user_role_store.dart';
import 'package:rafiq_app/view/pages/choice/choice_screen.dart';
import 'package:rafiq_app/view/home/home_view.dart';
import 'package:rafiq_app/view/provider/hub/provider_hub_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthState>? _authSubscription;
  late Future<List<Object>> _bootstrapFuture;
  bool _openedRecoveryPage = false;

  @override
  void initState() {
    super.initState();
    _bootstrapFuture = _bootstrap();

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

  Future<List<Object>> _bootstrap() {
    return Future.wait<Object>([
      AuthService.ensureSupabaseInitialized().then((_) => true),
      CacheHelper.getOnBoardingSeen(),
      UserRoleStore.instance.ensureLoaded().then((_) => true),
    ]);
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
          if (kDebugMode) {
            debugPrint('AuthGate bootstrap failed: ${snapshot.error}');
          }
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'تعذر تجهيز التطبيق الآن.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'يبدو أن هناك مشكلة مؤقتة في الاتصال أو التهيئة. جرّب مرة أخرى، ولو استمرت المشكلة هنكمل معك من نفس النقطة.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _bootstrapFuture = _bootstrap();
                        });
                      },
                      child: const Text(AppCopy.retry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final results = snapshot.data ?? const [];
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          if (!UserRoleStore.instance.hasChosenRole.value) {
            return ChoiceScreen(
              onPlanSelected: () {},
              onNoPlanSelected: () {},
              onNext: () {},
            );
          }

          if (UserRoleStore.instance.isProvider.value) {
            return const ProviderHubScreen();
          }
          return const HomeView();
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
