import 'package:flutter/material.dart';

/// لوحة الألوان المعتمدة في منصة محاميك
/// مستوحاة من الهيبة القانونية الكلاسيكية والفخامة الحديثة
class AppColors {
  // ==========================================
  // 1. PRIMARY & BRAND COLORS (الألوان الأساسية)
  // ==========================================
  
  /// الكحلي الملكي الداكن (اللون الأساسي للهوية واللوجو)
  static const Color navyDark = Color(0xFF0B2A5B);
  
  /// الكحلي المتوسط للبطاقات والخلفيات المتدرجة
  static const Color navyMedium = Color(0xFF103A7A);
  
  /// الكحلي الفاتح للحواف والعناصر التفاعلية
  static const Color navyLight = Color(0xFF194A93);

  /// الذهبي الملكي المعتمد في كلمة (محا) باللوجو
  static const Color gold = Color(0xFFD49B1A);
  
  /// الذهبي اللامع الفاتح للإضاءات
  static const Color goldLight = Color(0xFFFFD574);
  
  /// الذهبي الكهرماني الدافئ
  static const Color goldAmber = Color(0xFFE5A93C);
  
  /// الذهبي الداكن للنصوص والتأكيدات
  static const Color goldDark = Color(0xFFB87B08);

  // ==========================================
  // 2. ACCENT & STATE COLORS (ألوان الحالة والتفاعل)
  // ==========================================
  
  /// الأخضر الزمردي لحالات النجاح والواتساب
  static const Color emerald = Color(0xFF10B981);
  static const Color whatsappGreen = Color(0xFF25D366);
  static const Color whatsappDarkGreen = Color(0xFF16A34A);
  
  /// اللون الأحمر لحالات الخطأ والإلغاء
  static const Color error = Color(0xFFDC2626);
  
  /// الأزرق الفاتح للمعلومات والتنبيهات
  static const Color infoBlue = Color(0xFF3B82F6);

  // ==========================================
  // 3. NEUTRALS & BACKGROUNDS (الخلفيات والألوان المحايدة)
  // ==========================================
  
  /// الخلفية الرئيسية الفاتحة
  static const Color backgroundLight = Color(0xFFF8FAFC);
  
  /// الأبيض النقي للبطاقات
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  
  /// الرمادي الفاتح جداً للحواف والفواصل
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderCard = Color(0xFFEDE8DF);
  
  /// الرمادي الثانوي للنصوص الفرعية
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color textBody = Color(0xFF334155);

  // ==========================================
  // 4. GRADIENTS (التدرجات اللونية الفاخرة)
  // ==========================================
  
  /// تدرج الهوية الكحلية الفاخرة
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navyDark, navyMedium],
  );

  /// تدرج الإشعارات والبطاقات الذهبية المطابق للوجو
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD574), Color(0xFFD49B1A), Color(0xFFB87B08)],
  );
}
