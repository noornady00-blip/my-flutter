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

  /// تحويل الأرقام العربية والفارسية إلى أرقام إنجليزية قياسية
  static String normalizeDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    return res;
  }

  /// استخراج الأرقام المحلية السودانية فقط (9 أرقام بدون 0 في البداية وبدون رمز الدولة)
  /// أمثلة:
  /// - 0912345678     -> 912345678
  /// - +249912345678  -> 912345678
  /// - 249912345678   -> 912345678
  /// - 00249912345678 -> 912345678
  /// - 912345678      -> 912345678
  static String extractLocalSudanDigits(String phone) {
    var raw = normalizeDigits(phone.trim());
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

    // استثناء خاص للمشرف الرئيسي: 01146979833 أو 1146979833
    if (digits.endsWith('1146979833')) {
      return '1146979833';
    }

    // اقتصار على 9 أرقام كحد أقصى للرقم السوداني
    if (digits.length > sudanPhoneLength) {
      digits = digits.substring(0, sudanPhoneLength);
    }

    return digits;
  }

  /// التحقق مما إذا كان الرقم يعود لأحد المشرفين الأساسيين (الأدمن 1: 01146979833 أو الأدمن 2: 912209596 / +249912209596)
  static bool isSuperAdminPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return false;

    // المشرف الأساسي 1: 01146979833
    final bool isAdmin1 = digits.endsWith('1146979833') ||
        digits == '01146979833' ||
        digits == '1146979833' ||
        digits == '0146979833' ||
        digits == '146979833';

    // المشرف الأساسي 2: 91 220 9596 (0912209596 / +249912209596)
    final bool isAdmin2 = digits.endsWith('912209596') ||
        digits == '912209596' ||
        digits == '0912209596' ||
        digits == '249912209596';

    return isAdmin1 || isAdmin2;
  }

  /// التحقق مما إذا كان الرقم هو المشرف الأساسي الأول (01146979833)
  static bool isPrimaryAdmin1(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.endsWith('1146979833') ||
        digits == '01146979833' ||
        digits == '1146979833' ||
        digits == '0146979833' ||
        digits == '146979833';
  }

  /// التحقق مما إذا كان الرقم هو المشرف الأساسي الثاني (0912209596 / +249912209596)
  static bool isPrimaryAdmin2(String? phone) {
    if (phone == null || phone.trim().isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.endsWith('912209596') ||
        digits == '912209596' ||
        digits == '0912209596' ||
        digits == '249912209596';
  }

  /// التحقق مما إذا كان الرقمان يعودان لنفس المشرف
  static bool isSameAdminPhone(String? phone1, String? phone2) {
    if (phone1 == null || phone2 == null) return false;
    final d1 = extractLocalSudanDigits(phone1);
    final d2 = extractLocalSudanDigits(phone2);
    if (d1.isNotEmpty && d2.isNotEmpty && d1 == d2) return true;
    final c1 = phone1.replaceAll(RegExp(r'[^0-9]'), '');
    final c2 = phone2.replaceAll(RegExp(r'[^0-9]'), '');
    if (c1.isNotEmpty && c2.isNotEmpty && (c1 == c2 || c1.endsWith(c2) || c2.endsWith(c1))) {
      return true;
    }
    return false;
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

  /// الصيغة الموحدة الرسمية الوحيدة لحفظ أرقام الهواتف في كامل المنصة وقاعدة البيانات
  /// مفتاح الدولة + الرقم المحلي (مثال: +249912345678 أو للمشرف +2491146979833)
  static String toUnifiedPhone(String phone) {
    return normalizeSudanPhone(phone, withPlus: true);
  }

  /// استخراج الرقم المحلي المجرد (9 أرقام تبدأ بـ 9) الذي يدخله العميل في الواجهة
  /// مثال: 912345678
  static String toLocalDisplay(String phone) {
    return extractLocalSudanDigits(phone);
  }

  /// تنظيف أي نص وحذف كافة الرموز غير الرقمية
  static String cleanDigits(String phone) {
    return normalizeDigits(phone.trim()).replaceAll(RegExp(r'[^0-9]'), '');
  }

  /// الصيغة الموحدة للرقم
  static String normalizePhone(String phone, {bool withPlus = true}) {
    return normalizeSudanPhone(phone, withPlus: withPlus);
  }

  /// تحويل الرقم للصيغة المحلية (09...)
  static String toLocalFormat(String phone) {
    final local = extractLocalSudanDigits(phone);
    return local.isNotEmpty ? '0$local' : phone.trim();
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
    var raw = normalizeDigits(phone.trim());
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
