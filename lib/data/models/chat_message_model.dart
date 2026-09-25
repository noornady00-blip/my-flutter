// ==============================================================================
// 📨 CHAT MESSAGE DATA MODEL
// ==============================================================================
// Represents a single message within a conversation thread with sender metadata,
// 12-digit account ID, read status, delivery timestamps, replies, and deletions.
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

  // Deletion & Reply fields
  final bool isDeletedForEveryone;
  final List<String> deletedFor;
  final String? replyToMessageId;
  final String? replyToText;
  final String? replyToSenderName;

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
    this.isDeletedForEveryone = false,
    this.deletedFor = const [],
    this.replyToMessageId,
    this.replyToText,
    this.replyToSenderName,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdminSender => senderRole == 'admin';

  factory ChatMessageModel.fromMap(Map<String, dynamic> map, String id) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawDeletedFor = map['deletedFor'];
    final List<String> parsedDeletedFor = rawDeletedFor is List
        ? rawDeletedFor.map((e) => e.toString()).toList()
        : [];

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
      isDeletedForEveryone: map['isDeletedForEveryone'] == true || map['isDeleted'] == true,
      deletedFor: parsedDeletedFor,
      replyToMessageId: map['replyToMessageId']?.toString(),
      replyToText: map['replyToText']?.toString(),
      replyToSenderName: map['replyToSenderName']?.toString(),
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
      'isDeletedForEveryone': isDeletedForEveryone,
      'deletedFor': deletedFor,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
      if (replyToText != null) 'replyToText': replyToText,
      if (replyToSenderName != null) 'replyToSenderName': replyToSenderName,
    };
  }
}
