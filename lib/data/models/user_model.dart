// ==============================================================================
// 👤 USER DATA MODEL
// ==============================================================================
// Represents user entity (Client, Lawyer, Admin) stored in Firestore 'users'.
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

/// Application user model representing clients, lawyers, and administrators.
class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String role; // 'client' | 'lawyer' | 'admin'
  final String status; // 'active' | 'suspended'
  final String accountId; // 12-digit fixed unique identifier
  final String? photoUrl;
  final String? photoBase64;
  final DateTime createdAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.role,
    this.status = 'active',
    this.accountId = '',
    this.photoUrl,
    this.photoBase64,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ---------------------------------------------------------------------------
  // Status & Role Getters
  // ---------------------------------------------------------------------------
  bool get isClient => role == 'client';
  bool get isLawyer => role == 'lawyer';
  bool get isAdmin => role == 'admin';
  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';

  // ---------------------------------------------------------------------------
  // Serialization & Deserialization
  // ---------------------------------------------------------------------------
  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      uid: id,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? 'client',
      status: map['status']?.toString() ?? 'active',
      accountId: map['accountId']?.toString() ?? map['memberId']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString() ??
          (map['photo'] != null && map['photo'].toString().startsWith('http')
              ? map['photo'].toString()
              : null) ??
          map['imageUrl']?.toString() ??
          map['profileImage']?.toString(),
      photoBase64: map['photoBase64']?.toString() ??
          (map['photo'] != null &&
                  !map['photo'].toString().startsWith('http') &&
                  map['photo'].toString().length > 100
              ? map['photo'].toString()
              : null),
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : (map['createdAt'] != null
              ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'role': role,
      'status': status,
      if (accountId.isNotEmpty) 'accountId': accountId,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Map<String, dynamic> toJsonMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'role': role,
      'status': status,
      if (accountId.isNotEmpty) 'accountId': accountId,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (photoBase64 != null) 'photoBase64': photoBase64,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UserModel.fromJsonMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map['uid']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      role: map['role']?.toString() ?? 'client',
      status: map['status']?.toString() ?? 'active',
      accountId: map['accountId']?.toString() ?? map['memberId']?.toString() ?? '',
      photoUrl: map['photoUrl']?.toString(),
      photoBase64: map['photoBase64']?.toString(),
      createdAt: map['createdAt'] != null
          ? (DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now())
          : DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // Copy With
  // ---------------------------------------------------------------------------
  UserModel copyWith({
    String? uid,
    String? name,
    String? phone,
    String? role,
    String? status,
    String? accountId,
    String? photoUrl,
    String? photoBase64,
    DateTime? createdAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      status: status ?? this.status,
      accountId: accountId ?? this.accountId,
      photoUrl: photoUrl ?? this.photoUrl,
      photoBase64: photoBase64 ?? this.photoBase64,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
