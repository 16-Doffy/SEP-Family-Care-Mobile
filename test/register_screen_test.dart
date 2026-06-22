import 'package:family_care/screens/auth/register_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('registrationErrorMessage', () {
    test('maps an English duplicate phone error', () {
      expect(
        registrationErrorMessage(Exception('Phone already exists')),
        'Số điện thoại đã tồn tại',
      );
    });

    test('maps a Vietnamese duplicate phone error', () {
      expect(
        registrationErrorMessage(Exception('Số điện thoại đã tồn tại')),
        'Số điện thoại đã tồn tại',
      );
    });

    test('keeps unrelated backend errors', () {
      expect(
        registrationErrorMessage(Exception('Email already exists')),
        'Email already exists',
      );
    });
  });
}
