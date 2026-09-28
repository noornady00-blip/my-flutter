// ==============================================================================
// 💬 CHAT CONVERSATION DATA MODEL
// ==============================================================================
// Represents a conversation thread between a Client and a Lawyer (accessible
// to authorized Admins) with participant details, 12-digit account IDs, pinning,
// deletion, and real-time read/unread status.
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String? clientPhoto;
  final String? clientPhotoBase64;
  final String clientAccountId; // 12-digit fixed ID

  final String lawyerId;
  final String lawyerName;
  final String lawyerPhone;
  final String? lawyerPhoto;
  final String? lawyerPhotoBase64;
  final String lawyerAccountId; // 12-digit fixed ID

  final String lastMessage;
  final String lastSenderId;
  final String lastSenderName;
  final String lastSenderRole;
  final DateTime lastMessageTime;
  final int unreadByClient;
  final int unreadByLawyer;
  final List<String> pinnedBy;
  final List<String> deletedBy;
  final List<String> mutedBy;
  final List<String> stoppedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.participants,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    this.clientPhoto,
    this.clientPhotoBase64,
    this.clientAccountId = '',
    required this.lawyerId,
    required this.lawyerName,
    required this.lawyerPhone,
    this.lawyerPhoto,
    this.lawyerPhotoBase64,
    this.lawyerAccountId = '',
    this.lastMessage = '',
    this.lastSenderId = '',
    this.lastSenderName = '',
    this.lastSenderRole = '',
    DateTime? lastMessageTime,
    this.unreadByClient = 0,
    this.unreadByLawyer = 0,
    this.pinnedBy = const [],
    this.deletedBy = const [],
    this.mutedBy = const [],
    this.stoppedBy = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : lastMessageTime = lastMessageTime ?? DateTime.now(),
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ChatModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawParticipants = map['participants'];
    final List<String> parsedParticipants = rawParticipants is List
        ? rawParticipants.map((e) => e.toString()).toList()
        : [map['clientId']?.toString() ?? '', map['lawyerId']?.toString() ?? ''];

    final rawPinnedBy = map['pinnedBy'];
    final List<String> parsedPinnedBy = rawPinnedBy is List
        ? rawPinnedBy.map((e) => e.toString()).toList()
        : [];

    final rawDeletedBy = map['deletedBy'];
    final List<String> parsedDeletedBy = rawDeletedBy is List
        ? rawDeletedBy.map((e) => e.toString()).toList()
        : [];

    final rawMutedBy = map['mutedBy'];
    final List<String> parsedMutedBy = rawMutedBy is List
        ? rawMutedBy.map((e) => e.toString()).toList()
        : [];

    final rawStoppedBy = map['stoppedBy'];
    final List<String> parsedStoppedBy = rawStoppedBy is List
        ? rawStoppedBy.map((e) => e.toString()).toList()
        : [];

    final rawClientPhoto = map['clientPhoto']?.toString() ??
        map['clientPhotoUrl']?.toString() ??
        map['client_photo_url']?.toString();
    final rawClientBase64 = map['clientPhotoBase64']?.toString() ??
        map['client_photo_base64']?.toString() ??
        (rawClientPhoto != null && !rawClientPhoto.startsWith('http') && rawClientPhoto.length > 50 ? rawClientPhoto : null);

    final rawLawyerPhoto = map['lawyerPhoto']?.toString() ??
        map['lawyerPhotoUrl']?.toString() ??
        map['lawyer_photo_url']?.toString();
    final rawLawyerBase64 = map['lawyerPhotoBase64']?.toString() ??
        map['lawyer_photo_base64']?.toString() ??
        (rawLawyerPhoto != null && !rawLawyerPhoto.startsWith('http') && rawLawyerPhoto.length > 50 ? rawLawyerPhoto : null);

    return ChatModel(
      id: id,
      participants: parsedParticipants,
      clientId: map['clientId']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? 'عميل',
      clientPhone: map['clientPhone']?.toString() ?? '',
      clientPhoto: rawClientPhoto,
      clientPhotoBase64: rawClientBase64,
      clientAccountId: map['clientAccountId']?.toString() ?? '',
      lawyerId: map['lawyerId']?.toString() ?? '',
      lawyerName: map['lawyerName']?.toString() ?? 'محامٍ',
      lawyerPhone: map['lawyerPhone']?.toString() ?? '',
      lawyerPhoto: rawLawyerPhoto,
      lawyerPhotoBase64: rawLawyerBase64,
      lawyerAccountId: map['lawyerAccountId']?.toString() ?? '',
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastSenderId: map['lastSenderId']?.toString() ?? '',
      lastSenderName: map['lastSenderName']?.toString() ?? '',
      lastSenderRole: map['lastSenderRole']?.toString() ?? '',
      lastMessageTime: parseDate(map['lastMessageTime']),
      unreadByClient: (map['unreadByClient'] is num) ? (map['unreadByClient'] as num).toInt() : 0,
      unreadByLawyer: (map['unreadByLawyer'] is num) ? (map['unreadByLawyer'] as num).toInt() : 0,
      pinnedBy: parsedPinnedBy,
      deletedBy: parsedDeletedBy,
      mutedBy: parsedMutedBy,
      stoppedBy: parsedStoppedBy,
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'clientId': clientId,
      'clientName': clientName,
      'clientPhone': clientPhone,
      if (clientPhoto != null) 'clientPhoto': clientPhoto,
      if (clientPhotoBase64 != null) 'clientPhotoBase64': clientPhotoBase64,
      'clientAccountId': clientAccountId,
      'lawyerId': lawyerId,
      'lawyerName': lawyerName,
      'lawyerPhone': lawyerPhone,
      if (lawyerPhoto != null) 'lawyerPhoto': lawyerPhoto,
      if (lawyerPhotoBase64 != null) 'lawyerPhotoBase64': lawyerPhotoBase64,
      'lawyerAccountId': lawyerAccountId,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastSenderName': lastSenderName,
      'lastSenderRole': lastSenderRole,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadByClient': unreadByClient,
      'unreadByLawyer': unreadByLawyer,
      'pinnedBy': pinnedBy,
      'deletedBy': deletedBy,
      'mutedBy': mutedBy,
      'stoppedBy': stoppedBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  bool isPinnedBy(String uid) => pinnedBy.contains(uid);
  bool isDeletedBy(String uid) => deletedBy.contains(uid);
  bool isMutedBy(String uid) => mutedBy.contains(uid);
  bool isStoppedBy(String uid) => stoppedBy.contains(uid);

  /// Helper to get the other party's name and details based on current user UID
  String getOtherPartyName(String currentUserId) {
    return currentUserId == clientId ? lawyerName : clientName;
  }

  String? getOtherPartyPhoto(String currentUserId) {
    return currentUserId == clientId ? lawyerPhoto : clientPhoto;
  }

  String? getOtherPartyPhotoBase64(String currentUserId) {
    return currentUserId == clientId ? lawyerPhotoBase64 : clientPhotoBase64;
  }

  String getOtherPartyAccountId(String currentUserId) {
    return currentUserId == clientId ? lawyerAccountId : clientAccountId;
  }

  String getOtherPartyPhone(String currentUserId) {
    return currentUserId == clientId ? lawyerPhone : clientPhone;
  }

  String getOtherPartyRole(String currentUserId) {
    if (lastSenderRole == 'admin' && lastSenderId != currentUserId && lastSenderId.isNotEmpty) {
      return 'admin';
    }
    return currentUserId == clientId ? 'lawyer' : 'client';
  }

  int getUnreadCount(String currentUserId) {
    if (currentUserId.isEmpty) return 0;
    if (currentUserId == clientId) return unreadByClient;
    if (currentUserId == lawyerId) return unreadByLawyer;
    return unreadByClient > 0 ? unreadByClient : unreadByLawyer;
  }

  /// Helper to get the other party's UID
  String getOtherPartyUid(String currentUserId) {
    return currentUserId == clientId ? lawyerId : clientId;
  }
}
