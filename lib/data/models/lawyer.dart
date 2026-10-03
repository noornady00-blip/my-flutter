// ==============================================================================
// ⚖️ LAWYER DATA MODEL
// ==============================================================================
// Represents lawyer profile stored in Firestore 'lawyers' collection.
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';
export 'sudan_cities.dart';

/// Comprehensive data model representing lawyer profile and verification status.
class LawyerModel {
  final String uid;
  final String name;
  final String phone; // رقم إنشاء الحساب الأساسي (خاص لتسجيل الدخول)
  final String callPhone; // رقم الاتصال المباشر (ظاهر للعامة في البطاقة)
  final String whatsapp; // رقم الواتساب المعتمد (ظاهر للعامة في البطاقة)
  final String city;
  final String specialization; // Kept as optional fallback for legacy data compatibility
  final String status; // 'pending' | 'approved' | 'rejected' | 'suspended'
  final String accountId; // 12-digit fixed unique identifier
  final String? photoBase64;
  final String? photoUrl;
  final DateTime createdAt;
  final DateTime? approvedAt;

  LawyerModel({
    required this.uid,
    required this.name,
    required this.phone,
    String? callPhone,
    this.whatsapp = '',
    this.city = '',
    this.specialization = '',
    this.status = 'approved',
    this.accountId = '',
    this.photoBase64,
    this.photoUrl,
    DateTime? createdAt,
    this.approvedAt,
  })  : callPhone = (callPhone != null && callPhone.isNotEmpty) ? callPhone : phone,
        createdAt = createdAt ?? DateTime.now();

  /// Effective joined or approved date for chronological ordering
  DateTime get effectiveJoinedAt => approvedAt ?? createdAt;

  /// Effective public call phone for clients and public cards
  String get publicCallPhone => callPhone.isNotEmpty ? callPhone : phone;

  /// Effective public WhatsApp phone for clients and public cards
  String get publicWhatsApp => whatsapp.isNotEmpty ? whatsapp : phone;

  // ---------------------------------------------------------------------------
  // Status Flags
  // ---------------------------------------------------------------------------
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
  bool get isSuspended => status == 'suspended';

  // ---------------------------------------------------------------------------
  // Factory Deserialization
  // ---------------------------------------------------------------------------
  factory LawyerModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedDate = DateTime.now();
    final rawDate = map['createdAt'];
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    }

    DateTime? parsedApprovedAt;
    final rawApprovedAt = map['approvedAt'];
    if (rawApprovedAt is Timestamp) {
      parsedApprovedAt = rawApprovedAt.toDate();
    } else if (rawApprovedAt is String) {
      parsedApprovedAt = DateTime.tryParse(rawApprovedAt);
    }

    final cityVal = (map['city'] ??
            map['location'] ??
            map['governorate'] ??
            map['address'])
        ?.toString()
        .trim() ??
        '';
    final specVal = (map['specialization'] ??
            map['specialty'] ??
            map['category'] ??
            map['lawType'] ??
            map['spec'])
        ?.toString()
        .trim() ??
        '';

    final phoneVal = map['phone']?.toString().trim() ?? '';
    final callPhoneVal = (map['callPhone'] ??
            map['contactPhone'] ??
            map['publicPhone'])
        ?.toString()
        .trim();
    final waVal = map['whatsapp']?.toString().trim() ?? '';

    return LawyerModel(
      uid: id,
      name: map['name']?.toString() ?? '',
      phone: phoneVal,
      callPhone: (callPhoneVal != null && callPhoneVal.isNotEmpty) ? callPhoneVal : phoneVal,
      whatsapp: waVal.isNotEmpty ? waVal : phoneVal,
      city: cityVal,
      specialization: specVal,
      status: map['status']?.toString() ?? 'pending',
      accountId: map['accountId']?.toString() ?? map['memberId']?.toString() ?? '',
      photoBase64: map['photoBase64']?.toString() ??
          map['photo']?.toString() ??
          map['avatar']?.toString(),
      photoUrl: map['photoUrl']?.toString() ?? map['imageUrl']?.toString(),
      createdAt: parsedDate,
      approvedAt: parsedApprovedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'callPhone': callPhone.isNotEmpty ? callPhone : phone,
      'whatsapp': whatsapp.isNotEmpty ? whatsapp : phone,
      'city': city,
      if (specialization.isNotEmpty) 'specialization': specialization,
      'role': 'lawyer',
      'status': status,
      if (accountId.isNotEmpty) 'accountId': accountId,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      if (approvedAt != null) 'approvedAt': Timestamp.fromDate(approvedAt!),
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'callPhone': callPhone.isNotEmpty ? callPhone : phone,
      'whatsapp': whatsapp.isNotEmpty ? whatsapp : phone,
      'city': city,
      if (specialization.isNotEmpty) 'specialization': specialization,
      'role': 'lawyer',
      'status': status,
      if (accountId.isNotEmpty) 'accountId': accountId,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
      if (approvedAt != null) 'approvedAt': approvedAt!.toIso8601String(),
    };
  }

  factory LawyerModel.fromJsonMap(Map<String, dynamic> map) {
    final cityVal = (map['city'] ??
            map['location'] ??
            map['governorate'] ??
            map['address'])
        ?.toString()
        .trim() ??
        '';
    final specVal = (map['specialization'] ??
            map['specialty'] ??
            map['category'] ??
            map['lawType'] ??
            map['spec'])
        ?.toString()
        .trim() ??
        '';

    final phoneVal = map['phone']?.toString().trim() ?? '';
    final callPhoneVal = (map['callPhone'] ??
            map['contactPhone'] ??
            map['publicPhone'])
        ?.toString()
        .trim();
    final waVal = map['whatsapp']?.toString().trim() ?? '';

    return LawyerModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: phoneVal,
      callPhone: (callPhoneVal != null && callPhoneVal.isNotEmpty) ? callPhoneVal : phoneVal,
      whatsapp: waVal.isNotEmpty ? waVal : phoneVal,
      city: cityVal,
      specialization: specVal,
      status: map['status']?.toString() ?? 'approved',
      accountId: map['accountId']?.toString() ?? map['memberId']?.toString() ?? '',
      photoBase64: map['photoBase64'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
      approvedAt: map['approvedAt'] != null
          ? DateTime.tryParse(map['approvedAt'].toString())
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------
  LawyerModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? callPhone,
    String? whatsapp,
    String? city,
    String? specialization,
    String? status,
    String? accountId,
    String? photoBase64,
    String? photoUrl,
    DateTime? createdAt,
    DateTime? approvedAt,
  }) {
    return LawyerModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      callPhone: callPhone ?? this.callPhone,
      whatsapp: whatsapp ?? this.whatsapp,
      city: city ?? this.city,
      specialization: specialization ?? this.specialization,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      photoBase64: photoBase64 ?? this.photoBase64,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
    );
  }
}
