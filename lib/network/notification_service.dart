// ==============================================================================
// 🔔 NOTIFICATION SERVICE & PUSH HANDLERS
// ==============================================================================
// Manages local notifications, FCM background messaging, admin alert routing,
// channel configuration, and in-app banner delivery.
// ==============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/models/admin_notification_model.dart';
import '../firebase_options.dart';
import 'fcm_dispatcher_service.dart';
import '../ui/screens/admin/admin_password_resets_screen.dart';
import '../ui/screens/admin/admin_support_messages_screen.dart';
import '../ui/screens/admin/admin_pending_lawyers_screen.dart';
import '../ui/custom_widgets/in_app_notification_banner.dart';
import '../core/services/keep_alive_service.dart';

/// Top-level background message handler for FCM (runs in independent Dart isolate)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform);

    // Verify device is registered as admin or message is from admin topic
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    final isAdminDevice = prefs.getBool('is_admin_device') ?? false;
    final isFromAdminTopic = message.from?.contains('admin') ?? false;

    if (role != 'admin' && !isAdminDevice && !isFromAdminTopic) {
      debugPrint('Background message ignored: device role is $role, not admin');
      return;
    }

    final notification = message.notification;
    final title = notification?.title ??
        message.data['title']?.toString() ??
        'إشعار إداري جديد 🔔';
    final body = notification?.body ??
        message.data['body']?.toString() ??
        'وصلك تحديث جديد في المنصة';
    final payload = message.data['type']?.toString() ??
        message.data['screen']?.toString() ??
        'admin_notification';

    debugPrint('FCM Background message handling: $title | Payload: $payload');

    // Self-contained Local Notifications in background isolate
    final localNotifications = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
    await localNotifications.initialize(initSettings);

    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final urgentChannelV4 = AndroidNotificationChannel(
        NotificationService.adminChannelId,
        NotificationService.adminChannelName,
        description: NotificationService.adminChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
        enableLights: true,
        ledColor: const Color(0xFFD49B1A),
        showBadge: true,
      );
      await androidPlugin.createNotificationChannel(urgentChannelV4);
    }

    final androidDetails = AndroidNotificationDetails(
      NotificationService.adminChannelId,
      NotificationService.adminChannelName,
      channelDescription: NotificationService.adminChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      showWhen: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
      playSound: true,
      color: const Color(0xFF0B2A5B),
      ledColor: const Color(0xFFD49B1A),
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      visibility: NotificationVisibility.public,
      category: AndroidNotificationCategory.message,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      ticker: title,
      channelShowBadge: true,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'منصة محاميك',
      ),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    final notifDetails =
        NotificationDetails(android: androidDetails, iOS: iosDetails);
    final notificationId = message.messageId.hashCode != 0
        ? (message.messageId.hashCode.abs() % 100000)
        : (DateTime.now().millisecondsSinceEpoch % 100000);

    // Only display if the system hasn't automatically displayed it from message.notification
    if (message.notification == null) {
      await localNotifications.show(
        notificationId,
        title,
        body,
        notifDetails,
        payload: payload,
      );
    }
  } catch (e) {
    debugPrint('Background message handler error: $e');
  }
}

/// Notification service orchestrating Push and In-App notifications.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  /// Global navigator key for notification click routing
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static const MethodChannel _settingsChannel =
      MethodChannel('com.mahameek.app/settings');

  static bool _initialLaunchPayloadHandled = false;
  static String? _lastHandledPayload;
  static DateTime? _lastHandledTime;

  // ---------------------------------------------------------------------------
  // Notification Channels & Topics
  // ---------------------------------------------------------------------------
  static const String adminChannelId = 'mahameek_urgent_alerts_v4';
  static const String adminChannelName = 'تنبيهات محاميك العاجلة والمنبثقة';
  static const String adminChannelDesc =
      'إشعارات فورية منبثقة لطلبات استعادة كلمة المرور ورسائل الدعم';
  static const String adminTopic = 'admin_notifications';
  static const String adminAlertsTopic = 'admin_alerts';

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  // ---------------------------------------------------------------------------
  // Intent & Settings Helpers
  // ---------------------------------------------------------------------------
  /// Clears launch intent to prevent re-opening on cold app restarts
  static Future<void> clearLaunchIntent() async {
    try {
      await _settingsChannel.invokeMethod('clearLaunchIntent');
    } catch (e) {
      debugPrint('clearLaunchIntent notice: $e');
    }
  }

  /// Opens system notification settings for floating/heads-up banner permissions
  static Future<void> openNotificationSettings({String? channelId}) async {
    try {
      await _settingsChannel.invokeMethod('openNotificationSettings', {
        'channelId': channelId ?? adminChannelId,
      });
    } catch (e) {
      debugPrint('openNotificationSettings error: $e');
    }
  }

  /// Handles user click on a notification payload (Admins only)
  static Future<void> handleNotificationTap(String? payload) async {
    if (payload == null || payload.trim().isEmpty) return;
    final type = payload.trim();

    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role');
    if (role != 'admin') {
      debugPrint('Ignoring notification tap: device role is $role, not admin');
      return;
    }

    final now = DateTime.now();
    if (_lastHandledPayload == type && _lastHandledTime != null) {
      if (now.difference(_lastHandledTime!).inMilliseconds < 2500) {
        debugPrint('Ignoring duplicate notification tap for payload: $type');
        return;
      }
    }
    _lastHandledPayload = type;
    _lastHandledTime = now;

    clearLaunchIntent();
    debugPrint('Notification clicked with payload: $type');

    Future.delayed(const Duration(milliseconds: 300), () {
      final nav = navigatorKey.currentState;
      if (nav == null) return;

      if (type == 'password_reset') {
        nav.push(
          MaterialPageRoute(
              builder: (_) => const AdminPasswordResetsScreen()),
        );
      } else if (type == 'support_message') {
        nav.push(
          MaterialPageRoute(
              builder: (_) => const AdminSupportMessagesScreen()),
        );
      } else if (type == 'lawyer_registration') {
        nav.push(
          MaterialPageRoute(
              builder: (_) => const AdminPendingLawyersScreen()),
        );
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------
  Future<void> init() async {
    if (_isInitialized) return;

    if (kIsWeb) {
      _isInitialized = true;
      try {
        final messaging = FirebaseMessaging.instance;
        await messaging.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Web notification init notice: $e');
      }
      return;
    }

    try {
      // 1. Configure Local Notifications
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const initSettings =
          InitializationSettings(android: androidInit, iOS: iosInit);
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          handleNotificationTap(response.payload);
        },
      );

      // 2. Check if notification launched the app
      if (!_initialLaunchPayloadHandled) {
        final launchDetails =
            await _localNotifications.getNotificationAppLaunchDetails();
        if (launchDetails?.didNotificationLaunchApp == true) {
          final payload = launchDetails?.notificationResponse?.payload;
          if (payload != null && payload.trim().isNotEmpty) {
            _initialLaunchPayloadHandled = true;
            handleNotificationTap(payload);
          }
        }
      }

      // 3. Create Android High-Priority Channels
      if (!kIsWeb) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          final urgentChannelV4 = AndroidNotificationChannel(
            adminChannelId,
            adminChannelName,
            description: adminChannelDesc,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
            enableLights: true,
            ledColor: const Color(0xFFD49B1A),
            showBadge: true,
          );

          final oldChannelUpdated = AndroidNotificationChannel(
            'mahameek_admin_alerts',
            'تنبيهات الإدارة والطلبات (عاجل)',
            description:
                'إشعارات فورية لطلبات استعادة كلمة المرور وانضمام المحامين والرسائل',
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
            enableLights: true,
            ledColor: const Color(0xFFD49B1A),
            showBadge: true,
          );

          await androidPlugin.createNotificationChannel(urgentChannelV4);
          await androidPlugin.createNotificationChannel(oldChannelUpdated);
          await androidPlugin.requestNotificationsPermission();
        }
      }

      // 4. Request permissions on FCM
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      // 5. Register Background Handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 6. Handle Foreground Messages (Admin Only)
      FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
        final prefs = await SharedPreferences.getInstance();
        final currentRole = prefs.getString('role');
        if (currentRole != 'admin') {
          debugPrint(
              'Foreground FCM message ignored: recipient is not admin (role: $currentRole)');
          return;
        }

        final notification = message.notification;
        final title =
            notification?.title ?? message.data['title'] ?? 'إشعار إداري';
        final body = notification?.body ?? message.data['body'] ?? '';
        final payload = message.data['type']?.toString();
        showNotificationDirect(
          title: title,
          body: body,
          payload: payload,
        );
      });

      // 7. Handle App Opened via Notification
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        final payload = message.data['type']?.toString();
        handleNotificationTap(payload);
      });

      // 8. Handle Cold Launch Initial Message
      if (!_initialLaunchPayloadHandled) {
        final initialMessage =
            await FirebaseMessaging.instance.getInitialMessage();
        if (initialMessage != null) {
          final payload = initialMessage.data['type']?.toString();
          if (payload != null && payload.trim().isNotEmpty) {
            _initialLaunchPayloadHandled = true;
            handleNotificationTap(payload);
          }
        }
      }

      // Cleanup subscription if not admin or auto-register if admin
      final prefs = await SharedPreferences.getInstance();
      final currentRole = prefs.getString('role');
      if (currentRole != 'admin') {
        unawaited(unregisterAdminDevice());
      } else {
        final savedUid = prefs.getString('uid') ?? FirebaseAuth.instance.currentUser?.uid;
        unawaited(registerAdminDevice(adminUid: savedUid));
      }

      // 9. Listen for FCM Token Refreshes (Auto-update for Admin)
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        try {
          final p = await SharedPreferences.getInstance();
          final r = p.getString('role');
          if (r == 'admin') {
            final uid = p.getString('uid') ?? FirebaseAuth.instance.currentUser?.uid;
            await _db.collection('admin_tokens').doc(newToken).set({
              'token': newToken,
              'adminUid': uid ?? 'admin',
              'platform': defaultTargetPlatform.name,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
            await FirebaseMessaging.instance.subscribeToTopic(adminTopic);
            await FirebaseMessaging.instance.subscribeToTopic(adminAlertsTopic);
            debugPrint('FCM Token refreshed and updated for admin: $newToken');
          }
        } catch (tokenErr) {
          debugPrint('FCM onTokenRefresh error: $tokenErr');
        }
      });

      _isInitialized = true;
      debugPrint(
          'NotificationService initialized successfully with Heads-up support.');
    } catch (e) {
      debugPrint('NotificationService init error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Admin Device Subscriptions
  // ---------------------------------------------------------------------------
  /// Subscribe admin device to alerts topic so notifications arrive even when app is closed
  Future<void> registerAdminDevice({String? adminUid}) async {
    if (kIsWeb) return;
    try {
      final messaging = FirebaseMessaging.instance;

      // 1. Request full push notification permissions with critical alert support
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        criticalAlert: true,
        provisional: false,
      );
      debugPrint('Admin notification permission status: ${settings.authorizationStatus}');

      // 2. For iOS devices, wait for APNs token before requesting FCM token
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        String? apnsToken = await messaging.getAPNSToken();
        int attempts = 0;
        while (apnsToken == null && attempts < 10) {
          await Future.delayed(const Duration(milliseconds: 500));
          apnsToken = await messaging.getAPNSToken();
          attempts++;
        }
        debugPrint('APNs Token state: ${apnsToken != null ? "obtained" : "pending"}');
      }

      // 3. Subscribe to admin notification topics
      await messaging
          .subscribeToTopic(adminTopic)
          .timeout(const Duration(seconds: 15))
          .catchError((subErr) {
        debugPrint('subscribeToTopic $adminTopic notice: $subErr');
      });

      await messaging
          .subscribeToTopic(adminAlertsTopic)
          .timeout(const Duration(seconds: 15))
          .catchError((subErr) {
        debugPrint('subscribeToTopic $adminAlertsTopic notice: $subErr');
      });

      // 4. Mark this device locally as an admin device
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_admin_device', true);
      final effectiveUid = adminUid ??
          prefs.getString('uid') ??
          FirebaseAuth.instance.currentUser?.uid ??
          'admin';

      // 5. Retrieve FCM device token and register in Firestore
      final token = await messaging.getToken().timeout(const Duration(seconds: 15)).catchError((tokenErr) {
        debugPrint('getToken timeout or error: $tokenErr');
        return null;
      });

      if (token != null) {
        final tokenData = {
          'token': token,
          'adminUid': effectiveUid,
          'platform': defaultTargetPlatform.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'device': 'admin_phone',
        };

        await _db.collection('admin_tokens').doc(token).set(tokenData, SetOptions(merge: true));
        if (effectiveUid.isNotEmpty) {
          await _db.collection('admin_fcm_tokens').doc(effectiveUid).set(tokenData, SetOptions(merge: true));
        }
      }

      // 6. Start real-time foreground listener for live admin notifications
      startAdminLiveAlertsListener();

      debugPrint('Admin registered successfully for $adminTopic | Token: ${token != null ? "OK" : "None"} (UID: $effectiveUid)');
    } catch (e) {
      debugPrint('registerAdminDevice error: $e');
    }
  }

  /// Request all notification permissions and register admin token
  Future<bool> enableAllNotifications({String? adminUid}) async {
    if (kIsWeb) return false;
    try {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: true,
        provisional: false,
        sound: true,
      );

      await registerAdminDevice(adminUid: adminUid);

      return settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
    } catch (e) {
      debugPrint('enableAllNotifications error: $e');
      return false;
    }
  }

  /// Unsubscribe device when admin logs out
  Future<void> unregisterAdminDevice() async {
    if (kIsWeb) return;
    try {
      stopAdminLiveAlertsListener();
      final messaging = FirebaseMessaging.instance;
      await messaging.unsubscribeFromTopic(adminTopic).catchError((_) {});
      await messaging.unsubscribeFromTopic(adminAlertsTopic).catchError((_) {});
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('is_admin_device');
      final token = await messaging.getToken().catchError((_) => null);
      if (token != null) {
        await _db.collection('admin_tokens').doc(token).delete().catchError((_) {});
      }
    } catch (e) {
      debugPrint('unregisterAdminDevice error: $e');
    }
  }

  static final Map<String, DateTime> _recentlyShownDirectNotifs = {};

  // ---------------------------------------------------------------------------
  // Direct Notification Display (Heads-Up Banner)
  // ---------------------------------------------------------------------------
  Future<void> showNotificationDirect({
    required String title,
    required String body,
    String? payload,
    int? id,
  }) async {
    try {
      final now = DateTime.now();
      _recentlyShownDirectNotifs.removeWhere((_, t) => now.difference(t).inSeconds > 10);
      final dedupeKey = '${id ?? ""}_${title.trim()}_${body.trim()}';
      if (_recentlyShownDirectNotifs.containsKey(dedupeKey)) {
        debugPrint('showNotificationDirect debounced duplicate: $title');
        return;
      }
      _recentlyShownDirectNotifs[dedupeKey] = now;

      final prefs = await SharedPreferences.getInstance();
      final currentRole = prefs.getString('role');
      final isAdminPayload = payload == 'password_reset' ||
          payload == 'support_message' ||
          payload == 'lawyer_registration' ||
          title.contains('استعادة') ||
          title.contains('كلمة المرور') ||
          title.contains('انضمام محام') ||
          title.contains('رسالة تواصل');

      if (isAdminPayload && currentRole != 'admin') {
        debugPrint(
            'showNotificationDirect blocked: recipient is not admin (role: $currentRole)');
        return;
      }
      final androidDetails = AndroidNotificationDetails(
        adminChannelId,
        adminChannelName,
        channelDescription: adminChannelDesc,
        importance: Importance.max,
        priority: Priority.max,
        showWhen: true,
        enableVibration: true,
        vibrationPattern: Int64List.fromList([0, 300, 200, 300]),
        playSound: true,
        color: const Color(0xFF0B2A5B),
        ledColor: const Color(0xFFD49B1A),
        ledOnMs: 1000,
        ledOffMs: 500,
        enableLights: true,
        visibility: NotificationVisibility.public,
        category: AndroidNotificationCategory.message,
        largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
        ticker: 'إشعار جديد من منصة محاميك',
        channelShowBadge: true,
        actions: <AndroidNotificationAction>[
          const AndroidNotificationAction(
            'open_action',
            'عرض الطلب',
            showsUserInterface: true,
            cancelNotification: true,
          ),
        ],
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: 'منصة محاميك',
          htmlFormatContent: true,
          htmlFormatTitle: true,
        ),
      );

      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        presentBanner: true,
        presentList: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notifDetails =
          NotificationDetails(android: androidDetails, iOS: iosDetails);
      final notificationId =
          id ?? (DateTime.now().millisecondsSinceEpoch % 100000);

      // 1. In-app heads up floating banner
      try {
        final navCtx = navigatorKey.currentContext;
        if (navCtx != null && navCtx.mounted) {
          InAppNotificationBanner.show(
            context: navCtx,
            title: title,
            body: body,
            payload: payload,
            onTap: () => handleNotificationTap(payload),
          );
        }
      } catch (bannerErr) {
        debugPrint('InAppNotificationBanner error: $bannerErr');
      }

      // 2. System status bar & lock-screen notification
      await _localNotifications.show(
        notificationId,
        title,
        body,
        notifDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('showNotificationDirect error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Admin Alerts Dispatch & Stream
  // ---------------------------------------------------------------------------
  Future<void> dispatchAdminAlert({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await FcmDispatcherService().dispatchAlert(
      type: type,
      title: title,
      body: body,
      data: data,
    );
  }

  // ---------------------------------------------------------------------------
  // Live Foreground Stream for Active Admin Session
  // ---------------------------------------------------------------------------
  StreamSubscription? _adminLiveAlertsSubscription;
  final Set<String> _seenAdminNotifIds = {};
  bool _isInitialLiveAlertsSnapshot = true;

  void startAdminLiveAlertsListener() {
    if (kIsWeb) return;
    _adminLiveAlertsSubscription?.cancel();
    _isInitialLiveAlertsSnapshot = true;

    // Enable 24/7 Admin Keep-Alive (Screen Wakelock + iOS Background Audio Session)
    unawaited(KeepAliveService().enableAdminKeepAlive());

    // Listen to the most recent admin notifications
    _adminLiveAlertsSubscription = _db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(25)
        .snapshots()
        .listen((snapshot) async {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      final isAdmin = role == 'admin' || prefs.getBool('is_admin_device') == true;
      if (!isAdmin) return;

      if (_isInitialLiveAlertsSnapshot) {
        _isInitialLiveAlertsSnapshot = false;
        // Populate existing IDs on launch so old notifications don't trigger alerts
        for (final doc in snapshot.docs) {
          _seenAdminNotifIds.add(doc.id);
        }
        return;
      }

      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final docId = change.doc.id;
          if (_seenAdminNotifIds.contains(docId)) continue;
          _seenAdminNotifIds.add(docId);

          final data = change.doc.data();
          if (data != null) {
            final title = data['title']?.toString() ?? 'إشعار إداري جديد 🔔';
            final body = data['body']?.toString() ?? '';
            final type = data['type']?.toString();
            showNotificationDirect(
              title: title,
              body: body,
              payload: type,
              id: docId.hashCode.abs() % 100000,
            );
          }
        }
      }
    }, onError: (err) {
      debugPrint('startAdminLiveAlertsListener notice: $err');
    });
  }

  void stopAdminLiveAlertsListener() {
    _adminLiveAlertsSubscription?.cancel();
    _adminLiveAlertsSubscription = null;
    _seenAdminNotifIds.clear();
    _isInitialLiveAlertsSnapshot = true;
    unawaited(KeepAliveService().disableAdminKeepAlive());
  }

  Stream<List<AdminNotificationModel>> getAdminNotificationsStream() {
    return _db
        .collection('admin_notifications')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => AdminNotificationModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db
          .collection('admin_notifications')
          .doc(notificationId)
          .update({'read': true});
    } catch (e) {
      debugPrint('markAsRead error: $e');
    }
  }

  Future<void> markMultipleAsRead(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final id in notificationIds) {
        final docRef = _db.collection('admin_notifications').doc(id);
        batch.update(docRef, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markMultipleAsRead error: $e');
    }
  }

  Future<void> markAllAsRead() async {
    try {
      final snap = await _db
          .collection('admin_notifications')
          .where('read', isEqualTo: false)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('markAllAsRead error: $e');
    }
  }

  Future<void> deleteNotification(String notificationId) async {
    try {
      await _db.collection('admin_notifications').doc(notificationId).delete();
    } catch (e) {
      debugPrint('deleteNotification error: $e');
    }
  }

  Future<void> deleteMultipleNotifications(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    try {
      final batch = _db.batch();
      for (final id in notificationIds) {
        final docRef = _db.collection('admin_notifications').doc(id);
        batch.delete(docRef);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('deleteMultipleNotifications error: $e');
    }
  }

  Future<void> deleteAllNotifications() async {
    try {
      final snap = await _db.collection('admin_notifications').get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (e) {
      debugPrint('deleteAllNotifications error: $e');
    }
  }

  /// Automatic read marker when opening a specific entity (ticket, lawyer, message) in its screen
  Future<void> markNotificationsReadForEntity({
    String? type,
    String? entityId,
    String? phone,
  }) async {
    try {
      Query query = _db.collection('admin_notifications').where('read', isEqualTo: false);
      if (type != null && type.isNotEmpty) {
        query = query.where('type', isEqualTo: type);
      }
      final snap = await query.get();
      if (snap.docs.isEmpty) return;

      final batch = _db.batch();
      bool hasUpdates = false;

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final subData = data['data'] as Map<String, dynamic>? ?? {};

        bool matches = false;
        if (entityId != null && entityId.isNotEmpty) {
          if (subData['ticketId'] == entityId ||
              subData['uid'] == entityId ||
              subData['lawyerId'] == entityId ||
              subData['msgId'] == entityId ||
              subData['id'] == entityId ||
              doc.id == entityId) {
            matches = true;
          }
        }
        if (phone != null && phone.isNotEmpty) {
          final p = subData['phone']?.toString();
          if (p != null && (p == phone || p.contains(phone) || phone.contains(p))) {
            matches = true;
          }
        }
        // If neither entityId nor phone provided, all unread of that type match
        if (entityId == null && phone == null) {
          matches = true;
        }

        if (matches) {
          batch.update(doc.reference, {'read': true});
          hasUpdates = true;
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('markNotificationsReadForEntity error: $e');
    }
  }
}
