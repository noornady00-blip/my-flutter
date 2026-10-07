import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../network/firestore_service.dart';
import '../../network/notification_service.dart';
import '../../ui/screens/auth/auth_gateway_screen.dart';

/// Navigation utilities with 60/120fps smooth animations and zero UI lag
class NavigationUtils {
  /// Signs out cleanly: displays a smooth loading indicator, stops live listeners,
  /// purges notification tokens with tight timeouts, resets Firebase Auth,
  /// clears cache and SharedPreferences, and smoothly transitions to AuthGatewayScreen.
  static Future<void> smoothSignOut(BuildContext context) async {
    // 0. Immediately show a clean, lightweight loading indicator
    final BuildContext? targetContext = context.mounted
        ? context
        : NotificationService.navigatorKey.currentContext;

    if (targetContext != null) {
      try {
        showDialog(
          context: targetContext,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.5),
          builder: (ctx) => PopScope(
            canPop: false,
            child: Center(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 40),
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        strokeWidth: 3.5,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD49B1A)), // Mahameek Gold
                        backgroundColor: Color(0xFFF1F5F9),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'تسجيل الخروج...',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B), // Mahameek Navy
                        decoration: TextDecoration.none,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'جارٍ إنهاء الجلسة وحفظ البيانات',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } catch (e) {
        debugPrint('[smoothSignOut] showDialog error: $e');
      }
    }

    final stopwatch = Stopwatch()..start();

    // 1. Capture user credentials before clearing session
    String? currentUid;
    String? currentRole;
    try {
      final prefs = await SharedPreferences.getInstance();
      currentUid = prefs.getString('uid') ?? FirebaseAuth.instance.currentUser?.uid;
      currentRole = prefs.getString('role');
    } catch (_) {}

    // 2. Immediately stop live chat listener and unregister push notification tokens with strict timeouts
    NotificationService().stopGlobalUserChatListener();
    try {
      await NotificationService()
          .unregisterUserDevice(uid: currentUid)
          .timeout(const Duration(seconds: 3));
      if (currentRole == 'admin') {
        await NotificationService()
            .unregisterAdminDevice()
            .timeout(const Duration(seconds: 2));
      }
      await NotificationService().clearAllSystemNotifications();
    } catch (e) {
      debugPrint('[smoothSignOut] notification cleanup error: $e');
    }

    // 3. Immediately wipe SharedPreferences so old session cannot be read anywhere
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('[smoothSignOut] SharedPreferences clear notice: $e');
    }

    // 4. Clear in-memory caches
    FirestoreService.inMemoryApprovedLawyers = null;

    // 5. Complete Firebase Auth sign out with timeout
    try {
      await FirebaseAuth.instance.signOut().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('[smoothSignOut] FirebaseAuth signOut notice: $e');
    }

    // Ensure loader was visible for at least 450ms for smooth visual continuity
    final elapsed = stopwatch.elapsedMilliseconds;
    if (elapsed < 450) {
      await Future.delayed(Duration(milliseconds: 450 - elapsed));
    }

    // 6. Navigate cleanly to AuthGatewayScreen immediately (removes loading dialog and all previous routes)
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
