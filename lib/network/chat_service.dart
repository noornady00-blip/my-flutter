// ==============================================================================
// 💬 CHAT SERVICE & REALTIME FIRESTORE REPOSITORY
// ==============================================================================
// Manages real-time 1-on-1 conversations between Clients and Lawyers,
// with Admin oversight, 12-digit fixed account IDs, and notification dispatch.
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/models/chat_model.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/user_model.dart';
import '../data/models/lawyer.dart';
import 'fcm_dispatcher_service.dart';

class ChatService {
  final FirebaseFirestore _db;

  ChatService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  /// Deterministic ID generator for client-lawyer chat threads
  static String generateChatId(String clientUid, String lawyerUid) {
    return 'chat_${clientUid}_$lawyerUid';
  }

  // ---------------------------------------------------------------------------
  // 📥 STREAMS
  // ---------------------------------------------------------------------------

  /// Stream all conversations relevant to the current user (Client, Lawyer, or Admin)
  Stream<List<ChatModel>> getChatsForUser(String uid, String role) {
    if (role == 'admin') {
      return _db.collection('chats').snapshots().map((snapshot) {
        final list = snapshot.docs
            .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
            .toList();
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return list;
      }).handleError((err) {
        debugPrint('[ChatService] admin getChatsForUser error: $err');
        return <ChatModel>[];
      });
    }

    // Index-free single-field query: works instantly out of the box without requiring manual composite indexes
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    }).handleError((err) {
      debugPrint('[ChatService] getChatsForUser error: $err');
      return <ChatModel>[];
    });
  }

  /// Stream messages for a specific conversation thread (newest first for reverse ListView)
  Stream<List<ChatMessageModel>> getMessagesStream(String chatId) {
    if (chatId.trim().isEmpty) {
      return Stream.value(<ChatMessageModel>[]);
    }
    return _db
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => ChatMessageModel.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Stream unread message count for a user (useful for badge counts)
  Stream<int> getUnreadCountStream(String uid, String role) {
    if (role == 'admin') return const Stream.empty();
    return _db
        .collection('chats')
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snap) {
      int count = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (role == 'lawyer') {
          count += (data['unreadByLawyer'] as num?)?.toInt() ?? 0;
        } else {
          count += (data['unreadByClient'] as num?)?.toInt() ?? 0;
        }
      }
      return count;
    }).handleError((_) => 0);
  }

  // ---------------------------------------------------------------------------
  // 🚀 ACTIONS
  // ---------------------------------------------------------------------------

  /// Creates or retrieves an existing conversation between a Client and a Lawyer
  Future<ChatModel> getOrCreateChat({
    required UserModel client,
    required LawyerModel lawyer,
  }) async {
    final chatId = generateChatId(client.uid, lawyer.uid);
    final chatDocRef = _db.collection('chats').doc(chatId);

    final fallbackChat = ChatModel(
      id: chatId,
      participants: [client.uid, lawyer.uid],
      clientId: client.uid,
      clientName: client.name.isNotEmpty ? client.name : 'عميل',
      clientPhone: client.phone,
      clientPhoto: client.photoUrl,
      clientAccountId: client.accountId,
      lawyerId: lawyer.uid,
      lawyerName: lawyer.name.isNotEmpty ? lawyer.name : 'محامٍ',
      lawyerPhone: lawyer.phone,
      lawyerPhoto: lawyer.photoUrl,
      lawyerAccountId: lawyer.accountId,
      lastMessage: 'مرحباً، تم بدء المحادثة',
      lastSenderId: client.uid,
      lastSenderName: client.name,
      lastMessageTime: DateTime.now(),
      unreadByClient: 0,
      unreadByLawyer: 0,
    );

    try {
      final doc = await chatDocRef.get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final existing = ChatModel.fromMap(doc.data()!, doc.id);
        // Refresh account IDs if they were empty
        if ((existing.clientAccountId.isEmpty && client.accountId.isNotEmpty) ||
            (existing.lawyerAccountId.isEmpty && lawyer.accountId.isNotEmpty)) {
          unawaited(chatDocRef.update({
            if (client.accountId.isNotEmpty) 'clientAccountId': client.accountId,
            if (lawyer.accountId.isNotEmpty) 'lawyerAccountId': lawyer.accountId,
          }).catchError((_) {}));
        }
        return existing;
      }

      await chatDocRef.set(fallbackChat.toMap(), SetOptions(merge: true));
      return fallbackChat;
    } catch (e) {
      debugPrint('[ChatService] getOrCreateChat notice: $e');
      // Always return valid ChatModel so UI never freezes or spins indefinitely
      return fallbackChat;
    }
  }

  /// Send a text message inside a conversation
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderRole, // 'client' | 'lawyer' | 'admin'
    required String senderAccountId,
    required String text,
    required String recipientId,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    final batch = _db.batch();

    // 1. Add message to subcollection
    final msgDocRef = _db.collection('chats').doc(chatId).collection('messages').doc();
    final messageData = {
      'id': msgDocRef.id,
      'chatId': chatId,
      'senderId': senderId,
      'senderName': senderName,
      'senderRole': senderRole,
      'senderAccountId': senderAccountId,
      'text': cleanText,
      'createdAt': FieldValue.serverTimestamp(),
      'isRead': false,
    };
    batch.set(msgDocRef, messageData);

    // 2. Update conversation summary
    final chatDocRef = _db.collection('chats').doc(chatId);
    final updateData = <String, dynamic>{
      'id': chatId,
      'participants': FieldValue.arrayUnion([senderId, recipientId]),
      'lastMessage': cleanText,
      'lastSenderId': senderId,
      'lastSenderName': senderName,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (senderRole == 'lawyer') {
      updateData['lawyerId'] = senderId;
      updateData['clientId'] = recipientId;
      updateData['unreadByClient'] = FieldValue.increment(1);
    } else if (senderRole == 'client') {
      updateData['clientId'] = senderId;
      updateData['lawyerId'] = recipientId;
      updateData['unreadByLawyer'] = FieldValue.increment(1);
    } else if (senderRole == 'admin') {
      updateData['unreadByClient'] = FieldValue.increment(1);
      updateData['unreadByLawyer'] = FieldValue.increment(1);
    }

    batch.set(chatDocRef, updateData, SetOptions(merge: true));
    await batch.commit();

    // Dispatch real push notification to recipient device (works even when app is closed)
    if (recipientId.isNotEmpty) {
      unawaited(FcmDispatcherService().dispatchChatNotification(
        recipientId: recipientId,
        senderName: senderName,
        messageText: cleanText,
        chatId: chatId,
        senderRole: senderRole,
        senderAccountId: senderAccountId,
      ));
    }
  }

  /// Mark conversation as read for the active user
  Future<void> markChatAsRead({
    required String chatId,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    try {
      final chatRef = _db.collection('chats').doc(chatId);
      final Map<String, dynamic> update = {};

      if (currentUserRole == 'lawyer') {
        update['unreadByLawyer'] = 0;
      } else if (currentUserRole == 'client') {
        update['unreadByClient'] = 0;
      }

      if (update.isNotEmpty) {
        await chatRef.update(update).catchError((_) {});
      }

      // Also mark unread messages sent by the other party as read
      try {
        final unreadMsgsSnap = await _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .limit(100)
            .get();

        if (unreadMsgsSnap.docs.isNotEmpty) {
          final batch = _db.batch();
          bool hasChanges = false;
          for (final doc in unreadMsgsSnap.docs) {
            final data = doc.data();
            if (data['senderId'] != currentUserId) {
              batch.update(doc.reference, {'isRead': true});
              hasChanges = true;
            }
          }
          if (hasChanges) {
            await batch.commit().catchError((_) {});
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('[ChatService] markChatAsRead notice: $e');
    }
  }
}
