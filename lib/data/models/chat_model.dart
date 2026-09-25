// ==============================================================================
// 💬 CHAT CONVERSATION DATA MODEL
// ==============================================================================
// Represents a conversation thread between a Client and a Lawyer (accessible
// to authorized Admins) with participant details, 12-digit account IDs, and status.
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String clientId;
  final String clientName;
  final String clientPhone;
  final String? clientPhoto;
  final String clientAccountId; // 12-digit fixed ID

  final String lawyerId;
  final String lawyerName;
  final String lawyerPhone;
  final String? lawyerPhoto;
  final String lawyerAccountId; // 12-digit fixed ID

  final String lastMessage;
  final String lastSenderId;
  final String lastSenderName;
  final DateTime lastMessageTime;
  final int unreadByClient;
  final int unreadByLawyer;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    required this.participants,
    required this.clientId,
    required this.clientName,
    required this.clientPhone,
    this.clientPhoto,
    this.clientAccountId = '',
    required this.lawyerId,
    required this.lawyerName,
    required this.lawyerPhone,
    this.lawyerPhoto,
    this.lawyerAccountId = '',
    this.lastMessage = '',
    this.lastSenderId = '',
    this.lastSenderName = '',
    DateTime? lastMessageTime,
    this.unreadByClient = 0,
    this.unreadByLawyer = 0,
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

    return ChatModel(
      id: id,
      participants: parsedParticipants,
      clientId: map['clientId']?.toString() ?? '',
      clientName: map['clientName']?.toString() ?? 'عميل',
      clientPhone: map['clientPhone']?.toString() ?? '',
      clientPhoto: map['clientPhoto']?.toString(),
      clientAccountId: map['clientAccountId']?.toString() ?? '',
      lawyerId: map['lawyerId']?.toString() ?? '',
      lawyerName: map['lawyerName']?.toString() ?? 'محامٍ',
      lawyerPhone: map['lawyerPhone']?.toString() ?? '',
      lawyerPhoto: map['lawyerPhoto']?.toString(),
      lawyerAccountId: map['lawyerAccountId']?.toString() ?? '',
      lastMessage: map['lastMessage']?.toString() ?? '',
      lastSenderId: map['lastSenderId']?.toString() ?? '',
      lastSenderName: map['lastSenderName']?.toString() ?? '',
      lastMessageTime: parseDate(map['lastMessageTime']),
      unreadByClient: (map['unreadByClient'] is num) ? (map['unreadByClient'] as num).toInt() : 0,
      unreadByLawyer: (map['unreadByLawyer'] is num) ? (map['unreadByLawyer'] as num).toInt() : 0,
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
      'clientAccountId': clientAccountId,
      'lawyerId': lawyerId,
      'lawyerName': lawyerName,
      'lawyerPhone': lawyerPhone,
      if (lawyerPhoto != null) 'lawyerPhoto': lawyerPhoto,
      'lawyerAccountId': lawyerAccountId,
      'lastMessage': lastMessage,
      'lastSenderId': lastSenderId,
      'lastSenderName': lastSenderName,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadByClient': unreadByClient,
      'unreadByLawyer': unreadByLawyer,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Helper to get the other party's name and details based on current user UID
  String getOtherPartyName(String currentUserId) {
    return currentUserId == clientId ? lawyerName : clientName;
  }

  String? getOtherPartyPhoto(String currentUserId) {
    return currentUserId == clientId ? lawyerPhoto : clientPhoto;
  }

  String getOtherPartyAccountId(String currentUserId) {
    return currentUserId == clientId ? lawyerAccountId : clientAccountId;
  }

  String getOtherPartyPhone(String currentUserId) {
    return currentUserId == clientId ? lawyerPhone : clientPhone;
  }

  String getOtherPartyRole(String currentUserId) {
    return currentUserId == clientId ? 'lawyer' : 'client';
  }

  int getUnreadCount(String currentUserId) {
    return currentUserId == clientId ? unreadByClient : unreadByLawyer;
  }
}
