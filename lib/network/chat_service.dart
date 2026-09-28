// ==============================================================================
// 💬 CHAT SERVICE & REALTIME FIRESTORE REPOSITORY
// ==============================================================================
// Manages real-time 1-on-1 conversations between Clients and Lawyers,
// with Admin oversight, 12-digit fixed account IDs, replies, deletions,
// pinning, blocking, and push notifications.
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/models/chat_model.dart';
import '../data/models/chat_message_model.dart';
import '../data/models/user_model.dart';
import '../data/models/lawyer.dart';
import '../core/utils/phone_utils.dart';
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
    // Admin sees only their own direct conversations (where they are a participant).
    // They do NOT have oversight access to all user chats — same experience as client/lawyer.
    if (role == 'admin') {
      return _db
          .collection('chats')
          .where('participants', arrayContains: uid)
          .snapshots()
          .map((snapshot) {
        final list = snapshot.docs
            .map((doc) => ChatModel.fromMap(doc.data(), doc.id))
            .where((chat) => !chat.isDeletedBy(uid))
            .toList();
        list.sort((a, b) {
          final aPinned = a.isPinnedBy(uid);
          final bPinned = b.isPinnedBy(uid);
          if (aPinned && !bPinned) return -1;
          if (!aPinned && bPinned) return 1;
          return b.updatedAt.compareTo(a.updatedAt);
        });
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
          .where((chat) => !chat.isDeletedBy(uid))
          .toList();
      list.sort((a, b) {
        final aPinned = a.isPinnedBy(uid);
        final bPinned = b.isPinnedBy(uid);
        if (aPinned && !bPinned) return -1;
        if (!aPinned && bPinned) return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
      return list;
    }).handleError((err) {
      debugPrint('[ChatService] getChatsForUser error: $err');
      return <ChatModel>[];
    });
  }

  /// Stream messages for a specific conversation thread (newest first for reverse ListView)
  /// Optionally filters out messages deleted locally for the current user.
  Stream<List<ChatMessageModel>> getMessagesStream(String chatId, {String? currentUserId}) {
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
          .where((msg) {
            if (currentUserId != null && currentUserId.isNotEmpty) {
              return !msg.deletedFor.contains(currentUserId);
            }
            return true;
          })
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

    final effectiveClientPhoto = client.photoUrl ?? client.photoBase64;
    final effectiveLawyerPhoto = lawyer.photoUrl ?? lawyer.photoBase64;

    final fallbackChat = ChatModel(
      id: chatId,
      participants: [client.uid, lawyer.uid],
      clientId: client.uid,
      clientName: client.name.isNotEmpty ? client.name : 'عميل',
      clientPhone: client.phone,
      clientPhoto: effectiveClientPhoto,
      clientPhotoBase64: client.photoBase64,
      clientAccountId: client.accountId,
      lawyerId: lawyer.uid,
      lawyerName: lawyer.name.isNotEmpty ? lawyer.name : 'محامٍ',
      lawyerPhone: lawyer.phone,
      lawyerPhoto: effectiveLawyerPhoto,
      lawyerPhotoBase64: lawyer.photoBase64,
      lawyerAccountId: lawyer.accountId,
      lastMessage: 'مرحباً، تم بدء المحادثة',
      lastSenderId: client.uid,
      lastSenderName: client.name,
      lastMessageTime: DateTime.now(),
      unreadByClient: 0,
      unreadByLawyer: 0,
      pinnedBy: const [],
      deletedBy: const [],
    );

    try {
      final doc = await chatDocRef.get().timeout(const Duration(seconds: 4));
      if (doc.exists && doc.data() != null) {
        final existing = ChatModel.fromMap(doc.data()!, doc.id);
        final Map<String, dynamic> updates = {};

        // Keep client profile info up-to-date in the conversation
        if (client.name.isNotEmpty && client.name != 'عميل' && existing.clientName != client.name) {
          updates['clientName'] = client.name;
        }
        if (client.phone.isNotEmpty && existing.clientPhone != client.phone) {
          updates['clientPhone'] = client.phone;
        }
        if (client.accountId.isNotEmpty && existing.clientAccountId != client.accountId) {
          updates['clientAccountId'] = client.accountId;
        }
        if (effectiveClientPhoto != null && effectiveClientPhoto.isNotEmpty && existing.clientPhoto != effectiveClientPhoto) {
          updates['clientPhoto'] = effectiveClientPhoto;
        }
        if (client.photoBase64 != null && client.photoBase64!.isNotEmpty && existing.clientPhotoBase64 != client.photoBase64) {
          updates['clientPhotoBase64'] = client.photoBase64;
        }

        // Keep lawyer profile info up-to-date in the conversation
        if (lawyer.name.isNotEmpty && lawyer.name != 'محامٍ' && existing.lawyerName != lawyer.name) {
          updates['lawyerName'] = lawyer.name;
        }
        if (lawyer.phone.isNotEmpty && existing.lawyerPhone != lawyer.phone) {
          updates['lawyerPhone'] = lawyer.phone;
        }
        if (lawyer.accountId.isNotEmpty && existing.lawyerAccountId != lawyer.accountId) {
          updates['lawyerAccountId'] = lawyer.accountId;
        }
        if (effectiveLawyerPhoto != null && effectiveLawyerPhoto.isNotEmpty && existing.lawyerPhoto != effectiveLawyerPhoto) {
          updates['lawyerPhoto'] = effectiveLawyerPhoto;
        }
        if (lawyer.photoBase64 != null && lawyer.photoBase64!.isNotEmpty && existing.lawyerPhotoBase64 != lawyer.photoBase64) {
          updates['lawyerPhotoBase64'] = lawyer.photoBase64;
        }

        if (updates.isNotEmpty) {
          unawaited(chatDocRef.set(updates, SetOptions(merge: true)).catchError((_) {}));
        }
        return existing;
      }

      await chatDocRef.set(fallbackChat.toMap(), SetOptions(merge: true));
      return fallbackChat;
    } catch (e) {
      debugPrint('[ChatService] getOrCreateChat notice: $e');
      return fallbackChat;
    }
  }

  /// Synchronizes a user's updated photo and profile across all their conversations in Firestore
  Future<void> syncUserProfileToAllChats({
    required String uid,
    required String role,
    String? name,
    String? photoUrl,
    String? photoBase64,
    String? phone,
    String? accountId,
  }) async {
    if (uid.isEmpty) return;
    try {
      final isLawyer = (role == 'lawyer' || role == 'approved_lawyer');
      final cleanDigits = phone != null ? PhoneUtils.cleanDigits(phone) : '';

      // Parallel queries across participants, specific role IDs, and phone numbers
      final queries = <Future<QuerySnapshot<Map<String, dynamic>>>>[
        _db.collection('chats').where('participants', arrayContains: uid).get(),
        _db.collection('chats').where(isLawyer ? 'lawyerId' : 'clientId', isEqualTo: uid).get(),
      ];
      if (cleanDigits.isNotEmpty) {
        queries.add(_db.collection('chats').where(isLawyer ? 'lawyerPhone' : 'clientPhone', isEqualTo: phone).get());
        queries.add(_db.collection('chats').where(isLawyer ? 'lawyerPhone' : 'clientPhone', isEqualTo: cleanDigits).get());
      }

      final snapshots = await Future.wait(queries);
      final docsMap = <String, DocumentSnapshot<Map<String, dynamic>>>{};
      for (final snap in snapshots) {
        for (final doc in snap.docs) {
          docsMap[doc.id] = doc;
        }
      }

      if (docsMap.isEmpty) return;

      final batch = _db.batch();
      for (final doc in docsMap.values) {
        final Map<String, dynamic> updateData = {};
        if (isLawyer) {
          if (name != null && name.isNotEmpty) updateData['lawyerName'] = name;
          if (phone != null && phone.isNotEmpty) updateData['lawyerPhone'] = phone;
          if (accountId != null && accountId.isNotEmpty) updateData['lawyerAccountId'] = accountId;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            updateData['lawyerPhoto'] = photoUrl;
          } else if (photoUrl == '') {
            updateData['lawyerPhoto'] = FieldValue.delete();
          }
          if (photoBase64 != null && photoBase64.isNotEmpty) {
            updateData['lawyerPhotoBase64'] = photoBase64;
          } else if (photoBase64 == '') {
            updateData['lawyerPhotoBase64'] = FieldValue.delete();
          }
        } else {
          if (name != null && name.isNotEmpty) updateData['clientName'] = name;
          if (phone != null && phone.isNotEmpty) updateData['clientPhone'] = phone;
          if (accountId != null && accountId.isNotEmpty) updateData['clientAccountId'] = accountId;
          if (photoUrl != null && photoUrl.isNotEmpty) {
            updateData['clientPhoto'] = photoUrl;
          } else if (photoUrl == '') {
            updateData['clientPhoto'] = FieldValue.delete();
          }
          if (photoBase64 != null && photoBase64.isNotEmpty) {
            updateData['clientPhotoBase64'] = photoBase64;
          } else if (photoBase64 == '') {
            updateData['clientPhotoBase64'] = FieldValue.delete();
          }
        }

        if (updateData.isNotEmpty) {
          batch.set(doc.reference, updateData, SetOptions(merge: true));
        }
      }

      await batch.commit();
    } catch (e) {
      debugPrint('[ChatService] syncUserProfileToAllChats error: $e');
    }
  }

  /// Send a text message inside a conversation with optional reply
  Future<void> sendMessage({
    required String chatId,
    required String senderId,
    required String senderName,
    required String senderRole, // 'client' | 'lawyer' | 'admin'
    required String senderAccountId,
    required String text,
    required String recipientId,
    String? replyToMessageId,
    String? replyToText,
    String? replyToSenderName,
  }) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    // Check if recipient has stopped or muted this chat
    bool isStoppedByRecipient = false;
    bool isMutedByRecipient = false;
    try {
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      if (chatDoc.exists && chatDoc.data() != null) {
        final data = chatDoc.data()!;
        final rawStopped = data['stoppedBy'];
        if (rawStopped is List && rawStopped.map((e) => e.toString()).contains(recipientId)) {
          isStoppedByRecipient = true;
        }
        final rawMuted = data['mutedBy'];
        if (rawMuted is List && rawMuted.map((e) => e.toString()).contains(recipientId)) {
          isMutedByRecipient = true;
        }
      }
    } catch (_) {}

    final batch = _db.batch();

    // 1. Add message to subcollection
    // If recipient has stopped the chat, message is hidden for recipient (deletedFor: [recipientId])
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
      'isDeletedForEveryone': false,
      'deletedFor': isStoppedByRecipient ? <String>[recipientId] : <String>[],
      'replyToMessageId': ?replyToMessageId,
      'replyToText': ?replyToText,
      'replyToSenderName': ?replyToSenderName,
    };
    batch.set(msgDocRef, messageData);

    // 2. Update conversation summary and remove from deletedBy
    final chatDocRef = _db.collection('chats').doc(chatId);
    final updateData = <String, dynamic>{
      'id': chatId,
      'participants': FieldValue.arrayUnion([senderId, recipientId]),
      'deletedBy': FieldValue.arrayRemove(isStoppedByRecipient ? [senderId] : [senderId, recipientId]),
      'lastMessage': cleanText,
      'lastSenderId': senderId,
      'lastSenderName': senderName,
      'lastSenderRole': senderRole,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Only increment unread count for recipient if NOT stopped by recipient
    if (!isStoppedByRecipient) {
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
    }

    batch.set(chatDocRef, updateData, SetOptions(merge: true));
    await batch.commit();

    // Dispatch real push notification to recipient device (only if recipient has NOT stopped AND NOT muted this chat)
    if (recipientId.isNotEmpty && recipientId != senderId && !isStoppedByRecipient && !isMutedByRecipient) {
      try {
        unawaited(FcmDispatcherService().dispatchChatNotification(
          recipientId: recipientId,
          senderId: senderId,
          senderName: senderName,
          messageText: cleanText,
          chatId: chatId,
          senderRole: senderRole,
          senderAccountId: senderAccountId,
        ));
      } catch (_) {}
    }
  }

  /// Delete message for everyone (within 1 minute)
  /// Synchronizes the parent conversation summary so it displays "تم حذف هذه الرسالة" outside and clears unread badges.
  Future<void> deleteMessageForEveryone({
    required String chatId,
    required String messageId,
  }) async {
    try {
      // 1. Mark message as deleted
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'isDeletedForEveryone': true,
        'text': 'تم حذف هذه الرسالة',
      });

      // 2. Fetch latest message to see if this was the latest message
      final lastMsgSnap = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (lastMsgSnap.docs.isNotEmpty) {
        final latestDoc = lastMsgSnap.docs.first;
        final isDeleted = latestDoc.data()['isDeletedForEveryone'] == true;
        final latestText = isDeleted
            ? 'تم حذف هذه الرسالة'
            : (latestDoc.data()['text']?.toString() ?? 'تم حذف هذه الرسالة');

        await _db.collection('chats').doc(chatId).update({
          'lastMessage': latestText,
          'unreadByClient': 0,
          'unreadByLawyer': 0,
        });
      } else {
        await _db.collection('chats').doc(chatId).update({
          'lastMessage': 'تم حذف هذه الرسالة',
          'unreadByClient': 0,
          'unreadByLawyer': 0,
        });
      }
    } catch (e) {
      debugPrint('[ChatService] deleteMessageForEveryone error: $e');
    }
  }

  /// Delete message for the active user only
  Future<void> deleteMessageForMe({
    required String chatId,
    required String messageId,
    required String currentUserId,
  }) async {
    try {
      await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({
        'deletedFor': FieldValue.arrayUnion([currentUserId]),
      });

      // Clear any stuck unread count on the parent chat
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final data = chatDoc.data() ?? {};
        final isLawyer = (data['lawyerId'] == currentUserId);
        if (isLawyer) {
          await _db.collection('chats').doc(chatId).update({'unreadByLawyer': 0});
        } else {
          await _db.collection('chats').doc(chatId).update({'unreadByClient': 0});
        }
      }
    } catch (e) {
      debugPrint('[ChatService] deleteMessageForMe error: $e');
    }
  }

  /// Toggle pin status for a chat
  Future<void> togglePinChat({
    required String chatId,
    required String currentUserId,
    required bool pin,
  }) async {
    try {
      await _db.collection('chats').doc(chatId).update({
        'pinnedBy': pin
            ? FieldValue.arrayUnion([currentUserId])
            : FieldValue.arrayRemove([currentUserId]),
      });
    } catch (e) {
      debugPrint('[ChatService] togglePinChat error: $e');
    }
  }

  /// Toggle mute/silence notifications for a chat
  Future<void> toggleMuteChat({
    required String chatId,
    required String currentUserId,
    required bool mute,
  }) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'mutedBy': mute
            ? FieldValue.arrayUnion([currentUserId])
            : FieldValue.arrayRemove([currentUserId]),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatService] toggleMuteChat error: $e');
    }
  }

  /// Toggle unread status for a chat
  Future<void> toggleUnreadChat({
    required String chatId,
    required String currentUserId,
    required String role,
    required bool markUnread,
  }) async {
    try {
      final chatDoc = await _db.collection('chats').doc(chatId).get();
      final data = chatDoc.data() ?? {};
      final clientId = data['clientId']?.toString() ?? '';
      final isClient = currentUserId == clientId || role == 'client';
      final field = isClient ? 'unreadByClient' : 'unreadByLawyer';
      await _db.collection('chats').doc(chatId).update({
        field: markUnread ? 1 : 0,
      });
    } catch (e) {
      debugPrint('[ChatService] toggleUnreadChat error: $e');
    }
  }

  /// Delete conversation for the active user only (removes from their list and hides all past messages)
  Future<void> deleteChatForUser({
    required String chatId,
    required String currentUserId,
  }) async {
    if (chatId.isEmpty || currentUserId.isEmpty) return;
    try {
      // 1. Fetch all messages in the chat and mark them deletedFor this user
      final messagesSnap = await _db
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .get();

      final batch = _db.batch();
      for (final doc in messagesSnap.docs) {
        batch.update(doc.reference, {
          'deletedFor': FieldValue.arrayUnion([currentUserId]),
        });
      }

      // 2. Mark parent chat document as deletedBy this user
      final chatRef = _db.collection('chats').doc(chatId);
      batch.set(chatRef, {
        'deletedBy': FieldValue.arrayUnion([currentUserId]),
        'pinnedBy': FieldValue.arrayRemove([currentUserId]),
      }, SetOptions(merge: true));

      await batch.commit();
    } catch (e) {
      debugPrint('[ChatService] deleteChatForUser error: $e');
    }
  }

  /// Toggle stopped/paused status for a chat (disables messaging and suppresses all notifications from the other party)
  Future<void> toggleStopChat({
    required String chatId,
    required String currentUserId,
    required bool stop,
  }) async {
    try {
      await _db.collection('chats').doc(chatId).set({
        'stoppedBy': stop
            ? FieldValue.arrayUnion([currentUserId])
            : FieldValue.arrayRemove([currentUserId]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[ChatService] toggleStopChat error: $e');
    }
  }

  /// Delete chat for a user
  Future<void> deleteChat({
    required String chatId,
    required String userId,
  }) async {
    await deleteChatForUser(chatId: chatId, currentUserId: userId);
  }

  /// Mark conversation as read for the active user
  Future<void> markChatAsRead({
    required String chatId,
    required String currentUserId,
    required String currentUserRole,
  }) async {
    if (chatId.isEmpty || currentUserId.isEmpty) return;
    try {
      final chatRef = _db.collection('chats').doc(chatId);
      final chatDoc = await chatRef.get();
      final data = chatDoc.data() ?? {};
      final clientId = data['clientId']?.toString() ?? '';
      final lawyerId = data['lawyerId']?.toString() ?? '';

      final Map<String, dynamic> update = {};
      if (currentUserId == clientId) {
        update['unreadByClient'] = 0;
      }
      if (currentUserId == lawyerId) {
        update['unreadByLawyer'] = 0;
      }

      final isLawyer = currentUserRole == 'lawyer' || currentUserRole == 'approved_lawyer';
      if (isLawyer) {
        update['unreadByLawyer'] = 0;
      } else if (currentUserRole == 'client') {
        update['unreadByClient'] = 0;
      } else if (currentUserRole == 'admin') {
        // Admin chat: clear both counters or whichever is non-zero
        update['unreadByClient'] = 0;
        update['unreadByLawyer'] = 0;
      }

      // If user matched neither clientId nor lawyerId explicitly, clear both for safety
      if (update.isEmpty) {
        update['unreadByClient'] = 0;
        update['unreadByLawyer'] = 0;
      }

      await chatRef.update(update).catchError((_) {});

      // Also mark unread messages sent by the other party as read
      try {
        final unreadMsgsSnap = await _db
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('isRead', isEqualTo: false)
            .limit(50)
            .get();

        if (unreadMsgsSnap.docs.isNotEmpty) {
          final batch = _db.batch();
          bool hasChanges = false;
          for (final doc in unreadMsgsSnap.docs) {
            final mData = doc.data();
            if (mData['senderId'] != currentUserId) {
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
