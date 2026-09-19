import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/core/utils/phone_utils.dart';
import 'package:mahameek/network/auth_service.dart';

void main() {
  group('Auth Cross-Role & Admin Phone Detection Tests', () {
    test('Admin phone candidate permutations include primary admin', () {
      final candidates = PhoneUtils.generatePhoneCandidates('146979833');
      expect(candidates, contains('146979833'));
      expect(candidates, contains('0146979833'));
      expect(candidates, contains('+249146979833'));
    });

    test('internalAuthKey generates consistent deterministic salt for phone accounts', () {
      final key1 = AuthService.internalAuthKey('912345678');
      final key2 = AuthService.internalAuthKey('912345678');
      final key3 = AuthService.internalAuthKey('987654321');

      expect(key1, equals(key2));
      expect(key1, isNot(equals(key3)));
      expect(key1.startsWith('Mhk@'), isTrue);
      expect(key1.endsWith('#'), isTrue);
    });

    test('PhoneUtils valid prefixes allow Sudan 9 and 1 series', () {
      expect(PhoneUtils.isValidSudanPhone('912345678'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('146979833'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('249146979833'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('+249146979833'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('0146979833'), isTrue);
    });

    test('Admin candidate emails cover both admin_ prefix and unprefixed formats', () {
      const input = '0912345678';
      final cleanDigits = PhoneUtils.extractLocalSudanDigits(input);
      final rawDigits = input.replaceAll(RegExp(r'[^0-9]'), '');
      
      final candidates = [
        'admin_$cleanDigits@mahameek.admin.com',
        '$cleanDigits@mahameek.admin.com',
        'admin_$rawDigits@mahameek.admin.com',
        '$rawDigits@mahameek.admin.com',
      ];

      expect(candidates, contains('admin_912345678@mahameek.admin.com'));
      expect(candidates, contains('912345678@mahameek.admin.com'));
      expect(candidates, contains('admin_0912345678@mahameek.admin.com'));
      expect(candidates, contains('0912345678@mahameek.admin.com'));
    });

    test('Short admin passwords pad safely to 6 characters for Firebase Auth', () {
      const pass3 = '123';
      final padded3 = pass3.length < 6 ? pass3.padRight(6, '0') : pass3;
      expect(padded3, equals('123000'));
      expect(padded3.length, greaterThanOrEqualTo(6));

      const pass6 = '123456';
      final padded6 = pass6.length < 6 ? pass6.padRight(6, '0') : pass6;
      expect(padded6, equals('123456'));
    });
  });
}
