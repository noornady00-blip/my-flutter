import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// السمة والمظهر العام لتطبيق محاميك (App Theme Configuration)
/// يوفر تنسيقات النصوص، الألوان، الحقول، والسمة الكاملة لمنظومة Material 3
class AppTheme {
  // ==========================================
  // 1. BRAND COLORS (مأخوذة من AppColors)
  // ==========================================
  
  static const Color navyDark = AppColors.navyDark;
  static const Color navyMedium = AppColors.navyMedium;
  static const Color navyLight = AppColors.navyLight;
  
  static const Color gold = AppColors.gold;
  static const Color goldLight = Color(0xFFE8C96A);
  static const Color goldDark = AppColors.goldDark;
  
  static const Color white = AppColors.surfaceWhite;
  static const Color offWhite = Color(0xFFF5F5F0);
  static const Color lightGrey = Color(0xFFF0F0F0);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF424242);
  
  static const Color success = AppColors.emerald;
  static const Color error = AppColors.error;
  static const Color warning = Color(0xFFF57F17);

  // ==========================================
  // 2. GRADIENTS (التدرجات اللونية)
  // ==========================================
  
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, navyMedium, navyLight],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDark],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0B2A5B), Color(0xFF103A7A), Color(0xFF194A93)],
  );

  // ==========================================
  // 3. TYPOGRAPHY & TEXT STYLES (تنسيقات النصوص)
  // ==========================================
  
  static TextStyle get headingLarge => GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: navyDark,
      );

  static TextStyle get headingMedium => GoogleFonts.cairo(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: navyDark,
      );

  static TextStyle get headingSmall => GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: navyDark,
      );

  static TextStyle get bodyLarge => GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: darkGrey,
      );

  static TextStyle get bodyMedium => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: darkGrey,
      );

  static TextStyle get bodySmall => GoogleFonts.cairo(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: grey,
      );

  static TextStyle get labelGold => GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: gold,
      );

  static TextStyle get buttonText => GoogleFonts.cairo(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: white,
      );

  // ==========================================
  // 4. DECORATIONS (الزخارف والحاويات)
  // ==========================================
  
  static BoxDecoration get glassCard => BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      );

  static BoxDecoration get whiteCard => BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: navyDark.withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      );

  /// زخرفة حقول الإدخال الموحدة
  static InputDecoration inputDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: grey, fontSize: 14),
        prefixIcon: Icon(icon, color: gold, size: 22),
        filled: true,
        fillColor: offWhite,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: lightGrey, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
      );

  // ==========================================
  // 5. MATERIAL 3 THEME DATA (السمة الشاملة للتطبيق)
  // ==========================================
  
  static ThemeData get themeData => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: navyDark,
          primary: navyDark,
          secondary: gold,
          surface: offWhite,
        ),
        scaffoldBackgroundColor: offWhite,
        textTheme: GoogleFonts.cairoTextTheme(),
        appBarTheme: AppBarTheme(
          backgroundColor: navyDark,
          foregroundColor: white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: GoogleFonts.cairo(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: navyDark,
            foregroundColor: white,
            minimumSize: const Size(double.infinity, 54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            textStyle: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
            elevation: 4,
            shadowColor: navyDark.withValues(alpha: 0.4),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: offWhite,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: LuxurySmoothPageTransitionsBuilder(),
            TargetPlatform.iOS: LuxurySmoothPageTransitionsBuilder(),
            TargetPlatform.windows: LuxurySmoothPageTransitionsBuilder(),
            TargetPlatform.macOS: LuxurySmoothPageTransitionsBuilder(),
            TargetPlatform.linux: LuxurySmoothPageTransitionsBuilder(),
            TargetPlatform.fuchsia: LuxurySmoothPageTransitionsBuilder(),
          },
        ),
      );
}

/// Custom Luxury Smooth Page Transition Builder
/// Combines calm soft horizontal slide, gentle subtle zoom (scale: 0.97 -> 1.0),
/// and soft fade with Emphasized Decelerate cubic curve for 60/120fps ultra-fluid transitions.
class LuxurySmoothPageTransitionsBuilder extends PageTransitionsBuilder {
  const LuxurySmoothPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Determine text direction for natural RTL / LTR directionality
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final beginOffset = isRTL ? const Offset(-0.06, 0.0) : const Offset(0.06, 0.0);

    // Primary Entering Animation Curve (Emphasized Decelerate)
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: const Cubic(0.16, 1.0, 0.3, 1.0),
      reverseCurve: Curves.easeInCubic,
    );

    // Secondary Exiting Animation Curve (when another page is pushed on top)
    final secondaryCurvedAnimation = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Slide Transition (Subtle, calm 6% displacement)
    final slideTransition = SlideTransition(
      position: Tween<Offset>(
        begin: beginOffset,
        end: Offset.zero,
      ).animate(curvedAnimation),
      child: child,
    );

    // Scale Transition (0.97 -> 1.0 entering)
    final scaleTransition = ScaleTransition(
      scale: Tween<double>(begin: 0.97, end: 1.0).animate(curvedAnimation),
      child: slideTransition,
    );

    // Fade Transition (0.0 -> 1.0 entering)
    final fadeTransition = FadeTransition(
      opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
      child: scaleTransition,
    );

    // Secondary Exit Layer: subtle slide backward and soft dim
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: isRTL ? const Offset(0.04, 0.0) : const Offset(-0.04, 0.0),
      ).animate(secondaryCurvedAnimation),
      child: FadeTransition(
        opacity: Tween<double>(begin: 1.0, end: 0.88).animate(secondaryCurvedAnimation),
        child: fadeTransition,
      ),
    );
  }
}
