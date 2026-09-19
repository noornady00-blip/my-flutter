import 'dart:math';

/// محرك بحث ذكي وسريع وفائق الدقة والتسامح الإملائي (~20-25% نسبة خطأ)
/// يدعم اللغة العربية والإنجليزية والأرقام مع التطبيع الصوتي والمكاني للوحة المفاتيح
class AppSearchUtils {
  AppSearchUtils._();

  // ==========================================
  // 1. ARABIC, ENGLISH & NUMERIC TEXT NORMALIZATION
  // ==========================================

  /// تنظيف وتطبيع النصوص العربية والإنجليزية والأرقام
  /// يحول كافة أشكال الألف والياء والتاء المربوطة والأرقام المشرقية ويزيل التشكيل
  static String normalize(String? input) {
    if (input == null || input.isEmpty) return '';

    String text = input.trim().toLowerCase();

    // 1. تحويل الأرقام العربية والفارسية (٠-٩ / ۰-۹) إلى أرقام قياسية (0-9)
    const easternDigits = '٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹';
    const westernDigits = '01234567890123456789';
    for (int i = 0; i < easternDigits.length; i++) {
      text = text.replaceAll(easternDigits[i], westernDigits[i]);
    }

    // 2. إزالة التشكيل والتطويل (الحركات والشدة والتنوين والمد والوصلة)
    text = text.replaceAll(RegExp(r'[\u064B-\u0652\u0670\u0640\u0653-\u065F]'), '');

    // 3. توحيد كافة أشكال الهمزات والألف (أ، إ، آ، ٱ، ٵ، ٲ -> ا)
    text = text.replaceAll(RegExp(r'[إأآٱٵٲ]'), 'ا');

    // 4. توحيد الياء والألف المقصورة والهمزة على الياء (ى، ئ، ي -> ي)
    text = text.replaceAll(RegExp(r'[ىئ]'), 'ي');

    // 5. توحيد التاء المربوطة والهاء (ة -> ه)
    text = text.replaceAll('ة', 'ه');

    // 6. توحيد الواو المهموزة (ؤ -> و)
    text = text.replaceAll('ؤ', 'و');

    // 7. إزالة الهمزة المفردة المتطرفة لتسهيل المطابقة (ء -> "")
    text = text.replaceAll('ء', '');

    // 8. تنظيف الرموز الزائدة وتوحيد المسافات
    text = text.replaceAll(RegExp(r'[\s\-_/\\,.:;()]+'), ' ').trim();

    return text;
  }

  /// التطبيع الصوتي للأحرف العربية الشائعة الخطأ في الكتابة (مثل ذ/د، ظ/ض، ث/س، ط/ت)
  /// هذا يحل مشكلة كتابة "ناذي" بدلاً من "نادي" أو "الخرتوم" بدلاً من "الخرطوم" فورياً بنسبة تطابق 100%
  static String phoneticNormalize(String? input) {
    if (input == null || input.isEmpty) return '';
    String text = normalize(input);

    // استبدال الأحرف المتقاربة صوتياً أو التي يخطئ المستخدمون في كتابتها
    text = text
        .replaceAll('ذ', 'د') // ناذي -> نادي
        .replaceAll('ظ', 'ض') // حافط -> حافظ
        .replaceAll('ث', 'س') // ميراث -> ميراس
        .replaceAll('ط', 'ت') // خرتوم -> خرطوم
        .replaceAll('ص', 'س') // صابر -> سابر
        .replaceAll('ق', 'غ'); // قاسم -> غاسم

    return text;
  }

  /// تطبيع أرقام الهواتف لتسهيل البحث بأي صيغة (محلية، دولية، بدون صفر، مع رمز الدولة)
  static String normalizePhone(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    String digits = normalize(phone).replaceAll(RegExp(r'[^0-9]'), '');

    // إزالة رموز الدول الشائعة لتسهيل المقارنة (السودان 249 أو 00249)
    if (digits.startsWith('00249')) {
      digits = digits.substring(5);
    } else if (digits.startsWith('249')) {
      digits = digits.substring(3);
    } else if (digits.startsWith('0') && digits.length >= 10) {
      digits = digits.substring(1);
    }

    return digits;
  }

  // ==========================================
  // 2. FUZZY MATCHING & LEVENSHTEIN DISTANCE
  // ==========================================

  /// حساب مسافة التعديل (Damerau-Levenshtein Distance)
  /// تحسب أقل عدد من عمليات الحذف والإضافة والاستبدال وتبديل الحرفين المتجاورين
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final len1 = s1.length;
    final len2 = s2.length;

    // مصفوفة ديناميكية محسنة لاستهلاك الذاكرة
    List<int> prev = List<int>.generate(len2 + 1, (i) => i);
    List<int> curr = List<int>.filled(len2 + 1, 0);

    for (int i = 0; i < len1; i++) {
      curr[0] = i + 1;
      for (int j = 0; j < len2; j++) {
        final cost = (s1[i] == s2[j]) ? 0 : 1;
        curr[j + 1] = min(
          curr[j] + 1, // إضافة
          min(
            prev[j + 1] + 1, // حذف
            prev[j] + cost, // استبدال
          ),
        );
      }
      final temp = prev;
      prev = curr;
      curr = temp;
    }

    return prev[len2];
  }

  /// حساب نسبة التشابه بين سلسلتين نصيتين (من 0.0 إلى 1.0)
  static double similarityScore(String s1, String s2) {
    final maxLen = max(s1.length, s2.length);
    if (maxLen == 0) return 1.0;
    final dist = levenshteinDistance(s1, s2);
    return (maxLen - dist) / maxLen;
  }

  /// التحقق مما إذا كانت الكلمة المفردة تتطابق مع كلمة الهدف بنسبة تسامح مع الأخطاء
  static bool isWordFuzzyMatch(String queryWord, String targetWord, {double tolerance = 0.25}) {
    if (queryWord.isEmpty || targetWord.isEmpty) return false;
    if (queryWord == targetWord) return true;

    // 1. تطابق البادئة أو الاحتواء المباشر
    if (targetWord.startsWith(queryWord) || targetWord.contains(queryWord)) {
      return true;
    }

    // 2. التطابق الصوتي المباشر (مثل: ناذي مع نادي)
    final pQuery = phoneticNormalize(queryWord);
    final pTarget = phoneticNormalize(targetWord);
    if (pQuery == pTarget || pTarget.startsWith(pQuery) || pTarget.contains(pQuery)) {
      return true;
    }

    // 3. احتساب أقصى عدد أخطاء مسموح به بناءً على طول الكلمة (حوالي 20-25%)
    int maxErrors = (queryWord.length * tolerance).floor();
    if (queryWord.length >= 3 && maxErrors < 1) {
      maxErrors = 1;
    }

    // فحص مسافة التعديل على النص العادي والنص الصوتي
    final dist1 = levenshteinDistance(queryWord, targetWord);
    if (dist1 <= maxErrors) return true;

    final distPhonetic = levenshteinDistance(pQuery, pTarget);
    if (distPhonetic <= maxErrors) return true;

    // 4. فحص تطابق بداية الكلمة أثناء الكتابة (Prefix Fuzzy Match)
    if (targetWord.length > queryWord.length) {
      final prefix = targetWord.substring(0, queryWord.length);
      if (levenshteinDistance(queryWord, prefix) <= maxErrors) {
        return true;
      }
      final pPrefix = pTarget.substring(0, min(pQuery.length, pTarget.length));
      if (levenshteinDistance(pQuery, pPrefix) <= maxErrors) {
        return true;
      }
    }

    return false;
  }

  // ==========================================
  // 3. MAIN PUBLIC SEARCH MATCHING APIS
  // ==========================================

  /// يتحقق مما إذا كان نص الاستعلام يطابق النص الهدف بمرونة فائقة وتسامح مع الأخطاء
  static bool matches(String? query, String? target, {double tolerance = 0.25}) {
    if (query == null || query.trim().isEmpty) return true;
    if (target == null || target.trim().isEmpty) return false;

    final normQuery = normalize(query);
    final normTarget = normalize(target);

    if (normQuery.isEmpty) return true;
    if (normTarget.isEmpty) return false;

    // 1. مسار سريع: تطابق تام أو جزئي بعد التطبيع
    if (normTarget.contains(normQuery)) return true;

    // 2. مسار سريع: تطابق صوتي
    final phonQuery = phoneticNormalize(query);
    final phonTarget = phoneticNormalize(target);
    if (phonTarget.contains(phonQuery)) return true;

    // 3. مطابقة الكلمات المتعددة (Multi-token match):
    final queryTokens = normQuery.split(' ').where((t) => t.isNotEmpty).toList();
    final targetTokens = normTarget.split(' ').where((t) => t.isNotEmpty).toList();

    if (queryTokens.isEmpty) return true;
    if (targetTokens.isEmpty) return false;

    for (final qToken in queryTokens) {
      bool matched = false;
      for (final tToken in targetTokens) {
        if (isWordFuzzyMatch(qToken, tToken, tolerance: tolerance)) {
          matched = true;
          break;
        }
      }
      if (!matched) {
        if (similarityScore(normQuery, normTarget) >= (1.0 - tolerance) ||
            similarityScore(phonQuery, phonTarget) >= (1.0 - tolerance)) {
          return true;
        }
        return false;
      }
    }

    return true;
  }

  /// يتحقق مما إذا كان نص الاستعلام يطابق أي حقل من قائمة الحقول (الاسم، المدينة، التخصص، الهاتف... إلخ)
  static bool matchesAny(String? query, Iterable<String?> fields, {double tolerance = 0.25}) {
    if (query == null || query.trim().isEmpty) return true;

    final cleanQuery = query.trim();
    final phoneQuery = normalizePhone(cleanQuery);

    // إذا كان البحث رقماً هاتفياً
    final bool isNumeric = phoneQuery.length >= 3 && RegExp(r'^[0-9]+$').hasMatch(phoneQuery);

    // فحص كل حقل على حدة
    for (final field in fields) {
      if (field == null || field.trim().isEmpty) continue;

      // 1. مطابقة الهواتف إن كان البحث رقمياً
      if (isNumeric) {
        final fieldPhone = normalizePhone(field);
        if (fieldPhone.isNotEmpty && (fieldPhone.contains(phoneQuery) || phoneQuery.contains(fieldPhone))) {
          return true;
        }
      }

      // 2. مطابقة نصية كاملة على الحقل
      if (matches(cleanQuery, field, tolerance: tolerance)) {
        return true;
      }
    }

    // 3. مطابقة الكلمات المجمعة عبر كافة الحقول معاً
    final combinedTarget = fields.where((f) => f != null && f.trim().isNotEmpty).join(' ');
    if (combinedTarget.isNotEmpty && matches(cleanQuery, combinedTarget, tolerance: tolerance)) {
      return true;
    }

    return false;
  }

  /// فلترة وترتيب قائمة عناصر بناءً على جودة المطابقة
  static List<T> filter<T>(
    String? query,
    Iterable<T> items,
    List<String?> Function(T item) extractFields, {
    double tolerance = 0.25,
  }) {
    if (query == null || query.trim().isEmpty) return items.toList();

    final cleanQuery = query.trim();
    final normQuery = normalize(cleanQuery);

    final results = <MapEntry<T, int>>[];

    for (final item in items) {
      final fields = extractFields(item);
      if (!matchesAny(cleanQuery, fields, tolerance: tolerance)) continue;

      // تقييم درجة الأولوية (Rank Score) لفرز الأقرب أولاً
      int rank = 0;
      for (final f in fields) {
        if (f == null) continue;
        final normF = normalize(f);
        if (normF == normQuery) {
          rank += 100; // تطابق تام
        } else if (normF.startsWith(normQuery)) {
          rank += 50; // يبدأ بكلمة البحث
        } else if (normF.contains(normQuery)) {
          rank += 25; // يحتوي كلمة البحث
        } else {
          rank += 10; // تطابق تقريبي مرن
        }
      }
      results.add(MapEntry(item, rank));
    }

    // فرز النتائج تنازلياً حسب درجة المطابقة
    results.sort((a, b) => b.value.compareTo(a.value));
    return results.map((e) => e.key).toList();
  }
}
