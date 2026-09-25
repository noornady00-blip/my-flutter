// ==============================================================================
// 📨 CHAT MESSAGE DATA MODEL
// ==============================================================================
// Represents a single message within a conversation thread with sender metadata,
// 12-digit account ID, read status, and delivery timestamps.
// ==============================================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String senderName;
  final String senderRole; // 'client' | 'lawyer' | 'admin'
  final String senderAccountId; // 12-digit fixed ID
  final String text;
  final DateTime createdAt;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    this.senderAccountId = '',
    required this.text,
    DateTime? createdAt,
    this.isRead = false,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdminSender => senderRole == 'admin';

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ChatMessageModel(
      id: id,
      chatId: map['chatId']?.toString() ?? '',
      senderId: map['senderId']?.toString() ?? '',
      senderName: map['senderName']?.toString() ?? '',
      senderRole: map['senderRole']?.toString() ?? 'client',
      senderAccountId: map['senderAccountId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      createdAt: parseDate(map['createdAt']),
      isRead: map['isRead'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'senderAccountId': senderAccountId,
      'text': text,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
    };
  }
}
