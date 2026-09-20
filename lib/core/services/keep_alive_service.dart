// ==============================================================================
// 🔋 ADMIN KEEP-ALIVE SERVICE (24/7 AWAKE ENGINE)
// ==============================================================================
// Ensures the admin device stays awake and connected to real-time events:
// 1. Prevents screen from dimming/sleeping while on dashboard (Wakelock).
// 2. Activates silent background execution on iOS so Firestore real-time listeners
//    and notifications trigger immediately even when screen is locked.
// ==============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class KeepAliveService {
  static final KeepAliveService _instance = KeepAliveService._internal();
  factory KeepAliveService() => _instance;
  KeepAliveService._internal();

  static const MethodChannel _iosKeepAliveChannel =
      MethodChannel('com.mahameek.app/admin_keep_alive');

  bool _isActive = false;
  bool get isActive => _isActive;

  /// Activates 24/7 Keep-Alive mode for Admin:
  /// - Keeps screen awake while dashboard is open.
  /// - Runs silent background keep-alive on iOS to preserve Firestore listener when locked.
  Future<void> enableAdminKeepAlive() async {
    if (_isActive) return;
    try {
      _isActive = true;

      // 1. Keep Screen Awake in foreground
      if (!kIsWeb) {
        try {
          await WakelockPlus.enable();
        } catch (wErr) {
          debugPrint('WakelockPlus.enable note: $wErr');
        }
      }

      // 2. iOS Silent Background Keep-Alive
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await _iosKeepAliveChannel.invokeMethod('enableKeepAlive');
        } catch (iosErr) {
          debugPrint('iOS enableKeepAlive note: $iosErr');
        }
      }

      debugPrint('KeepAliveService: Admin 24/7 Keep-Alive successfully enabled.');
    } catch (e) {
      debugPrint('KeepAliveService.enableAdminKeepAlive error: $e');
    }
  }

  /// Disables Keep-Alive mode on logout
  Future<void> disableAdminKeepAlive() async {
    if (!_isActive) return;
    try {
      _isActive = false;

      if (!kIsWeb) {
        try {
          await WakelockPlus.disable();
        } catch (_) {}
      }

      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        try {
          await _iosKeepAliveChannel.invokeMethod('disableKeepAlive');
        } catch (_) {}
      }

      debugPrint('KeepAliveService: Admin Keep-Alive disabled.');
    } catch (e) {
      debugPrint('KeepAliveService.disableAdminKeepAlive error: $e');
    }
  }
}
