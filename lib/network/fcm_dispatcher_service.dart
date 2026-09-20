// ==============================================================================
// 🚀 FCM DISPATCHER SERVICE (HTTP v1 DIRECT PUSH ENGINE)
// ==============================================================================
// Standalone, self-contained FCM HTTP v1 remote push dispatcher.
// Dispatches authentic, high-priority notifications to Android & iOS devices
// even when closed or locked, with zero Cloud Functions or Blaze billing needed.
// ==============================================================================

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/auth_io.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

class FcmDispatcherService {
  static final FcmDispatcherService _instance = FcmDispatcherService._internal();
  factory FcmDispatcherService() => _instance;
  FcmDispatcherService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _defaultProjectId = 'mahameek-47a1d';

  // In-memory caches
  Map<String, dynamic>? _cachedCredentials;
  String? _cachedAccessToken;
  DateTime? _tokenExpiry;

  /// Fetches Service Account credentials from Firestore `app_config/fcm_credentials`
  Future<Map<String, dynamic>?> _getCredentials() async {
    if (_cachedCredentials != null) return _cachedCredentials;
    try {
      final doc = await _db.collection('app_config').doc('fcm_credentials').get();
      if (doc.exists && doc.data() != null) {
        final raw = doc.data()!['credentialsJson'];
        if (raw is String) {
          _cachedCredentials = jsonDecode(raw) as Map<String, dynamic>;
        } else if (raw is Map<String, dynamic>) {
          _cachedCredentials = raw;
        }
        return _cachedCredentials;
      }
    } catch (e) {
      debugPrint('FcmDispatcherService._getCredentials error: $e');
    }
    return null;
  }

  /// Retrieves a valid OAuth2 Access Token for Firebase Cloud Messaging
  Future<String?> _getAccessToken() async {
    try {
      if (_cachedAccessToken != null &&
          _tokenExpiry != null &&
          DateTime.now().isBefore(_tokenExpiry!.subtract(const Duration(minutes: 5)))) {
        return _cachedAccessToken;
      }

      final creds = await _getCredentials();
      if (creds == null) {
        debugPrint('FcmDispatcherService: Service account credentials not found in Firestore.');
        return null;
      }

      final accountCredentials = ServiceAccountCredentials.fromJson(creds);
      final scopes = ['https://www.googleapis.com/auth/firebase.messaging'];
      final client = await clientViaServiceAccount(accountCredentials, scopes);

      _cachedAccessToken = client.credentials.accessToken.data;
      _tokenExpiry = client.credentials.accessToken.expiry;
      client.close();

      return _cachedAccessToken;
    } catch (e) {
      debugPrint('FcmDispatcherService._getAccessToken error: $e');
      return null;
    }
  }

  /// Dispatches an urgent administrative alert to all admin devices across platforms
  Future<void> dispatchAlert({
    required String type,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      final stringPayload = <String, String>{
        'type': type,
        'title': title,
        'body': body,
        'timestamp': DateTime.now().toIso8601String(),
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      };

      if (data != null) {
        for (final entry in data.entries) {
          if (entry.value != null) {
            stringPayload[entry.key] = entry.value.toString();
          }
        }
      }

      // 1. Record alert in Firestore collection for in-app history & badges
      final alertRef = await _db.collection('admin_notifications').add({
        'type': type,
        'title': title,
        'body': body,
        'data': stringPayload,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 2. If caller device happens to be an active admin, show instant local alert
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

      // 3. Dispatch Remote Push Notification via FCM HTTP v1 in background
      unawaited(_sendFcmHttpV1Message(
        title: title,
        body: body,
        data: stringPayload,
      ));

      debugPrint('Admin alert successfully recorded and queued: [$type] $title');
    } catch (e) {
      debugPrint('FcmDispatcherService.dispatchAlert error: $e');
    }
  }

  /// Sends the FCM HTTP v1 request to the admin topic and active admin tokens
  Future<void> _sendFcmHttpV1Message({
    required String title,
    required String body,
    required Map<String, String> data,
  }) async {
    try {
      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('FCM Dispatch warning: Could not obtain OAuth2 token.');
        return;
      }

      final creds = await _getCredentials();
      final projectId = creds?['project_id'] ?? _defaultProjectId;
      final endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json; UTF-8',
      };

      // Payload targeted to the admin_notifications topic (subscribed by all admin devices)
      final topicPayload = {
        'message': {
          'topic': NotificationService.adminTopic,
          'notification': {
            'title': title,
            'body': body,
          },
          'data': data,
          'android': {
            'priority': 'HIGH',
            'notification': {
              'channel_id': NotificationService.adminChannelId,
              'sound': 'default',
              'priority': 'MAX',
              'visibility': 'PUBLIC',
              'default_sound': true,
              'default_vibrate_timings': true,
            },
          },
          'apns': {
            'headers': {
              'apns-priority': '10',
              'apns-push-type': 'alert',
            },
            'payload': {
              'aps': {
                'alert': {
                  'title': title,
                  'body': body,
                },
                'sound': 'default',
                'badge': 1,
                'content-available': 1,
              },
            },
          },
        },
      };

      final response = await http
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: jsonEncode(topicPayload),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('FCM HTTP v1 Topic Push sent successfully: ${response.body}');
      } else {
        debugPrint('FCM HTTP v1 Topic Push returned status ${response.statusCode}: ${response.body}');
      }

      // Also dispatch directly to individual tokens in admin_tokens as a fail-safe
      final tokensSnap = await _db.collection('admin_tokens').limit(15).get();
      for (final doc in tokensSnap.docs) {
        final token = doc.data()['token']?.toString();
        if (token != null && token.isNotEmpty) {
          final directPayload = {
            'message': {
              'token': token,
              'notification': {
                'title': title,
                'body': body,
              },
              'data': data,
              'android': {
                'priority': 'HIGH',
                'notification': {
                  'channel_id': NotificationService.adminChannelId,
                  'sound': 'default',
                  'priority': 'MAX',
                  'visibility': 'PUBLIC',
                },
              },
              'apns': {
                'headers': {
                  'apns-priority': '10',
                  'apns-push-type': 'alert',
                },
                'payload': {
                  'aps': {
                    'alert': {
                      'title': title,
                      'body': body,
                    },
                    'sound': 'default',
                    'badge': 1,
                    'content-available': 1,
                  },
                },
              },
            },
          };

          unawaited(http
              .post(
                Uri.parse(endpoint),
                headers: headers,
                body: jsonEncode(directPayload),
              )
              .timeout(const Duration(seconds: 8))
              .catchError((_) => http.Response('', 500)));
        }
      }
    } catch (e) {
      debugPrint('FcmDispatcherService._sendFcmHttpV1Message error: $e');
    }
  }
}
