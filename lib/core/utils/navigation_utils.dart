import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../network/firestore_service.dart';
import '../../network/notification_service.dart';
import '../../ui/screens/auth/auth_gateway_screen.dart';

/// Navigation utilities with 60/120fps smooth animations and zero UI lag
class NavigationUtils {
  /// Signs out cleanly: purges local SharedPreferences, resets Firebase Auth,
  /// clears cache, and smoothly transitions to AuthGatewayScreen.
  static Future<void> smoothSignOut(BuildContext context) async {
    // 1. Navigate cleanly to AuthGatewayScreen immediately so previous screens are unmounted immediately
    final nav = NotificationService.navigatorKey.currentState;
    final gatewayRoute = PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => const AuthGatewayScreen(),
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
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 260),
    );

    if (nav != null) {
      nav.pushAndRemoveUntil(gatewayRoute, (_) => false);
    } else if (context.mounted) {
      Navigator.pushAndRemoveUntil(context, gatewayRoute, (_) => false);
    }

    // 2. Immediately wipe SharedPreferences so old session cannot be read
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('[smoothSignOut] SharedPreferences clear notice: $e');
    }

    // 3. Clear memory cache
    FirestoreService.inMemoryApprovedLawyers = null;

    // 4. Complete Firebase Auth sign out
    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {
      debugPrint('[smoothSignOut] FirebaseAuth signOut notice: $e');
    }

    // 5. Background cleanup for push notifications
    unawaited(NotificationService().clearAllSystemNotifications().catchError((_) {}));
    unawaited(NotificationService().unregisterAdminDevice().catchError((_) {}));
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
