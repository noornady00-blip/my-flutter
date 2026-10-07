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

import 'notification_service.dart';

class FcmDispatcherService {
  static final FcmDispatcherService _instance = FcmDispatcherService._internal();
  factory FcmDispatcherService() => _instance;
  FcmDispatcherService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  static const String _defaultProjectId = 'mahameek-30c70';

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
      debugPrint('FcmDispatcherService._getCredentials notice: $e');
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
      await _db.collection('admin_notifications').add({
        'type': type,
        'title': title,
        'body': body,
        'data': stringPayload,
        'createdAt': FieldValue.serverTimestamp(),
        'read': false,
      });

      // 2. Dispatch exactly ONE remote Push Notification via FCM HTTP v1 Topic in background
      unawaited(_sendFcmHttpV1Message(
        title: title,
        body: body,
        data: stringPayload,
      ));

      debugPrint('Admin alert successfully recorded and dispatched: [$type] $title');
    } catch (e) {
      debugPrint('FcmDispatcherService.dispatchAlert error: $e');
    }
  }

  /// Sends the FCM HTTP v1 request to the admin topic
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
        'Content-Type': 'application/json; charset=utf-8',
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
              'notification_priority': 'PRIORITY_MAX',
              'visibility': 'PUBLIC',
              'icon': 'ic_stat_mahameek',
              'color': '#0B2A5B',
              'default_sound': true,
              'default_vibrate_timings': true,
              'tag': 'admin_${data['type'] ?? 'alert'}',
            },
          },
          'apns': {
            'headers': {
              'apns-priority': '10',
              'apns-push-type': 'alert',
              'apns-collapse-id': 'admin_${data['type'] ?? 'alert'}',
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
                'category': 'FLUTTER_NOTIFICATION_CLICK',
                'mutable-content': 1,
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
        return; // Success: Admin topic broadcast delivered. Do NOT send to admin_tokens to avoid duplicate notifications.
      } else {
        debugPrint('FCM HTTP v1 Topic Push returned status ${response.statusCode}: ${response.body}');
      }

      // Fallback: only if topic broadcast failed, deliver to individual admin device tokens
      try {
        final adminTokensSnap = await _db.collection('admin_tokens').get();
        if (adminTokensSnap.docs.isNotEmpty) {
          for (final doc in adminTokensSnap.docs) {
            final adminToken = doc.id;
            if (adminToken.isNotEmpty) {
              final directPayload = {
                'message': {
                  'token': adminToken,
                  'notification': {
                    'title': title,
                    'body': body,
                  },
                  'data': data,
                  'android': (topicPayload['message'] as Map)['android'],
                  'apns': (topicPayload['message'] as Map)['apns'],
                },
              };
              try {
                await http.post(
                  Uri.parse(endpoint),
                  headers: headers,
                  body: jsonEncode(directPayload),
                ).timeout(const Duration(seconds: 8));
              } catch (_) {}
            }
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('FcmDispatcherService._sendFcmHttpV1Message error: $e');
    }
  }

  /// Dispatches an authentic push notification for chat messages to the recipient device (works when closed)
  Future<void> dispatchChatNotification({
    required String recipientId,
    required String senderId,
    required String senderName,
    required String messageText,
    required String chatId,
    String? senderRole,
    String? senderAccountId,
  }) async {
    final cleanRecipient = recipientId.trim();
    final cleanSender = senderId.trim();
    if (cleanRecipient.isEmpty || (cleanSender.isNotEmpty && cleanRecipient == cleanSender)) {
      debugPrint('[FcmDispatcher] Aborted chat push: cleanRecipient is empty or equals sender ($cleanRecipient == $cleanSender)');
      return;
    }

    try {
      final isFromAdmin = senderRole == 'admin';
      final pushTitle = isFromAdmin ? 'مشرف: $senderName' : senderName;

      // ====================================================================
      // 🛑 STOP GUARD: Verify recipient has NOT stopped this chat.
      // This is a second-layer check — even if chat_service already checked,
      // we re-verify here to guarantee zero notifications reach a stopped user.
      // ====================================================================
      try {
        final chatDoc = await _db.collection('chats').doc(chatId).get();
        if (chatDoc.exists && chatDoc.data() != null) {
          final rawStopped = chatDoc.data()!['stoppedBy'];
          final isStoppedByRecipient = rawStopped is List &&
              rawStopped.map((e) => e.toString()).contains(cleanRecipient);
          if (isStoppedByRecipient) {
            debugPrint('[FcmDispatcher] ⛔ Aborting push: recipient $cleanRecipient has stopped chat $chatId');
            return;
          }
        }
      } catch (stopCheckErr) {
        // If Firestore check fails, abort the notification to be safe
        debugPrint('[FcmDispatcher] ⚠️ stoppedBy check failed ($stopCheckErr) — aborting push for safety');
        return;
      }


      final stringPayload = <String, String>{
        'type': 'chat_message',
        'chatId': chatId,
        'senderId': cleanSender,
        'senderName': senderName,
        'senderRole': senderRole ?? '',
        'senderAccountId': senderAccountId ?? '',
        'body': messageText,
        'title': pushTitle,
        'screen': 'chat',
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'timestamp': DateTime.now().toIso8601String(),
      };

      final accessToken = await _getAccessToken();
      if (accessToken == null) {
        debugPrint('[FcmDispatcher] Warning: Could not obtain OAuth2 token for chat push.');
        return;
      }

      final creds = await _getCredentials();
      final projectId = creds?['project_id'] ?? _defaultProjectId;
      final endpoint = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';

      final headers = {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json; charset=utf-8',
      };

      // Payload targeted to user personal topic (user_{uid})
      final androidConfig = {
        'priority': 'HIGH',
        'notification': {
          'channel_id': NotificationService.chatChannelId,
          'sound': 'default',
          'notification_priority': 'PRIORITY_MAX',
          'visibility': 'PUBLIC',
          'icon': 'ic_stat_mahameek',
          'color': '#0B2A5B',
          'default_sound': true,
          'default_vibrate_timings': true,
          'tag': 'chat_$chatId',
        },
      };

      final apnsConfig = {
        'headers': {
          'apns-priority': '10',
          'apns-push-type': 'alert',
          'apns-collapse-id': 'chat_$chatId',
        },
        'payload': {
          'aps': {
            'alert': {
              'title': pushTitle,
              'body': messageText,
            },
            'sound': 'default',
            'badge': 1,
            'content-available': 1,
            'category': 'FLUTTER_NOTIFICATION_CLICK',
            'mutable-content': 1,
          },
        },
      };

      // 1. Look up primary registered device token for recipient
      String? primaryToken;
      try {
        final tokenDoc = await _db.collection('user_tokens').doc(cleanRecipient).get();
        if (tokenDoc.exists) {
          final t = tokenDoc.data()?['token']?.toString();
          if (t != null && t.trim().isNotEmpty) primaryToken = t.trim();
        }
      } catch (_) {}

      if (primaryToken == null || primaryToken.isEmpty) {
        try {
          final userDoc = await _db.collection('users').doc(cleanRecipient).get();
          final t = userDoc.data()?['fcmToken']?.toString();
          if (t != null && t.trim().isNotEmpty) primaryToken = t.trim();
        } catch (_) {}
      }

      if (primaryToken == null || primaryToken.isEmpty) {
        try {
          final lawyerDoc = await _db.collection('lawyers').doc(cleanRecipient).get();
          final t = lawyerDoc.data()?['fcmToken']?.toString();
          if (t != null && t.trim().isNotEmpty) primaryToken = t.trim();
        } catch (_) {}
      }

      bool directSuccess = false;

      // 2. Direct Token Delivery: Send directly to recipient device token (fastest, unicast, never duplicates)
      if (primaryToken != null && primaryToken.isNotEmpty) {
        final directPayload = {
          'message': {
            'token': primaryToken,
            'notification': {
              'title': pushTitle,
              'body': messageText,
            },
            'data': stringPayload,
            'android': androidConfig,
            'apns': apnsConfig,
          },
        };

        try {
          final directRes = await http
              .post(
                Uri.parse(endpoint),
                headers: headers,
                body: jsonEncode(directPayload),
              )
              .timeout(const Duration(seconds: 8));

          if (directRes.statusCode >= 200 && directRes.statusCode < 300) {
            directSuccess = true;
            debugPrint('[FcmDispatcher] Direct Token Push sent to $cleanRecipient successfully');
          } else {
            debugPrint('[FcmDispatcher] Direct Token Push returned ${directRes.statusCode}: ${directRes.body}');
          }
        } catch (tokenErr) {
          debugPrint('[FcmDispatcher] Direct Token Push network error: $tokenErr');
        }
      }

      // 3. Fallback: ONLY send to topic if NO direct token was registered or direct token dispatch failed!
      if (!directSuccess) {
        final topicPayload = {
          'message': {
            'topic': 'user_$cleanRecipient',
            'notification': {
              'title': pushTitle,
              'body': messageText,
            },
            'data': stringPayload,
            'android': androidConfig,
            'apns': apnsConfig,
          },
        };

        try {
          final topicRes = await http
              .post(
                Uri.parse(endpoint),
                headers: headers,
                body: jsonEncode(topicPayload),
              )
              .timeout(const Duration(seconds: 8));

          if (topicRes.statusCode >= 200 && topicRes.statusCode < 300) {
            debugPrint('[FcmDispatcher] Fallback Chat Push sent to user_$cleanRecipient topic successfully');
          }
        } catch (topicErr) {
          debugPrint('[FcmDispatcher] Fallback Topic Push network error: $topicErr');
        }
      }
    } catch (e) {
      debugPrint('[FcmDispatcher] dispatchChatNotification notice: $e');
    }
  }
}
