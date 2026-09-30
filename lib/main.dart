import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'network/network_service.dart';
import 'network/notification_service.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/screens/admin/admin_dashboard.dart';
import 'ui/screens/main_navigation_screen.dart';
import 'ui/screens/auth/lawyer_pending_screen.dart';
import 'ui/screens/auth/admin_login_screen.dart';
import 'ui/custom_widgets/global_network_banner.dart';
import 'network/firestore_service.dart';

import 'package:intl/date_symbol_data_local.dart';

// ============================================================================
// Mahameek Application Entry Point
// Professional, ultra-responsive initialization matching clean architecture.
// ============================================================================

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Arabic locale date formatting
  try {
    await initializeDateFormatting('ar', null);
  } catch (e) {
    debugPrint('initializeDateFormatting notice: $e');
  }

  // Error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  // 2. Set preferred device orientations & modern system UI overlay on mobile
  if (!kIsWeb) {
    unawaited(
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]),
    );

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );
  }

  // 3. Initialize background network monitoring service
  unawaited(
    NetworkService().init().catchError((err) {
      debugPrint('NetworkService init error: $err');
    }),
  );

  // 4. Initialize Firebase Core & Firestore offline persistence
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 4));
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (firebaseErr) {
    debugPrint('Firebase init notice: $firebaseErr');
  }

  // 5. Initialize Notification channels & listeners in background (never blocks UI)
  unawaited(
    NotificationService().init().catchError((notifErr) {
      debugPrint('NotificationService init notice: $notifErr');
    }),
  );

  // 6. Resolve Initial Screen dynamically from local session
  Widget initialScreen = const OnboardingScreen();

  try {
    final prefs = await SharedPreferences.getInstance();
    final savedRole = prefs.getString('role');
    final savedUid = prefs.getString('uid');
    final savedStatus = prefs.getString('status');
    final savedName = prefs.getString('name');

    // Safely attempt to get Firebase user without breaking local SharedPreferences logic
    User? currentUser;
    try {
      currentUser = FirebaseAuth.instance.currentUser;
    } catch (_) {}

    // Determine effective role
    String? effectiveRole = (savedRole != null && savedRole.trim().isNotEmpty)
        ? savedRole.trim()
        : null;
    if (effectiveRole == null && currentUser?.email != null) {
      final email = currentUser!.email!.toLowerCase();
      if (email.contains('@mahameek.admin.com') || email.startsWith('admin_')) {
        effectiveRole = 'admin';
      } else if (email.contains('@mahameek.lawyer.com')) {
        effectiveRole = 'lawyer';
      } else if (email.contains('@mahameek.client.com')) {
        effectiveRole = 'client';
      }
    }

    // Robust Session Persistence: User is only logged in if BOTH local session and Firebase Auth exist
    final bool hasLocalSession = savedUid != null && savedUid.trim().isNotEmpty;
    final bool hasFirebaseUser = currentUser != null;
    final bool isLoggedIn = hasLocalSession && hasFirebaseUser;

    if (hasFirebaseUser && !hasLocalSession) {
      // User signed out locally -> clean up orphaned Firebase Auth session
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}
    }

    if (isLoggedIn) {
      final String role = effectiveRole ?? 'client';
      final currentUid = savedUid;
      unawaited(
        NotificationService().registerUserDevice(uid: currentUid, role: role),
      );
      if (role == 'admin' || role.toLowerCase() == 'subadmin') {
        initialScreen = const AdminDashboard();
        try {
          unawaited(
            NotificationService().enableAllNotifications(adminUid: currentUid),
          );
          unawaited(FirestoreService().ensurePrimaryAdminsSeeded());
        } catch (_) {}
      } else if (role == 'lawyer') {
        if (savedStatus == 'pending') {
          initialScreen = LawyerPendingScreen(lawyerName: savedName);
        } else {
          initialScreen = const MainNavigationScreen(role: 'lawyer');
        }
      } else {
        initialScreen = const MainNavigationScreen(role: 'client');
      }
    } else {
      initialScreen = const OnboardingScreen();
    }
  } catch (sessionErr) {
    debugPrint('Session resolution notice: $sessionErr');
    initialScreen = const OnboardingScreen();
  }

  // 7. Launch Application with resolved initial screen
  runApp(MahameekApp(initialScreen: initialScreen));
}

class MahameekApp extends StatefulWidget {
  final Widget initialScreen;
  const MahameekApp({super.key, required this.initialScreen});

  @override
  State<MahameekApp> createState() => _MahameekAppState();
}

class _MahameekAppState extends State<MahameekApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Dismiss all system notifications on cold launch / app entry
    NotificationService().clearAllSystemNotifications();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Dismiss all system notifications when app returns to foreground
      NotificationService().clearAllSystemNotifications();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'محاميك',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      locale: const Locale('ar', 'SD'),
      // Global RTL wrapper with dynamic text scaling and real-time connectivity banner
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: mediaQuery.copyWith(
              textScaler: mediaQuery.textScaler.clamp(
                minScaleFactor: 0.85,
                maxScaleFactor: 1.35,
              ),
            ),
            child: GlobalNetworkBannerWrapper(child: child!),
          ),
        );
      },
      home: widget.initialScreen,
      routes: {
        '/admin-portal': (context) => const AdminLoginScreen(),
      },
    );
  }
}
