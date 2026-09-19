// ==============================================================================
// 🏛️ SUDAN CITIES & SPECIALIZATIONS DATA MODEL
// ==============================================================================
// Provides standard lists of Sudanese administrative cities and legal specializations
// used throughout the Mahameek application.
// ==============================================================================

/// Represents Sudanese cities available in the application.
class SudanCities {
  static const List<Map<String, String>> cities = [
    {'name': 'الخرطوم', 'icon': '🏛️'},
    {'name': 'أم درمان', 'icon': '🕌'},
    {'name': 'بحري', 'icon': '🌊'},
    {'name': 'بورتسودان', 'icon': '⚓'},
    {'name': 'كسلا', 'icon': '🏔️'},
    {'name': 'عطبرة', 'icon': '🚂'},
    {'name': 'ود مدني', 'icon': '🌴'},
    {'name': 'الأبيض', 'icon': '🌾'},
    {'name': 'الفاشر', 'icon': '🏜️'},
    {'name': 'نيالا', 'icon': '🌿'},
    {'name': 'دنقلا', 'icon': '🏺'},
  ];

  /// Returns a simple list of city names.
  static List<String> get names => cities.map((c) => c['name']!).toList();
}

/// Standard lawyer specialization categories.
class LawyerSpecializations {
  static const List<String> list = [
    'محامي عام',
    'قانون الأسرة والأحوال الشخصية',
    'القانون التجاري والشركات',
    'قانون العقارات والعقود',
    'القانون الجنائي',
    'قانون العمل والتأمينات',
    'القانون الدولي',
    'قانون الملكية الفكرية',
    'القانون الإداري',
    'قانون المصارف والتمويل',
    'قانون الميراث والوصايا',
    'قانون حقوق الإنسان',
  ];
}
