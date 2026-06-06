import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_app/service/auth_service.dart';

void main() {
  group('Google authentication intent', () {
    test('allows login only for a completed account', () {
      final error = AuthService.googleIntentError(
        intent: GoogleAuthIntent.login,
        emailState: const {
          'exists': true,
          'signup_completed': true,
        },
      );

      expect(error, isNull);
    });

    test('rejects login for an unregistered Google identity', () {
      final error = AuthService.googleIntentError(
        intent: GoogleAuthIntent.login,
        emailState: const {
          'exists': false,
          'signup_completed': false,
        },
      );

      expect(error, contains('اعمل حساب جديد'));
    });

    test('allows registration for a new Google identity', () {
      final error = AuthService.googleIntentError(
        intent: GoogleAuthIntent.register,
        emailState: const {
          'exists': false,
          'signup_completed': false,
        },
      );

      expect(error, isNull);
    });

    test('rejects registration for an existing completed account', () {
      final error = AuthService.googleIntentError(
        intent: GoogleAuthIntent.register,
        emailState: const {
          'exists': true,
          'signup_completed': true,
        },
      );

      expect(error, contains('تسجيل الدخول'));
    });

    test('fails closed when backend verification is unavailable', () {
      final error = AuthService.googleIntentError(
        intent: GoogleAuthIntent.login,
        emailState: const {'exists': true},
      );

      expect(error, contains('نتحقق من الحساب'));
    });
  });
}
