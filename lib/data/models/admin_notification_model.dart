// ==============================================================================
// 🔔 ADMIN NOTIFICATION DATA MODEL
// ==============================================================================
// Represents in-app and push notification payloads received by administrators.
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification model consumed by admin dashboards and notification handlers.
class AdminNotificationModel {
  final String id;
  final String type; // 'password_reset' | 'lawyer_registration' | 'support_message'
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final bool isRead;

  const AdminNotificationModel({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
    required this.createdAt,
    this.isRead = false,
  });

  // ---------------------------------------------------------------------------
  // Type Checkers
  // ---------------------------------------------------------------------------
  bool get isPasswordReset =>
      type == 'password_reset' || title.contains('استعادة كلمة المرور');

  bool get isLawyerRegistration =>
      type == 'lawyer_registration' || title.contains('انضمام');

  bool get isSupportMessage =>
      type == 'support_message' ||
      type == 'contact' ||
      title.contains('رسالة تواصل');

  // ---------------------------------------------------------------------------
  // Factory Deserialization
  // ---------------------------------------------------------------------------
  factory AdminNotificationModel.fromMap(
      Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AdminNotificationModel(
      id: docId,
      type: map['type']?.toString() ?? 'general',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      data: map['data'] is Map ? Map<String, dynamic>.from(map['data']) : {},
      createdAt: parseDate(map['createdAt']),
      isRead: map['read'] == true || map['isRead'] == true,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'body': body,
      'data': data,
      'createdAt': Timestamp.fromDate(createdAt),
      'read': isRead,
    };
  }
}
