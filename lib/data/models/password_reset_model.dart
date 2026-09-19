// ==============================================================================
// 🔑 PASSWORD RESET DATA MODEL
// ==============================================================================
// Represents a password reset request submitted by a client or lawyer.
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/utils/phone_utils.dart';

/// Model representing password recovery tickets submitted by users.
class PasswordResetModel {
  final String id;
  final String phone;
  final String cleanPhone;
  final String status; // 'pending' | 'resolved' | 'rejected'
  final String source; // 'whatsapp' | 'in_app'
  final String? notes;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? tempPassword;

  final String? uid;
  final String? name;
  final String? role;
  final String? photoUrl;
  final String? photoBase64;
  final String? specialization;
  final String? city;

  const PasswordResetModel({
    required this.id,
    required this.phone,
    required this.cleanPhone,
    required this.status,
    required this.source,
    this.notes,
    required this.createdAt,
    this.resolvedAt,
    this.tempPassword,
    this.uid,
    this.name,
    this.role,
    this.photoUrl,
    this.photoBase64,
    this.specialization,
    this.city,
  });

  // ---------------------------------------------------------------------------
  // Status Getters
  // ---------------------------------------------------------------------------
  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isRejected => status == 'rejected';

  // ---------------------------------------------------------------------------
  // Factory Deserialization
  // ---------------------------------------------------------------------------
  factory PasswordResetModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      if (val is DateTime) return val;
      return DateTime.now();
    }

    final rawPhone = map['phone']?.toString() ?? '';
    final digits = map['cleanPhone']?.toString() ??
        rawPhone.replaceAll(RegExp(r'[^0-9]'), '');

    return PasswordResetModel(
      id: docId,
      phone: rawPhone,
      cleanPhone: digits,
      status: map['status']?.toString() ?? 'pending',
      source: map['source']?.toString() ?? 'whatsapp',
      notes: map['notes']?.toString(),
      createdAt: parseDate(map['createdAt']),
      resolvedAt:
          map['resolvedAt'] != null ? parseDate(map['resolvedAt']) : null,
      tempPassword: map['tempPassword']?.toString(),
      uid: map['uid']?.toString(),
      name: map['name']?.toString(),
      role: map['role']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      photoBase64: map['photoBase64']?.toString(),
      specialization: map['specialization']?.toString(),
      city: map['city']?.toString(),
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'phone': phone,
      'cleanPhone': cleanPhone,
      'status': status,
      'source': source,
      if (notes != null) 'notes': notes,
      'createdAt': Timestamp.fromDate(createdAt),
      if (resolvedAt != null) 'resolvedAt': Timestamp.fromDate(resolvedAt!),
      if (tempPassword != null) 'tempPassword': tempPassword,
      if (uid != null) 'uid': uid,
      if (name != null) 'name': name,
      if (role != null) 'role': role,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      if (specialization != null) 'specialization': specialization,
      if (city != null) 'city': city,
    };
  }

  /// Utility to format Sudanese and international phone numbers for WhatsApp API.
  static String formatWhatsAppNumber(String phone) {
    return PhoneUtils.formatWhatsAppNumber(phone);
  }
}
