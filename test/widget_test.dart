import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_app/service/auth_service.dart';
import 'package:rafiq_app/service/api_service.dart';

void main() {
  test('Auth policy helpers enforce the expected input rules', () {
    expect(AuthService.isGmailEmail('user@gmail.com'), isTrue);
    expect(AuthService.isGmailEmail('user@yahoo.com'), isFalse);
    expect(AuthService.isStrongPassword('Aa1!aaaa'), isTrue);
    expect(AuthService.isStrongPassword('weakpass'), isFalse);
  });

  test('Account mode resolution keeps new users unchosen', () {
    final snapshot = ApiService.resolveAccountMode(
      accountMode: null,
      providerId: null,
    );

    expect(snapshot.hasChosenRole, isFalse);
    expect(snapshot.isProviderMode, isFalse);
    expect(snapshot.hasProviderHistory, isFalse);
  });

  test('Account mode resolution restores provider mode from backend choice',
      () {
    final snapshot = ApiService.resolveAccountMode(
      accountMode: 'provider',
      providerId: 'provider-123',
    );

    expect(snapshot.hasChosenRole, isTrue);
    expect(snapshot.isProviderMode, isTrue);
    expect(snapshot.hasProviderHistory, isTrue);
    expect(snapshot.providerId, 'provider-123');
  });

  test('Provider history without backend choice stays unchosen until user decides',
      () {
    final snapshot = ApiService.resolveAccountMode(
      accountMode: null,
      providerId: 'provider-123',
    );

    expect(snapshot.hasChosenRole, isFalse);
    expect(snapshot.isProviderMode, isFalse);
    expect(snapshot.hasProviderHistory, isTrue);
    expect(snapshot.providerId, 'provider-123');
  });
}
