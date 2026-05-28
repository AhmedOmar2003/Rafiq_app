import 'package:flutter_test/flutter_test.dart';
import 'package:rafiq_app/service/auth_service.dart';

void main() {
  test('Auth policy helpers enforce the expected input rules', () {
    expect(AuthService.isGmailEmail('user@gmail.com'), isTrue);
    expect(AuthService.isGmailEmail('user@yahoo.com'), isFalse);
    expect(AuthService.isStrongPassword('Aa1!aaaa'), isTrue);
    expect(AuthService.isStrongPassword('weakpass'), isFalse);
  });
}
