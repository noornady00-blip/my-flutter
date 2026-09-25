// ==============================================================================
// 🔋 24/7 KEEP-ALIVE SERVICE (AWAKE ENGINE)
// ==============================================================================
// Ensures devices (Admin, Lawyer, Client) stay connected to real-time events:
// 1. Prevents screen from sleeping while interacting with vital screens (Wakelock).
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
  String _activeRole = 'client';
  String get activeRole => _activeRole;

  /// Activates 24/7 Keep-Alive mode for Admin, Lawyer, or Client:
  /// - Keeps screen awake while dashboard / active screen is open.
  /// - Runs silent background keep-alive on iOS to preserve Firestore listener when locked.
  Future<void> enableKeepAlive({String role = 'client'}) async {
    _activeRole = role;
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

      debugPrint('KeepAliveService: 24/7 Keep-Alive ($role) successfully enabled.');
    } catch (e) {
      debugPrint('KeepAliveService.enableKeepAlive error: $e');
    }
  }

  /// Backward compatible alias for admin keep-alive
  Future<void> enableAdminKeepAlive() => enableKeepAlive(role: 'admin');

  /// Disables Keep-Alive mode on logout
  Future<void> disableKeepAlive() async {
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

      debugPrint('KeepAliveService: Keep-Alive disabled.');
    } catch (e) {
      debugPrint('KeepAliveService.disableKeepAlive error: $e');
    }
  }

  /// Backward compatible alias for admin disable
  Future<void> disableAdminKeepAlive() => disableKeepAlive();
}
