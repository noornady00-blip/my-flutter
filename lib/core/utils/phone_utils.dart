/// أدوات معالجة وتنسيق أرقام الهواتف السودانية والدولية وفورمات روابط الواتساب
class PhoneUtils {
  static const String sudanCountryCode = '249';
  static const String sudanPhonePrefix = '+249';
  static const int sudanPhoneLength = 9;

  /// تحويل الأرقام العربية والفارسية إلى أرقام إنجليزية قياسية
  static String convertArabicDigits(String input) {
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    const persian = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
    var res = input;
    for (int i = 0; i < 10; i++) {
      res = res.replaceAll(arabic[i], '$i').replaceAll(persian[i], '$i');
    }
    return res;
  }

  /// الخطوة 1: الدالة الوحيدة في المشروع لتطبيع الهواتف
  /// ⚠️ تطرح FormatException إذا كان الرقم غير صالح — استخدم tryNormalize() في واجهة المستخدم
  static String normalize(String input) {
    var res = convertArabicDigits(input.trim());
    res = res.replaceAll(RegExp(r'[^0-9]'), '');

    if (res.startsWith('00249')) {
      res = res.substring(5);
    } else if (res.startsWith('249') && res.length >= 11) {
      res = res.substring(3);
    }

    if (res.startsWith('0')) {
      res = res.substring(1);
    }

    if (res.length != 9) {
      throw const FormatException('رقم الهاتف يجب أن يكون 9 أرقام');
    }

    return '+249$res';
  }

  /// نسخة آمنة من normalize() لا تطرح استثناءً أبداً — تُرجع null عند فشل التطبيع
  /// استخدمها في واجهة المستخدم (build, itemBuilder, إلخ) لتجنب الأعطال
  static String? tryNormalize(String? input) {
    if (input == null || input.trim().isEmpty) return null;
    try {
      return normalize(input);
    } catch (_) {
      return null;
    }
  }

  /// مقارنة آمنة بين رقمين هاتف — لا تطرح استثناءً حتى لو كان أحدهما غير صالح
  static bool safeMatch(String? a, String? b) {
    if (a == null || b == null) return false;
    final na = tryNormalize(a);
    final nb = tryNormalize(b);
    if (na != null && nb != null) return na == nb;
    // Fallback: compare raw digits if normalization fails
    final ra = convertArabicDigits(a).replaceAll(RegExp(r'[^0-9]'), '');
    final rb = convertArabicDigits(b).replaceAll(RegExp(r'[^0-9]'), '');
    if (ra.length >= 9 && rb.length >= 9) {
      return ra.substring(ra.length - 9) == rb.substring(rb.length - 9);
    }
    return ra == rb;
  }

  static bool isValid(String input) {
    try {
      normalize(input);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// التنسيق المحلي للأرقام (0 + 9 أرقام)
  static String toLocalDisplay(String normalized) {
    try {
      final n = normalize(normalized);
      return '0${n.substring(4)}';
    } catch (_) {
      return normalized;
    }
  }

  /// تنسيق موحد ومثالي لرقم الهاتف للعرض في كامل التطبيق مثل: +249 912209596
  static String formatDisplay(String phone) {
    try {
      final n = normalize(phone);
      return '+249 ${n.substring(4)}';
    } catch (_) {
      final digits = convertArabicDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length >= 9) {
        return '+249 ${digits.substring(digits.length - 9)}';
      }
      return phone;
    }
  }

  /// استخراج الأرقام الـ 9 الصافية بدون بادئة للحقول المدخلة
  static String toRaw9(String phone) {
    try {
      final n = normalize(phone);
      return n.substring(4);
    } catch (_) {
      final digits = convertArabicDigits(phone).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.length >= 9 ? digits.substring(digits.length - 9) : digits;
    }
  }


  static String toAuthEmail(String normalized) {
    final n = normalize(normalized);
    final digits = n.replaceAll(RegExp(r'[^0-9]'), '');
    return '$digits@mahameek.com';
  }

  static bool isSuperAdminPhone(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    try {
      final n = normalize(phone);
      // Admin 1: 146979833 -> +249146979833
      // Admin 2: 912209596 -> +249912209596
      return n == '+249146979833' || n == '+249912209596';
    } catch (_) {
      return false;
    }
  }

  /// تجهيز رقم الواتساب لروابط wa.me (أرقام دولية صافية بدون +)
  static String formatWhatsAppNumber(String phone) {
    try {
      final n = normalize(phone);
      return n.substring(1); // Remove the '+'
    } catch (_) {
      return phone;
    }
  }
}
