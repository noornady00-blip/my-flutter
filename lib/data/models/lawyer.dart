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
  final String phone;
  final String whatsapp;
  final String city;
  final String specialization;
  final String status; // 'pending' | 'approved' | 'rejected' | 'suspended'
  final String? photoBase64;
  final String? photoUrl;
  final DateTime createdAt;

  LawyerModel({
    required this.uid,
    required this.name,
    required this.phone,
    this.whatsapp = '',
    this.city = '',
    this.specialization = '',
    this.status = 'approved',
    this.photoBase64,
    this.photoUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

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

    return LawyerModel(
      uid: id,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      whatsapp: map['whatsapp']?.toString() ?? '',
      city: cityVal,
      specialization: specVal,
      status: map['status']?.toString() ?? 'pending',
      photoBase64: map['photoBase64']?.toString(),
      photoUrl: map['photoUrl']?.toString(),
      createdAt: parsedDate,
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
      'whatsapp': whatsapp,
      'city': city,
      'specialization': specialization,
      'role': 'lawyer',
      'status': status,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'whatsapp': whatsapp,
      'city': city,
      'specialization': specialization,
      'role': 'lawyer',
      'status': status,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'createdAt': createdAt.toIso8601String(),
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

    return LawyerModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      whatsapp: map['whatsapp']?.toString() ?? '',
      city: cityVal,
      specialization: specVal,
      status: map['status']?.toString() ?? 'approved',
      photoBase64: map['photoBase64'] as String?,
      photoUrl: map['photoUrl'] as String?,
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------
  LawyerModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? whatsapp,
    String? city,
    String? specialization,
    String? status,
    String? photoBase64,
    String? photoUrl,
    DateTime? createdAt,
  }) {
    return LawyerModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      whatsapp: whatsapp ?? this.whatsapp,
      city: city ?? this.city,
      specialization: specialization ?? this.specialization,
      status: status ?? this.status,
      photoBase64: photoBase64 ?? this.photoBase64,
      photoUrl: photoUrl ?? this.photoUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
