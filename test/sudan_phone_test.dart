import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/core/utils/phone_utils.dart';

void main() {
  group('PhoneUtils.normalize (The Canonical Formatter)', () {
    test('Should normalize various formats to +249xxxxxxxxx', () {
      final expected = '+249912209596';
      
      expect(PhoneUtils.normalize('0912209596'), expected);
      expect(PhoneUtils.normalize('912209596'), expected);
      expect(PhoneUtils.normalize('+249912209596'), expected);
      expect(PhoneUtils.normalize('00249912209596'), expected);
      expect(PhoneUtils.normalize('249912209596'), expected);
      expect(PhoneUtils.normalize('0912 209 596'), expected);
      expect(PhoneUtils.normalize(' 0 912 209 596 '), expected);
      expect(PhoneUtils.normalize('+249 912-209-596'), expected);
    });

    test('Should handle Arabic/Persian digits', () {
      final expected = '+249912345678';
      expect(PhoneUtils.normalize('٠٩١٢٣٤٥٦٧٨'), expected);
      expect(PhoneUtils.normalize('۰۹۱۲۳۴۵۶۷۸'), expected);
    });

    test('Should accept numbers not starting with 9', () {
      expect(PhoneUtils.normalize('0103786461'), '+249103786461');
    });

    test('Should throw FormatException on invalid lengths', () {
      expect(() => PhoneUtils.normalize('09123456'), throwsFormatException); // 8 digits (too short)
      expect(() => PhoneUtils.normalize('09123456789'), throwsFormatException); // 11 digits (too long)
      expect(() => PhoneUtils.normalize(''), throwsFormatException);
    });
  });

  group('PhoneUtils.isValid', () {
    test('Should return true for valid numbers', () {
      expect(PhoneUtils.isValid('0912209596'), isTrue);
      expect(PhoneUtils.isValid('+249912209596'), isTrue);
      expect(PhoneUtils.isValid('٠٩١٢٣٤٥٦٧٨'), isTrue);
    });

    test('Should return false for invalid numbers', () {
      expect(PhoneUtils.isValid('09123456'), isFalse); // 8 digits
      expect(PhoneUtils.isValid('abc'), isFalse);
    });
  });

  group('PhoneUtils.toLocalDisplay', () {
    test('Should return local display format (0 + 9 digits)', () {
      expect(PhoneUtils.toLocalDisplay('+249912209596'), '0912209596');
      expect(PhoneUtils.toLocalDisplay('0912209596'), '0912209596'); // Normalizes first
    });
  });

  group('PhoneUtils.isSuperAdminPhone', () {
    test('Should identify admins', () {
      // 146979833 -> +249146979833
      expect(PhoneUtils.isSuperAdminPhone('146979833'), isTrue);
      expect(PhoneUtils.isSuperAdminPhone('+249146979833'), isTrue);
      expect(PhoneUtils.isSuperAdminPhone('0146979833'), isTrue); // Starts with 0

      // 912209596 -> +249912209596
      expect(PhoneUtils.isSuperAdminPhone('0912209596'), isTrue);

      expect(PhoneUtils.isSuperAdminPhone('0912345678'), isFalse);
    });
  });
}
