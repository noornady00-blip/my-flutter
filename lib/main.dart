import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'network/network_service.dart';
import 'network/notification_service.dart';
import 'ui/screens/onboarding/onboarding_screen.dart';
import 'ui/custom_widgets/global_network_banner.dart';

// ============================================================================
// Mahameek Application Entry Point
// Professional, ultra-responsive initialization matching clean architecture.
// ============================================================================

void main() async {
  // 1. Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Error handling
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exception}');
  };

  // 2. Set preferred device orientations & modern system UI overlay on mobile
  if (!kIsWeb) {
    unawaited(SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]));

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
  }

  // 3. Initialize background network monitoring service
  unawaited(NetworkService().init().catchError((err) {
    debugPrint('NetworkService init error: $err');
  }));

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
  unawaited(NotificationService().init().catchError((notifErr) {
    debugPrint('NotificationService init notice: $notifErr');
  }));

  // 6. Launch Application with Onboarding Gateway immediately
  runApp(const MahameekApp(initialScreen: OnboardingScreen()));
}

class MahameekApp extends StatelessWidget {
  final Widget initialScreen;
  const MahameekApp({super.key, required this.initialScreen});

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
            child: GlobalNetworkBannerWrapper(
              child: child!,
            ),
          ),
        );
      },
      home: initialScreen,
    );
  }
}
