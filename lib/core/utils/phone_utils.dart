import 'package:flutter/services.dart';

/// أدوات معالجة وتنسيق أرقام الهواتف السودانية والدولية وفورمات روابط الواتساب
class PhoneUtils {
  /// مفتاح دولة السودان
  static const String sudanCountryCode = '249';
  static const String sudanPhonePrefix = '+249';
  static const int sudanPhoneLength = 9;

  // ==========================================
  // 1. SUDAN PHONE EXTRACTION & NORMALIZATION
  // ==========================================

  /// استخراج الأرقام المحلية السودانية فقط (9 أرقام بدون 0 في البداية وبدون رمز الدولة)
  /// أمثلة:
  /// - 0912345678     -> 912345678
  /// - +249912345678  -> 912345678
  /// - 249912345678   -> 912345678
  /// - 00249912345678 -> 912345678
  /// - 912345678      -> 912345678
  static String extractLocalSudanDigits(String phone) {
    var raw = phone.trim();
    if (raw.isEmpty) return '';

    // إزالة كل ما هو غير أرقام
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // إزالة الصفر الدولي 00249
    if (digits.startsWith('00249')) {
      digits = digits.substring(5);
    }
    // إزالة مفتاح السودان 249
    else if (digits.startsWith('249')) {
      digits = digits.substring(3);
    }

    // إزالة أي صفر بادئ (0)
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // اقتصار على 9 أرقام كحد أقصى للرقم السوداني
    if (digits.length > sudanPhoneLength) {
      digits = digits.substring(0, sudanPhoneLength);
    }

    return digits;
  }

  /// تحويل أي رقم سوداني مدخل إلى الصيغة القياسية الدولية (+2499XXXXXXXX أو 2499XXXXXXXX)
  /// أمثلة:
  /// - 0912345678     -> +249912345678 (أو 249912345678 إذا كان withPlus = false)
  /// - 912345678      -> +249912345678
  /// - +249912345678  -> +249912345678
  /// - 00249912345678 -> +249912345678
  static String normalizeSudanPhone(String phone, {bool withPlus = true}) {
    final local = extractLocalSudanDigits(phone);
    if (local.isEmpty) {
      final raw = phone.trim().replaceAll(RegExp(r'[^0-9]'), '');
      if (raw.isEmpty) return phone.trim();
      return withPlus ? '+$raw' : raw;
    }

    final full = '$sudanCountryCode$local';
    return withPlus ? '+$full' : full;
  }

  /// التحقق من صحة رقم الهاتف السوداني (يجب أن يكون 9 أرقام)
  static bool isValidSudanPhone(String phone) {
    final local = extractLocalSudanDigits(phone);
    // الأرقام في السودان تبدأ بـ 9 (زين، إم تي إن، سوداني) أو 1 (سوداني) وتتكون من 9 أرقام
    if (local.length != sudanPhoneLength) return false;
    return local.startsWith('9') || local.startsWith('1');
  }

  // ==========================================
  // 2. WHATSAPP URL FORMATTING
  // ==========================================

  /// تجهيز رقم الواتساب لروابط wa.me (أرقام دولية صافية بدون + وبدون أصفار بداية)
  /// هذا التنسيق يضمن فتح محادثة واتساب فوراً دون ظهور خطأ "رقم غير صالح"
  /// مثال: 249912345678 أو لأي رقم دولي آخر (مثل 201037864619)
  static String formatWhatsAppNumber(String phone) {
    var raw = phone.trim();
    if (raw.isEmpty) return '';

    // تنظيف جميع الرموز غير الرقمية
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // معالجة الأرقام السودانية
    if (digits.startsWith('00249')) {
      return digits.substring(2); // 249...
    } else if (digits.startsWith('249')) {
      return digits;
    } else if (digits.startsWith('0')) {
      // رقم محلي بصفر: 09XXXXXXXX -> 2499XXXXXXXX
      return '$sudanCountryCode${digits.substring(1)}';
    } else if (digits.length == sudanPhoneLength || (digits.length == 10 && !digits.startsWith('20'))) {
      // رقم محلي بدون مفتاح
      return '$sudanCountryCode$digits';
    }

    return digits;
  }

  // ==========================================
  // 3. CANDIDATES GENERATOR FOR AUTH/SEARCH
  // ==========================================

  /// توليد كافة التباديل المحتملة للرقم للبحث والمطابقة في تسجيل الدخول وقواعد البيانات
  /// يضمن أن يبحث النظام عن: 0912345678 و +249912345678 و 249912345678 و 912345678
  static Set<String> generatePhoneCandidates(String phone) {
    final raw = phone.trim();
    if (raw.isEmpty) return {};

    final clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    final candidates = <String>{raw, clean};

    final local = extractLocalSudanDigits(raw);
    if (local.isNotEmpty) {
      candidates.add(local);
      candidates.add('0$local');
      candidates.add('$sudanCountryCode$local');
      candidates.add('+$sudanCountryCode$local');
      candidates.add('00$sudanCountryCode$local');
    }

    final normalizedWithPlus = normalizeSudanPhone(raw, withPlus: true);
    final normalizedNoPlus = normalizeSudanPhone(raw, withPlus: false);
    candidates.add(normalizedWithPlus);
    candidates.add(normalizedNoPlus);

    candidates.removeWhere((s) => s.trim().isEmpty);
    return candidates;
  }

  // ==========================================
  // 4. DISPLAY FORMATTING
  // ==========================================

  /// تنسيق العرض للمستخدم (مثال: +249 912 345 678)
  static String formatForDisplay(String phone) {
    final local = extractLocalSudanDigits(phone);
    if (local.length == sudanPhoneLength) {
      return '+249 ${local.substring(0, 3)} ${local.substring(3, 6)} ${local.substring(6)}';
    }
    if (local.isNotEmpty) {
      return '+249 $local';
    }
    return phone;
  }
}

/// مخصص تحكم وإدخال أرقام الهواتف السودانية
/// - يمنع إدخال الصفر (0) في البداية ويحذفه تلقائياً
/// - يحذف الرموز والمفاتيح الدولية إذا تم لصقها (+249, 00249, 249)
/// - يقبل فقط الأرقام ويحدد الحد الأقصى بـ 9 أرقام
class SudanPhoneInputFormatter extends TextInputFormatter {
  static const int maxDigits = 9;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;
    if (text.isEmpty) {
      return const TextEditingValue(
        text: '',
        selection: TextSelection.collapsed(offset: 0),
      );
    }

    // تنظيف غير الأرقام
    var digits = text.replaceAll(RegExp(r'[^0-9]'), '');

    // إزالة الصفر الدولي أو المفتاح إذا تم لصقه
    if (digits.startsWith('00249')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('249')) {
      digits = digits.substring(3);
    }

    // إزالة أي صفر بادئ تلقائياً
    while (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    // تحديد الحد الأقصى بـ 9 أرقام
    if (digits.length > maxDigits) {
      digits = digits.substring(0, maxDigits);
    }

    return TextEditingValue(
      text: digits,
      selection: TextSelection.collapsed(offset: digits.length),
    );
  }
}
