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
    {'name': 'باقي المدن', 'icon': '🗺️'},
  ];

  /// Returns a simple list of city names.
  static List<String> get names => cities.map((c) => c['name']!).toList();
}

/// Standard lawyer specialization categories.
class LawyerSpecializations {
  static const List<String> list = [
    'قانون جنائي',
    'قانون مدني',
    'شرعي وأحوال شخصية وتوثيق',
    'تجاري وشركات واستثمار',
    'عقارات وأراضي وتسجيلات',
    'عمالي وإداري ومظالم',
    'قانون دولي وحقوق إنسان',
    'ملكية فكرية وبراءات اختراع',
    'قضايا مصرفية ومالية',
    'استشارات عامة وقضايا متنوعة',
  ];

  static const List<String> filterList = [
    'الكل',
    'قانون جنائي',
    'قانون مدني',
    'شرعي وأحوال شخصية وتوثيق',
    'تجاري وشركات واستثمار',
    'عقارات وأراضي وتسجيلات',
    'عمالي وإداري ومظالم',
    'قانون دولي وحقوق إنسان',
    'ملكية فكرية وبراءات اختراع',
    'قضايا مصرفية ومالية',
    'استشارات عامة وقضايا متنوعة',
  ];

  /// Intelligent matching that supports exact matches, cleaned prefixes, and semantic keyword matching.
  static bool matches(String? lawyerSpec, String selectedFilter) {
    if (selectedFilter == 'الكل' || selectedFilter.trim().isEmpty) return true;
    if (lawyerSpec == null || lawyerSpec.trim().isEmpty) return false;

    final trimmedLawyer = lawyerSpec.trim();
    final trimmedFilter = selectedFilter.trim();
    if (trimmedLawyer == trimmedFilter) return true;

    // Remove common prefixes
    String clean(String s) => s
        .replaceAll('قانون ', '')
        .replaceAll('القانون ', '')
        .replaceAll('قضايا ', '')
        .trim();

    final cLawyer = clean(trimmedLawyer);
    final cFilter = clean(trimmedFilter);
    if (cLawyer == cFilter || cLawyer.contains(cFilter) || cFilter.contains(cLawyer)) {
      return true;
    }

    // Keyword matching for compound categories (e.g. شركات, عقارات, جنائي, مدني, شرعي, عمالي, مصرفية)
    final filterWords = cFilter
        .split(RegExp(r'[\s،و]+'))
        .where((w) => w.length >= 3 && w != 'عام' && w != 'عامة')
        .toList();

    for (final word in filterWords) {
      if (trimmedLawyer.contains(word)) return true;
    }

    return false;
  }
}

