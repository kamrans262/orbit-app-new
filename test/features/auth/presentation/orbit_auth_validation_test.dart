import 'package:flutter_test/flutter_test.dart';
import 'package:orbit_ui/features/auth/domain/orbit_auth_validation.dart';

void main() {
  test('email and international phone validation rejects malformed values', () {
    expect(OrbitAuthValidation.recipient('valid@example.com'), isNull);
    expect(OrbitAuthValidation.recipient('+923001234567'), isNull);
    expect(OrbitAuthValidation.recipient('valid@'), isNotNull);
    expect(OrbitAuthValidation.recipient('03001234567'), isNotNull);
    expect(OrbitAuthValidation.recipient('z' * 191), isNotNull);
  });

  test('signup checks full name and password length/strength', () {
    expect(OrbitAuthValidation.signup('A', 'valid@example.com', 'GoodPassword123'), isNotNull);
    expect(OrbitAuthValidation.signup('A' * 121, 'valid@example.com', 'GoodPassword123'), isNotNull);
    expect(OrbitAuthValidation.signup('Test User', 'valid@example.com', 'short'), isNotNull);
    expect(OrbitAuthValidation.signup('Test User', 'valid@example.com', 'onlylettersandnothing'), isNotNull);
    expect(OrbitAuthValidation.signup('Test User', 'valid@example.com', '1' * 257), isNotNull);
    expect(OrbitAuthValidation.signup('Test User', 'valid@example.com', 'StrongPassword123'), isNull);
  });

  test('login requires valid destination without enforcing new password policy', () {
    expect(OrbitAuthValidation.login('unknown@example.com', 'old-pass'), isNull);
    expect(OrbitAuthValidation.login('bad', 'some-password'), isNotNull);
    expect(OrbitAuthValidation.login('unknown@example.com', ''), isNotNull);
  });
}
