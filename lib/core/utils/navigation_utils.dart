import 'dart:async';
import 'package:flutter/material.dart';
import '../../network/auth_service.dart';
import '../../ui/screens/onboarding/onboarding_screen.dart';

/// Navigation utilities with 60/120fps smooth animations and zero UI lag
class NavigationUtils {
  /// Navigates to OnboardingScreen with a smooth slide-and-fade transition,
  /// executing backend sign-out in the background without freezing the UI.
  static void smoothSignOut(BuildContext context) {
    // 1. Immediately push the route with custom smooth slide animation
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(-1.0, 0.0), // Smooth slide from left (RTL natural exit)
              end: Offset.zero,
            ).animate(curve),
            child: FadeTransition(
              opacity: curve,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 300),
      ),
      (_) => false,
    );

    // 2. Perform backend sign-out asynchronously
    unawaited(AuthService().signOut());
  }

  /// General smooth slide transition for opening child screens
  static Future<T?> pushSmoothSlide<T>(BuildContext context, Widget screen) {
    return Navigator.push<T>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(1.0, 0.0),
              end: Offset.zero,
            ).animate(curve),
            child: FadeTransition(
              opacity: curve,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }
}
