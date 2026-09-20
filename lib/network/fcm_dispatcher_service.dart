// ==============================================================================
// 🚀 FCM DISPATCHER SERVICE
// ==============================================================================
// Clean architecture service for broadcasting administrative alerts to admin devices.
// Works seamlessly with Firestore admin notifications, local foreground alerts,
// and cloud push dispatch queues.
// ==============================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class FcmDispatcherService {
  static final FcmDispatcherService _instance = FcmDispatcherService._internal();
  factory FcmDispatcherService() => _instance;
  FcmDispatcherService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Dispatch an urgent administrative alert to all admin devices
  Future<void> dispatchAlert({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final payloadData = Map<String, dynamic>.from(data ?? {});
      payloadData['type'] = type;
      payloadData['timestamp'] = DateTime.now().toIso8601String();

      // 1. Record alert in Firestore collection for notification centers & history
      final alertRef = await _db.collection('admin_notifications').add({
        'type': type,
        'title': title,
        'body': body,
        'data': payloadData,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 2. Queue for Cloud Function / FCM Remote Push dispatcher
      try {
        await _db.collection('fcm_dispatch_queue').add({
          'notificationId': alertRef.id,
          'topic': NotificationService.adminTopic,
          'title': title,
          'body': body,
          'payload': payloadData,
          'channelId': NotificationService.adminChannelId,
          'priority': 'high',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      } catch (queueErr) {
        debugPrint('fcm_dispatch_queue notice: $queueErr');
      }

      // 3. If caller device happens to be an active admin, show instant local alert
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      final isAdmin = role == 'admin' || prefs.getBool('is_admin_device') == true;

      if (isAdmin) {
        unawaited(NotificationService().showNotificationDirect(
          title: title,
          body: body,
          payload: type,
          id: alertRef.id.hashCode.abs() % 100000,
        ));
      }

      debugPrint('Admin alert dispatched successfully: [$type] $title');
    } catch (e) {
      debugPrint('FcmDispatcherService.dispatchAlert error: $e');
    }
  }
}
