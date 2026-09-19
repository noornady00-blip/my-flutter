import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/core/utils/phone_utils.dart';

void main() {
  group('Sudan PhoneUtils & Formatter Tests', () {
    test('extractLocalSudanDigits strips leading zero and country codes', () {
      expect(PhoneUtils.extractLocalSudanDigits('0912345678'), equals('912345678'));
      expect(PhoneUtils.extractLocalSudanDigits('912345678'), equals('912345678'));
      expect(PhoneUtils.extractLocalSudanDigits('+249912345678'), equals('912345678'));
      expect(PhoneUtils.extractLocalSudanDigits('249912345678'), equals('912345678'));
      expect(PhoneUtils.extractLocalSudanDigits('00249912345678'), equals('912345678'));
      expect(PhoneUtils.extractLocalSudanDigits('0123456789'), equals('123456789'));
    });

    test('normalizeSudanPhone formats with and without plus', () {
      expect(PhoneUtils.normalizeSudanPhone('912345678', withPlus: true), equals('+249912345678'));
      expect(PhoneUtils.normalizeSudanPhone('0912345678', withPlus: true), equals('+249912345678'));
      expect(PhoneUtils.normalizeSudanPhone('+249912345678', withPlus: true), equals('+249912345678'));
      expect(PhoneUtils.normalizeSudanPhone('912345678', withPlus: false), equals('249912345678'));
    });

    test('formatWhatsAppNumber produces clean digits without plus', () {
      expect(PhoneUtils.formatWhatsAppNumber('912345678'), equals('249912345678'));
      expect(PhoneUtils.formatWhatsAppNumber('0912345678'), equals('249912345678'));
      expect(PhoneUtils.formatWhatsAppNumber('+249912345678'), equals('249912345678'));
      expect(PhoneUtils.formatWhatsAppNumber('249912345678'), equals('249912345678'));
      expect(PhoneUtils.formatWhatsAppNumber('201037864619'), equals('201037864619'));
    });

    test('isValidSudanPhone checks 9 digits and valid prefixes', () {
      expect(PhoneUtils.isValidSudanPhone('912345678'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('0912345678'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('+249912345678'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('123456789'), isTrue);
      expect(PhoneUtils.isValidSudanPhone('12345'), isFalse);
      expect(PhoneUtils.isValidSudanPhone('512345678'), isFalse);
    });

    test('generatePhoneCandidates contains all search permutations', () {
      final candidates = PhoneUtils.generatePhoneCandidates('912345678');
      expect(candidates, contains('912345678'));
      expect(candidates, contains('0912345678'));
      expect(candidates, contains('249912345678'));
      expect(candidates, contains('+249912345678'));
    });

    test('SudanPhoneInputFormatter prevents typing leading zero and limits to 9 digits', () {
      final formatter = SudanPhoneInputFormatter();

      // Typing '0' as first character -> becomes empty
      var res = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '0'),
      );
      expect(res.text, equals(''));

      // Typing '9' -> becomes '9'
      res = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '9'),
      );
      expect(res.text, equals('9'));

      // Pasting '0912345678' -> zero is stripped -> '912345678'
      res = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '0912345678'),
      );
      expect(res.text, equals('912345678'));

      // Pasting '+249912345678' -> '912345678'
      res = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '+249912345678'),
      );
      expect(res.text, equals('912345678'));

      // Pasting 12 digits -> truncated to 9 digits
      res = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '912345678999'),
      );
      expect(res.text, equals('912345678'));
      expect(res.text.length, equals(9));
    });
  });
}
