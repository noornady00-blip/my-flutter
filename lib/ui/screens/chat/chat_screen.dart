// ==============================================================================
// 💬 CHAT CONVERSATION SCREEN
// ==============================================================================
// WhatsApp-familiar simplicity tailored to Mahameek's Royal Navy & Gold branding.
// Features RTL Arabic layout, Swipe-to-Reply (left), Swipe-to-Delete (right with 1-min rule),
// supervisor privacy protection, curved header, live client photo loading,
// and real-time Firestore synchronization.
// ==============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/chat_model.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/chat_service.dart';
import '../../../network/auth_service.dart';
import '../../../network/notification_service.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../custom_widgets/profile_details_modal.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel? chat;
  final String? currentUserId;
  final String? currentUserName;
  final String? currentUserRole; // 'client' | 'lawyer' | 'admin'
  final String? currentUserAccountId;

  // Convenience parameters when initiated from Lawyer card or profile:
  final String? lawyerUid;
  final String? lawyerName;
  final String? lawyerAccountId;
  final String? lawyerPhone;
  final String? lawyerPhotoUrl;
  final String? lawyerPhotoBase64;

  // Convenience parameters when initiated from Client modal:
  final String? clientUid;
  final String? clientName;
  final String? clientAccountId;
  final String? clientPhone;
  final String? clientPhotoUrl;
  final String? clientPhotoBase64;

  // Or generic target:
  final String? otherUserUid;
  final String? otherUserName;
  final String? otherUserRole;
  final String? otherUserAccountId;

  const ChatScreen({
    super.key,
    this.chat,
    this.currentUserId,
    this.currentUserName,
    this.currentUserRole,
    this.currentUserAccountId,
    this.lawyerUid,
    this.lawyerName,
    this.lawyerAccountId,
    this.lawyerPhone,
    this.lawyerPhotoUrl,
    this.lawyerPhotoBase64,
    this.clientUid,
    this.clientName,
    this.clientAccountId,
    this.clientPhone,
    this.clientPhotoUrl,
    this.clientPhotoBase64,
    this.otherUserUid,
    this.otherUserName,
    this.otherUserRole,
    this.otherUserAccountId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final FocusNode _focusNode = FocusNode();

  ChatModel? _activeChat;
  String _currentUserId = '';
  String _currentUserName = '';
  String _currentUserRole = 'client';
  String _currentUserAccountId = '';
  String _detectedOtherRole = '';

  // Pin & Stop status state
  bool _isPinned = false;
  bool _isStoppedByMe = false;
  StreamSubscription<DocumentSnapshot>? _chatDocSubscription;
  Stream<List<ChatMessageModel>>? _messagesStream;
  bool _isMarkingRead = false;

  // Live profile details of the other party (especially for client photos & updated roles)
  String? _liveOtherPhotoUrl;
  String? _liveOtherPhotoBase64;
  String? _liveOtherName;
  String? _liveOtherAccountId;
  String? _liveOtherPhone;

  // Active reply target
  ChatMessageModel? _replyingTo;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.chat != null) {
      _activeChat = widget.chat;
      NotificationService.activeChatId = widget.chat!.id;
      _setupChatDocListener(widget.chat!.id);
      _updateMessagesStream();
    }
    _initChat();
  }

  void _updateMessagesStream() {
    if (_activeChat == null || _activeChat!.id.isEmpty) return;
    _messagesStream = _chatService.getMessagesStream(_activeChat!.id, currentUserId: _currentUserId);
  }

  void _setupChatDocListener(String chatId) {
    if (chatId.isEmpty) return;
    _chatDocSubscription?.cancel();
    _chatDocSubscription = FirebaseFirestore.instance
        .collection('chats')
        .doc(chatId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || doc.data() == null) return;
      final data = doc.data()!;
      final rawPinned = data['pinnedBy'];
      final pinnedBy = rawPinned is List ? rawPinned.map((e) => e.toString()).toList() : <String>[];
      final rawStopped = data['stoppedBy'];
      final stoppedBy = rawStopped is List ? rawStopped.map((e) => e.toString()).toList() : <String>[];
      if (mounted) {
        setState(() {
          _isPinned = _currentUserId.isNotEmpty && pinnedBy.contains(_currentUserId);
          _isStoppedByMe = _currentUserId.isNotEmpty && stoppedBy.contains(_currentUserId);
        });
      }
    }, onError: (err) {
      debugPrint('[ChatScreen] _setupChatDocListener error: $err');
    });
  }

  Future<void> _fetchOtherPartyInfoIfNeeded() async {
    if (_activeChat == null) return;
    try {
      final otherUid = _activeChat!.getOtherPartyUid(_currentUserId);
      final targetUid = otherUid.isNotEmpty
          ? otherUid
          : (widget.lawyerUid ?? widget.clientUid ?? widget.otherUserUid ?? '');

      if (targetUid.isNotEmpty) {
        final uDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .get()
            .timeout(const Duration(seconds: 4));

        String? photoUrl;
        String? photoBase64;
        String? name;
        String? accId;
        String? phone;
        String? r;

        if (uDoc.exists && uDoc.data() != null) {
          final data = uDoc.data()!;
          r = data['role']?.toString();
          final rawPhoto = data['photo']?.toString();
          photoUrl = data['photoUrl']?.toString() ??
              data['user_profile_photo_url']?.toString() ??
              data['imageUrl']?.toString() ??
              data['profileImage']?.toString() ??
              (rawPhoto != null && (rawPhoto.startsWith('http') || rawPhoto.startsWith('data:image'))
                  ? rawPhoto
                  : null);

          photoBase64 = data['photoBase64']?.toString() ??
              data['user_profile_photo_base64']?.toString() ??
              data['user_profile_photo']?.toString() ??
              (rawPhoto != null && !rawPhoto.startsWith('http') && rawPhoto.length > 50
                  ? rawPhoto
                  : null);

          name = data['name']?.toString();
          accId = data['accountId']?.toString() ?? data['memberId']?.toString();
          phone = data['phone']?.toString();
        }

        // If lawyer, check lawyers collection as well for latest photo/name
        if (_detectedOtherRole == 'lawyer' || widget.otherUserRole == 'lawyer' || widget.lawyerUid != null || r == 'lawyer') {
          try {
            final lDoc = await FirebaseFirestore.instance
                .collection('lawyers')
                .doc(targetUid)
                .get()
                .timeout(const Duration(seconds: 4));

            if (lDoc.exists && lDoc.data() != null) {
              final lData = lDoc.data()!;
              final lRawPhoto = lData['photo']?.toString();
              final lPhotoUrl = lData['photoUrl']?.toString() ??
                  lData['user_profile_photo_url']?.toString() ??
                  lData['imageUrl']?.toString() ??
                  (lRawPhoto != null && (lRawPhoto.startsWith('http') || lRawPhoto.startsWith('data:image'))
                      ? lRawPhoto
                      : null);

              final lPhotoBase64 = lData['photoBase64']?.toString() ??
                  lData['user_profile_photo_base64']?.toString() ??
                  lData['user_profile_photo']?.toString() ??
                  (lRawPhoto != null && !lRawPhoto.startsWith('http') && lRawPhoto.length > 50
                      ? lRawPhoto
                      : null);

              if (lPhotoUrl != null && lPhotoUrl.isNotEmpty) photoUrl = lPhotoUrl;
              if (lPhotoBase64 != null && lPhotoBase64.isNotEmpty) photoBase64 = lPhotoBase64;
              if (lData['name'] != null && lData['name'].toString().isNotEmpty) name = lData['name']?.toString();
              if (lData['accountId'] != null && lData['accountId'].toString().isNotEmpty) accId = lData['accountId']?.toString();
              if (lData['phone'] != null && lData['phone'].toString().isNotEmpty) phone = lData['phone']?.toString();
            }
          } catch (_) {}
        }

        // Additional phone_directory fallback if photo or details are missing
        if (photoUrl == null && photoBase64 == null) {
          final fallbackPhone = _activeChat?.getOtherPartyPhone(_currentUserId) ?? phone;
          final cleanPhone = fallbackPhone != null ? PhoneUtils.normalize(fallbackPhone) : '';
          if (cleanPhone.isNotEmpty) {
            try {
              final dirDoc = await FirebaseFirestore.instance
                  .collection('phone_directory')
                  .doc(cleanPhone)
                  .get()
                  .timeout(const Duration(seconds: 3));
              if (dirDoc.exists && dirDoc.data() != null) {
                final dData = dirDoc.data()!;
                final dRawPhoto = dData['photo']?.toString();
                photoUrl = dData['photoUrl']?.toString() ??
                    dData['user_profile_photo_url']?.toString() ??
                    (dRawPhoto != null && (dRawPhoto.startsWith('http') || dRawPhoto.startsWith('data:image')) ? dRawPhoto : null);
                photoBase64 = dData['photoBase64']?.toString() ??
                    dData['user_profile_photo_base64']?.toString() ??
                    (dRawPhoto != null && !dRawPhoto.startsWith('http') && dRawPhoto.length > 50 ? dRawPhoto : null);
                if (name == null || name.isEmpty) name = dData['name']?.toString();
                if (accId == null || accId.isEmpty) accId = dData['accountId']?.toString();
              }
            } catch (_) {}
          }
        }

        if (mounted) {
          setState(() {
            if (r != null && r.isNotEmpty) _detectedOtherRole = r;
            if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != 'default') _liveOtherPhotoUrl = photoUrl;
            if (photoBase64 != null && photoBase64.isNotEmpty && photoBase64 != 'default') _liveOtherPhotoBase64 = photoBase64;
            if (name != null && name.isNotEmpty) _liveOtherName = name;
            if (accId != null && accId.isNotEmpty) _liveOtherAccountId = accId;
            if (phone != null && phone.isNotEmpty) _liveOtherPhone = phone;
          });
        }

        // Keep parent chat document in sync with the other party's latest photo/name
        if (_activeChat != null) {
          final isOtherLawyer = (_detectedOtherRole == 'lawyer' || widget.otherUserRole == 'lawyer');
          final Map<String, dynamic> chatUpdates = {};
          if (isOtherLawyer) {
            if (photoUrl != null && photoUrl.isNotEmpty && _activeChat!.lawyerPhoto != photoUrl) {
              chatUpdates['lawyerPhoto'] = photoUrl;
            }
            if (photoBase64 != null && photoBase64.isNotEmpty && _activeChat!.lawyerPhotoBase64 != photoBase64) {
              chatUpdates['lawyerPhotoBase64'] = photoBase64;
            }
            if (name != null && name.isNotEmpty && _activeChat!.lawyerName != name) {
              chatUpdates['lawyerName'] = name;
            }
          } else {
            if (photoUrl != null && photoUrl.isNotEmpty && _activeChat!.clientPhoto != photoUrl) {
              chatUpdates['clientPhoto'] = photoUrl;
            }
            if (photoBase64 != null && photoBase64.isNotEmpty && _activeChat!.clientPhotoBase64 != photoBase64) {
              chatUpdates['clientPhotoBase64'] = photoBase64;
            }
            if (name != null && name.isNotEmpty && _activeChat!.clientName != name) {
              chatUpdates['clientName'] = name;
            }
          }
          if (chatUpdates.isNotEmpty) {
            unawaited(FirebaseFirestore.instance.collection('chats').doc(_activeChat!.id).set(
              chatUpdates,
              SetOptions(merge: true),
            ).catchError((_) {}));
          }
        }
      }
    } catch (e) {
      debugPrint('[ChatScreen] _fetchOtherPartyInfoIfNeeded: $e');
    }
  }

  Future<void> _initChat() async {
    final authUser = FirebaseAuth.instance.currentUser;
    Map<String, dynamic>? session;
    try {
      session = await AuthService().getSavedSession();
    } catch (_) {}

    _currentUserId = widget.currentUserId ?? authUser?.uid ?? session?['uid'] ?? '';
    _currentUserRole = widget.currentUserRole ?? session?['role'] ?? 'client';
    _currentUserName = widget.currentUserName ?? session?['name'] ?? (authUser?.displayName ?? 'المستخدم');
    _currentUserAccountId = widget.currentUserAccountId ?? session?['accountId'] ?? '';

    // Initialize live image state from widget parameters if available
    _liveOtherPhotoUrl = widget.clientPhotoUrl ?? widget.lawyerPhotoUrl;
    _liveOtherPhotoBase64 = widget.clientPhotoBase64 ?? widget.lawyerPhotoBase64;

    if (widget.chat != null) {
      _activeChat = widget.chat;
      NotificationService.activeChatId = widget.chat!.id;
      _setupChatDocListener(widget.chat!.id);
      _updateMessagesStream();
      if (mounted) setState(() {});
      _markRead();
      _fetchOtherPartyInfoIfNeeded();
      return;
    }

    String targetLawyerUid = widget.lawyerUid ?? '';
    String targetClientUid = widget.clientUid ?? '';
    if (targetLawyerUid.isEmpty && targetClientUid.isEmpty) {
      if (widget.otherUserRole == 'lawyer') {
        targetLawyerUid = widget.otherUserUid ?? '';
      } else {
        targetClientUid = widget.otherUserUid ?? '';
      }
    }

    // Determine the participant roles properly
    String effectiveClientUid;
    String effectiveLawyerUid;

    if (targetLawyerUid.isNotEmpty) {
      effectiveLawyerUid = targetLawyerUid;
      effectiveClientUid = _currentUserId;
    } else if (targetClientUid.isNotEmpty) {
      effectiveClientUid = targetClientUid;
      effectiveLawyerUid = _currentUserId;
    } else {
      effectiveClientUid = _currentUserId;
      effectiveLawyerUid = widget.otherUserUid ?? '';
    }

    // Optimistic chat model for instantaneous screen rendering
    _activeChat = ChatModel(
      id: ChatService.generateChatId(effectiveClientUid, effectiveLawyerUid),
      participants: [effectiveClientUid, effectiveLawyerUid],
      clientId: effectiveClientUid,
      clientName: widget.clientName ?? (effectiveClientUid == _currentUserId ? _currentUserName : 'عميل'),
      clientPhone: widget.clientPhone ?? '',
      clientPhoto: widget.clientPhotoUrl,
      clientAccountId: widget.clientAccountId ?? (effectiveClientUid == _currentUserId ? _currentUserAccountId : ''),
      lawyerId: effectiveLawyerUid,
      lawyerName: widget.lawyerName ?? (effectiveLawyerUid == _currentUserId ? _currentUserName : 'محامٍ'),
      lawyerPhone: widget.lawyerPhone ?? '',
      lawyerPhoto: widget.lawyerPhotoUrl,
      lawyerAccountId: widget.lawyerAccountId ?? (effectiveLawyerUid == _currentUserId ? _currentUserAccountId : ''),
      lastMessage: 'مرحباً، تم بدء المحادثة',
      lastSenderId: _currentUserId,
      lastSenderName: _currentUserName,
      lastMessageTime: DateTime.now(),
    );
    NotificationService.activeChatId = _activeChat!.id;
    _setupChatDocListener(_activeChat!.id);
    _updateMessagesStream();
    if (mounted) setState(() {});
    _markRead();
    _fetchOtherPartyInfoIfNeeded();

    if (authUser == null) {
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get().timeout(const Duration(seconds: 4));
      final userData = userDoc.data() ?? {};
      if (_currentUserName == 'المستخدم') {
        _currentUserName = userData['name']?.toString() ?? 'المستخدم';
      }
      if (_currentUserAccountId.isEmpty) {
        _currentUserAccountId = userData['accountId']?.toString() ?? '';
      }

      UserModel clientModel;
      LawyerModel lawyerModel;

      if (targetLawyerUid.isNotEmpty) {
        final clientPhoto = widget.clientPhotoUrl ??
            userData['photoUrl']?.toString() ??
            userData['user_profile_photo_url']?.toString() ??
            userData['photo']?.toString();
        final clientBase64 = widget.clientPhotoBase64 ??
            userData['photoBase64']?.toString() ??
            userData['user_profile_photo_base64']?.toString();

        clientModel = UserModel(
          uid: _currentUserId,
          name: _currentUserName,
          phone: userData['phone']?.toString() ?? '',
          role: _currentUserRole,
          accountId: _currentUserAccountId,
          photoUrl: clientPhoto,
          photoBase64: clientBase64,
        );

        final lDoc = await FirebaseFirestore.instance.collection('lawyers').doc(targetLawyerUid).get().timeout(const Duration(seconds: 4));
        final lData = lDoc.data() ?? {};
        final lawyerPhoto = widget.lawyerPhotoUrl ??
            lData['photoUrl']?.toString() ??
            lData['user_profile_photo_url']?.toString() ??
            lData['photo']?.toString();
        final lawyerBase64 = widget.lawyerPhotoBase64 ??
            lData['photoBase64']?.toString() ??
            lData['user_profile_photo_base64']?.toString();

        lawyerModel = LawyerModel(
          uid: targetLawyerUid,
          name: widget.lawyerName ?? lData['name']?.toString() ?? 'محامٍ',
          phone: widget.lawyerPhone ?? lData['phone']?.toString() ?? '',
          whatsapp: lData['whatsapp']?.toString() ?? '',
          city: lData['city']?.toString() ?? 'السودان',
          accountId: widget.lawyerAccountId ?? lData['accountId']?.toString() ?? '',
          photoUrl: lawyerPhoto,
          photoBase64: lawyerBase64,
          status: 'approved',
        );
      } else {
        final cDoc = await FirebaseFirestore.instance.collection('users').doc(targetClientUid).get().timeout(const Duration(seconds: 4));
        final cData = cDoc.data() ?? {};
        final clientPhoto = widget.clientPhotoUrl ??
            cData['photoUrl']?.toString() ??
            cData['user_profile_photo_url']?.toString() ??
            cData['photo']?.toString();
        final clientBase64 = widget.clientPhotoBase64 ??
            cData['photoBase64']?.toString() ??
            cData['user_profile_photo_base64']?.toString();

        clientModel = UserModel(
          uid: targetClientUid,
          name: widget.clientName ?? cData['name']?.toString() ?? 'عميل',
          phone: widget.clientPhone ?? cData['phone']?.toString() ?? '',
          role: 'client',
          accountId: widget.clientAccountId ?? cData['accountId']?.toString() ?? '',
          photoUrl: clientPhoto,
          photoBase64: clientBase64,
        );

        Map<String, dynamic> lData = {};
        try {
          final lDoc = await FirebaseFirestore.instance.collection('lawyers').doc(_currentUserId).get().timeout(const Duration(seconds: 3));
          lData = lDoc.data() ?? {};
        } catch (_) {}

        lawyerModel = LawyerModel(
          uid: _currentUserId,
          name: _currentUserName,
          phone: lData['phone']?.toString() ?? userData['phone']?.toString() ?? '',
          whatsapp: lData['whatsapp']?.toString() ?? '',
          city: lData['city']?.toString() ?? 'السودان',
          accountId: _currentUserAccountId,
          status: 'approved',
        );
      }

      final chat = await _chatService.getOrCreateChat(
        client: clientModel,
        lawyer: lawyerModel,
      );

      if (mounted) {
        setState(() {
          _activeChat = chat;
        });
        NotificationService.activeChatId = chat.id;
        _setupChatDocListener(chat.id);
        _markRead();
        _fetchOtherPartyInfoIfNeeded();
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error background initializing chat: $e');
    }
  }

  @override
  void dispose() {
    _chatDocSubscription?.cancel();
    if (NotificationService.activeChatId == _activeChat?.id) {
      NotificationService.activeChatId = null;
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openOtherProfile() {
    if (_activeChat == null) return;
    final otherName = _activeChat!.getOtherPartyName(_currentUserId);
    final otherPhoto = _activeChat!.getOtherPartyPhoto(_currentUserId);
    final otherAccountId = _activeChat!.getOtherPartyAccountId(_currentUserId);
    final otherPhone = _activeChat!.getOtherPartyPhone(_currentUserId);
    final otherRole = _detectedOtherRole.isNotEmpty
        ? _detectedOtherRole
        : (widget.otherUserRole ?? _activeChat!.getOtherPartyRole(_currentUserId));
    final displayOtherName = _liveOtherName ?? (otherName.isNotEmpty ? otherName : 'مستخدم المنصة');

    final otherUid = _activeChat?.getOtherPartyUid(_currentUserId) ?? '';
    final targetUid = otherUid.isNotEmpty
        ? otherUid
        : (widget.lawyerUid ?? widget.clientUid ?? widget.otherUserUid ?? '');
    final fallbackName = displayOtherName;
    final fallbackPhone = otherRole == 'admin' ? '' : (_liveOtherPhone ?? otherPhone);
    final fallbackPhoto = _liveOtherPhotoUrl ?? otherPhoto ?? widget.clientPhotoUrl ?? widget.lawyerPhotoUrl;
    final fallbackPhotoBase64 = _liveOtherPhotoBase64 ?? widget.clientPhotoBase64 ?? widget.lawyerPhotoBase64;
    final fallbackAccountId = _liveOtherAccountId ?? (otherAccountId.isNotEmpty ? otherAccountId : (widget.clientAccountId ?? widget.lawyerAccountId ?? widget.otherUserAccountId ?? ''));

    ProfileDetailsModal.showProfileByUid(
      context,
      uid: targetUid,
      role: otherRole,
      fallbackName: fallbackName,
      fallbackPhone: fallbackPhone,
      fallbackPhoto: fallbackPhoto,
      fallbackPhotoBase64: fallbackPhotoBase64,
      fallbackAccountId: fallbackAccountId,
      isAdmin: _currentUserRole == 'admin',
    );
  }

  Future<void> _togglePinChat() async {
    if (_activeChat == null || _currentUserId.isEmpty) return;
    final nextState = !_isPinned;
    setState(() => _isPinned = nextState);
    try {
      await _chatService.togglePinChat(
        chatId: _activeChat!.id,
        currentUserId: _currentUserId,
        pin: nextState,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextState ? 'تم تثبيت المحادثة في الأعلى 📌' : 'تم إلغاء تثبيت المحادثة',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
            ),
            backgroundColor: const Color(0xFF0B2A5B),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChatScreen] togglePin error: $e');
    }
  }

  Future<void> _toggleStopUser() async {
    if (_activeChat == null || _currentUserId.isEmpty) return;
    // Dismiss keyboard immediately to prevent IME deadlock during widget tree swapping
    FocusScope.of(context).unfocus();
    final nextState = !_isStoppedByMe;
    setState(() => _isStoppedByMe = nextState);
    try {
      await _chatService.toggleStopChat(
        chatId: _activeChat!.id,
        currentUserId: _currentUserId,
        stop: nextState,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              nextState
                  ? 'تم إيقاف هذا الحساب ⏸️ (لن تصلك أي رسائل أو إشعارات منه)'
                  : 'تم تنشيط المحادثة مع هذا الحساب بنجاح ▶️',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
            backgroundColor: nextState ? const Color(0xFF991B1B) : const Color(0xFF0B2A5B),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[ChatScreen] toggleStopUser error: $e');
    }
  }

  Future<void> _markRead() async {
    // Don't mark messages as read if we've stopped this user — their messages
    // are already hidden (deletedFor) and should not show as seen.
    if (_activeChat == null || _isStoppedByMe || _currentUserId.isEmpty || _isMarkingRead) return;
    _isMarkingRead = true;
    try {
      await _chatService.markChatAsRead(
        chatId: _activeChat!.id,
        currentUserId: _currentUserId,
        currentUserRole: _currentUserRole,
      );
    } catch (_) {
    } finally {
      _isMarkingRead = false;
    }
  }

  void _onReplyToMessage(ChatMessageModel message) {
    if (message.isDeletedForEveryone) return;
    setState(() {
      _replyingTo = message;
    });
    _focusNode.requestFocus();
  }

  void _showDeleteDialog(ChatMessageModel message) {
    final isMe = message.senderId == _currentUserId;
    final diff = DateTime.now().difference(message.createdAt);
    // 1-minute (60 seconds) window for Delete for Everyone
    final canDeleteForEveryone = isMe && !message.isDeletedForEveryone && diff.inSeconds <= 60;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'خيارات حذف الرسالة',
                      style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  canDeleteForEveryone
                      ? 'الرسالة أُرسلت منذ أقل من دقيقة. يمكنك حذفها لدى جميع أطراف المحادثة أو حذفها من عندك فقط.'
                      : 'سيتم حذف هذه الرسالة من محادثتك فقط ولن تظهر لك مجدداً.',
                  style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 20),

                if (canDeleteForEveryone) ...[
                  // Delete for Everyone Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          await _chatService.deleteMessageForEveryone(
                            chatId: _activeChat!.id,
                            messageId: message.id,
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم حذف الرسالة لدى الجميع', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                                backgroundColor: const Color(0xFF0B2A5B),
                              ),
                            );
                          }
                        } catch (e) {
                          debugPrint('[ChatScreen] deleteMessageForEveryone err: $e');
                        }
                      },
                      icon: const Icon(Icons.public_off_rounded, size: 18),
                      label: Text('الحذف لدى الجميع', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],

                // Delete for Me Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      try {
                        await _chatService.deleteMessageForMe(
                          chatId: _activeChat!.id,
                          messageId: message.id,
                          currentUserId: _currentUserId,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم حذف الرسالة من عندك', style: GoogleFonts.cairo(fontWeight: FontWeight.w600)),
                              backgroundColor: const Color(0xFF64748B),
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('[ChatScreen] deleteMessageForMe err: $e');
                      }
                    },
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey.shade800),
                    label: Text('الحذف لدي فقط', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14, color: const Color(0xFF0F172A))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Cancel Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSend() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending || _activeChat == null || _isStoppedByMe) return;

    final replying = _replyingTo;
    setState(() {
      _isSending = true;
      _replyingTo = null; // Clear reply bar immediately for fluid UX
    });
    _msgCtrl.clear();

    try {
      final activeUserId = _currentUserId.isNotEmpty
          ? _currentUserId
          : (FirebaseAuth.instance.currentUser?.uid ?? '');

      String recipientId = '';

      // 1. Direct explicit target from widget arguments (highest priority)
      if (widget.clientUid != null && widget.clientUid!.trim().isNotEmpty && widget.clientUid!.trim() != activeUserId) {
        recipientId = widget.clientUid!.trim();
      } else if (widget.lawyerUid != null && widget.lawyerUid!.trim().isNotEmpty && widget.lawyerUid!.trim() != activeUserId) {
        recipientId = widget.lawyerUid!.trim();
      } else if (widget.otherUserUid != null && widget.otherUserUid!.trim().isNotEmpty && widget.otherUserUid!.trim() != activeUserId) {
        recipientId = widget.otherUserUid!.trim();
      }

      // 2. Resolve from participants in active chat
      if (recipientId.isEmpty && _activeChat != null) {
        final otherParticipants = _activeChat!.participants
            .where((p) => p.trim().isNotEmpty && p.trim() != activeUserId)
            .toList();
        if (otherParticipants.isNotEmpty) {
          recipientId = otherParticipants.first.trim();
        }
      }

      // 3. Fallback to clientId/lawyerId properties
      if (recipientId.isEmpty && _activeChat != null) {
        if (_activeChat!.clientId.trim().isNotEmpty && _activeChat!.clientId.trim() != activeUserId) {
          recipientId = _activeChat!.clientId.trim();
        } else if (_activeChat!.lawyerId.trim().isNotEmpty && _activeChat!.lawyerId.trim() != activeUserId) {
          recipientId = _activeChat!.lawyerId.trim();
        }
      }

      // 4. Strict safety guard: never allow self notification
      if (recipientId == activeUserId) {
        debugPrint('[ChatScreen] Warning: recipientId matches sender ($activeUserId). Notification to self aborted.');
        recipientId = '';
      }

      String? replySenderName;
      if (replying != null) {
        if (replying.isAdminSender || replying.senderRole == 'admin') {
          replySenderName = 'مشرف المنصة';
        } else if (replying.senderId == activeUserId) {
          replySenderName = 'أنت';
        } else {
          replySenderName = replying.senderName;
        }
      }

      await _chatService.sendMessage(
        chatId: _activeChat!.id,
        senderId: activeUserId,
        senderName: _currentUserName,
        senderRole: _currentUserRole,
        senderAccountId: _currentUserAccountId,
        text: text,
        recipientId: recipientId,
        replyToMessageId: replying?.id,
        replyToText: replying?.text,
        replyToSenderName: replySenderName,
      );
    } catch (e) {
      debugPrint('[ChatScreen] sendMessage error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر إرسال الرسالة، يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              textDirection: TextDirection.rtl,
            ),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _callOtherParty(String phone) async {
    if (phone.trim().isEmpty) return;
    final normalized = PhoneUtils.tryNormalize(phone) ?? phone;
    final uri = Uri.parse('tel:$normalized');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF0B2A5B);
    const Color brandGold = Color(0xFFD49B1A);
    const Color chatBg = Color(0xFFF8FAFC);

    if (_activeChat == null) {
      return Scaffold(
        backgroundColor: chatBg,
        appBar: AppBar(
          backgroundColor: brandNavy,
          elevation: 1,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'المحادثة المباشرة',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                const SizedBox(height: 12),
                Text(
                  'تعذر فتح المحادثة، يرجى المحاولة مجدداً',
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('رجوع', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final otherName = _activeChat!.getOtherPartyName(_currentUserId);
    final otherPhoto = _activeChat!.getOtherPartyPhoto(_currentUserId);
    final otherPhone = _activeChat!.getOtherPartyPhone(_currentUserId);
    final otherRole = _detectedOtherRole.isNotEmpty
        ? _detectedOtherRole
        : (widget.otherUserRole ?? _activeChat!.getOtherPartyRole(_currentUserId));

    final displayOtherName = _liveOtherName ?? (otherName.isNotEmpty ? otherName : 'مستخدم المنصة');

    return Scaffold(
      backgroundColor: chatBg,
      appBar: AppBar(
        backgroundColor: brandNavy,
        elevation: 2,
        shadowColor: brandNavy.withValues(alpha: 0.3),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: _openOtherProfile,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                // Avatar with Live Client/Lawyer Photo Support
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: brandGold.withValues(alpha: 0.7), width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      width: 38,
                      height: 38,
                      color: brandGold.withValues(alpha: 0.2),
                      child: AppImageUtils.buildAvatarImage(
                        photoBase64: _liveOtherPhotoBase64 ?? widget.clientPhotoBase64 ?? widget.lawyerPhotoBase64,
                        photoUrl: _liveOtherPhotoUrl ?? otherPhoto ?? widget.clientPhotoUrl ?? widget.lawyerPhotoUrl,
                        width: 38,
                        height: 38,
                        fallback: Center(
                          child: Text(
                            displayOtherName.isNotEmpty ? displayOtherName.substring(0, 1) : 'م',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Name and Subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              displayOtherName,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 5),
                          _buildRoleBadge(otherRole),
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'اضغط لعرض الملف الشخصي',
                        style: GoogleFonts.cairo(
                          fontSize: 9.5,
                          color: Colors.white.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          // Pin / Unpin Action (Gold filled when pinned, white outline when unpinned)
          IconButton(
            icon: Icon(
              _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              color: _isPinned ? brandGold : Colors.white,
              size: 20,
            ),
            tooltip: _isPinned ? 'إلغاء تثبيت المحادثة' : 'تثبيت المحادثة في الأعلى',
            onPressed: _togglePinChat,
          ),

          // Stop / Pause User Action (Red filled when stopped, white outline when active)
          IconButton(
            icon: Icon(
              _isStoppedByMe ? Icons.pause_circle_filled_rounded : Icons.pause_circle_outline_rounded,
              color: _isStoppedByMe ? const Color(0xFFF87171) : Colors.white,
              size: 21,
            ),
            tooltip: _isStoppedByMe ? 'تنشيط الحساب وإلغاء الإيقاف' : 'إيقاف هذا المستخدم ومنع وصول رسائله',
            onPressed: _toggleStopUser,
          ),

          // Call Action if available AND NOT an Admin/Supervisor AND not stopped
          if (otherPhone.isNotEmpty && otherRole != 'admin' && !_isStoppedByMe)
            IconButton(
              icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 20),
              tooltip: 'اتصال هاتفياً',
              onPressed: () => _callOtherParty(otherPhone),
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // If the chat is stopped by me, show the stopped UI in the center
            if (_isStoppedByMe)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3), width: 2),
                          ),
                          child: const Icon(
                            Icons.pause_circle_filled_rounded,
                            size: 56,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'تم إيقاف هذا الحساب',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'لن تصلك أي رسائل أو إشعارات من هذا الشخص.\nاضغط على "تنشيط" لاستئناف المحادثة في أي وقت.',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: const Color(0xFF64748B),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _toggleStopUser,
                          icon: const Icon(Icons.play_circle_outline_rounded, size: 20),
                          label: Text(
                            'تنشيط الحساب',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: brandGold,
                            foregroundColor: brandNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else ...[
              // Messages Stream Area
              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  initialData: const <ChatMessageModel>[],
                  stream: _messagesStream ?? (_activeChat != null ? _chatService.getMessagesStream(_activeChat!.id, currentUserId: _currentUserId) : const Stream.empty()),
                  builder: (context, snapshot) {
                    final messages = snapshot.data ?? [];
                    if (!_isStoppedByMe && !_isMarkingRead && messages.any((m) => m.senderId != _currentUserId && !m.isRead)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
                    }

                    if (messages.isEmpty) {
                      if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
                        return const Center(
                          child: CircularProgressIndicator(color: brandNavy),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.wifi_off_rounded, size: 40, color: Color(0xFF94A3B8)),
                                const SizedBox(height: 10),
                                Text(
                                  'تعذر تحميل الرسائل، يرجى التأكد من اتصالك بالإنترنت.',
                                  style: GoogleFonts.cairo(fontSize: 13.5, color: const Color(0xFF64748B)),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: brandNavy.withValues(alpha: 0.06),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 44,
                                  color: brandNavy,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'محادثة آمنة ومباشرة',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: brandNavy,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'اسحب الرسالة لليسار للرد، أو لليمين للحذف.\nالمحادثة مشفرة ومحمية ضمن سياسة المنصة.',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  color: const Color(0xFF64748B),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollCtrl,
                      reverse: true, // newest messages at the bottom
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final message = messages[index];
                        final isMe = message.senderId == _currentUserId;

                        return _buildDismissibleBubble(message, isMe);
                      },
                    );
                  },
                ),
              ),

              // Active Reply Bar (shown when swiping left or clicking reply)
              _buildReplyBar(),

              // Bottom Input Bar
              _buildInputBar(brandNavy, brandGold),
            ],

          ],
        ),
      ),
    );
  }

  /// Wraps message bubble with Dismissible for Swipe Left (Reply) & Swipe Right (Delete)
  Widget _buildDismissibleBubble(ChatMessageModel message, bool isMe) {
    // In RTL context:
    // startToEnd = dragging from Right to Left (سحب للشمال) -> REPLY
    // endToStart = dragging from Left to Right (سحب لليمين) -> DELETE
    return Dismissible(
      key: ValueKey('msg_${message.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        final isRtl = Directionality.of(context) == TextDirection.rtl;
        final isDragLeft = isRtl
            ? (direction == DismissDirection.startToEnd)
            : (direction == DismissDirection.endToStart);

        if (isDragLeft) {
          // Swipe Left: Reply
          _onReplyToMessage(message);
          return false; // do not remove from list
        } else {
          // Swipe Right: Delete
          _showDeleteDialog(message);
          return false; // do not remove from list
        }
      },
      // When dragging Right to Left (Reply in RTL)
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2A5B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.reply_rounded, color: Color(0xFF0B2A5B), size: 24),
            const SizedBox(width: 8),
            Text(
              'رد',
              style: GoogleFonts.cairo(color: const Color(0xFF0B2A5B), fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
      ),
      // When dragging Left to Right (Delete in RTL)
      secondaryBackground: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        margin: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'حذف',
              style: GoogleFonts.cairo(color: Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 24),
          ],
        ),
      ),
      child: InkWell(
        onLongPress: () {
          _showActionMenu(message);
        },
        borderRadius: BorderRadius.circular(18),
        child: _buildMessageBubble(message, isMe),
      ),
    );
  }

  void _showActionMenu(ChatMessageModel message) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (!message.isDeletedForEveryone)
                  ListTile(
                    leading: const Icon(Icons.reply_rounded, color: Color(0xFF0B2A5B)),
                    title: Text('رد على هذه الرسالة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _onReplyToMessage(message);
                    },
                  ),
                ListTile(
                  leading: Icon(Icons.delete_outline_rounded, color: Colors.red.shade700),
                  title: Text('حذف الرسالة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, color: Colors.red.shade700)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showDeleteDialog(message);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReplyBar() {
    if (_replyingTo == null) return const SizedBox.shrink();

    final isReplyAdmin = _replyingTo!.isAdminSender || _replyingTo!.senderRole == 'admin';
    final replySenderTitle = isReplyAdmin
        ? 'مشرف المنصة 🛡️'
        : (_replyingTo!.senderId == _currentUserId ? 'أنت' : _replyingTo!.senderName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        border: Border(
          top: BorderSide(color: Colors.grey.shade300, width: 0.8),
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.8),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 36,
            decoration: BoxDecoration(
              color: isReplyAdmin ? const Color(0xFFD49B1A) : const Color(0xFF0B2A5B),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.reply_rounded, size: 14, color: Color(0xFF0B2A5B)),
                    const SizedBox(width: 4),
                    Text(
                      'الرد على $replySenderTitle',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _replyingTo!.text,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
            onPressed: () {
              setState(() {
                _replyingTo = null;
              });
            },
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime dt) {
    try {
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'م' : 'ص';
      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  Widget _buildRoleBadge(String role) {
    if (role == 'admin') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD49B1A), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFD49B1A).withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_rounded, size: 12, color: Color(0xFF92400E)),
            const SizedBox(width: 3),
            Text(
              'مشرف',
              style: GoogleFonts.cairo(
                fontSize: 10,
                color: const Color(0xFF92400E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    if (role == 'lawyer') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFD49B1A),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'محامٍ ⚖️',
          style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFF0B2A5B), fontWeight: FontWeight.w800),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'عميل 👤',
        style: GoogleFonts.cairo(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Builds Message Bubble with Native Arabic RTL Alignment:
  /// Sent by Me (`isMe`): Placed on the LEFT (`Alignment.centerLeft`), pointy bottom-left corner.
  /// Received from Other: Placed on the RIGHT (`Alignment.centerRight`), pointy bottom-right corner.
  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    const Color brandNavy = Color(0xFF0B2A5B);
    const Color brandGold = Color(0xFFD49B1A);
    final isSpecialAdmin = message.isAdminSender || message.senderRole == 'admin';

    final timeStr = _formatMessageTime(message.createdAt);

    return Align(
      // Native Arabic layout: Sent messages on the LEFT, Incoming on the RIGHT
      alignment: isMe ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.80,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? (isSpecialAdmin ? const Color(0xFF0A1E3F) : brandNavy)
              : (isSpecialAdmin ? const Color(0xFFFFFBEB) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            // In Arabic RTL: Sent message pointy corner is on the bottom-left, incoming on bottom-right
            bottomLeft: Radius.circular(isMe ? 4 : 18),
            bottomRight: Radius.circular(isMe ? 18 : 4),
          ),
          border: Border.all(
            color: isSpecialAdmin
                ? brandGold
                : (isMe ? Colors.transparent : const Color(0xFFE2E8F0)),
            width: isSpecialAdmin ? 1.6 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isSpecialAdmin
                  ? brandGold.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: isSpecialAdmin ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Prominent official Supervisor badge if message is from Admin
            if (isSpecialAdmin) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? null
                      : const LinearGradient(
                          colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                        ),
                  color: isMe ? brandGold.withValues(alpha: 0.25) : null,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: brandGold,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 13,
                      color: isMe ? const Color(0xFFFBBF24) : const Color(0xFF92400E),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isMe ? 'مشرف المنصة' : 'إدارة المنصة • مشرف',
                      style: GoogleFonts.cairo(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isMe ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Quoted Reply Card
            if (message.replyToText != null && message.replyToText!.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe ? Colors.black.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    right: BorderSide(
                      color: isMe ? brandGold : brandNavy,
                      width: 3.5,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message.replyToSenderName ?? 'رسالة',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isMe ? const Color(0xFFFDE68A) : brandNavy,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.replyToText!,
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        color: isMe ? Colors.white70 : const Color(0xFF475569),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],

            // Message text or Deleted indicator
            if (message.isDeletedForEveryone) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: 14,
                    color: isMe ? Colors.white60 : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'تم حذف هذه الرسالة',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isMe ? Colors.white70 : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ] else ...[
              SelectableText(
                message.text,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  color: isMe ? Colors.white : const Color(0xFF1E293B),
                  height: 1.45,
                  fontWeight: isSpecialAdmin && !isMe ? FontWeight.w600 : FontWeight.normal,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
            const SizedBox(height: 4),

            // Timestamp & Read indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isMe ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: GoogleFonts.cairo(
                    fontSize: 10,
                    color: isMe ? const Color(0xFFCBD5E1) : const Color(0xFF94A3B8),
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all_rounded : Icons.done_rounded,
                    size: 15,
                    color: message.isRead ? const Color(0xFF38BDF8) : Colors.white60,
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildInputBar(Color brandNavy, Color brandGold) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: const Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Send Button
          InkWell(
            onTap: _handleSend,
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: brandNavy,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: brandNavy.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _isSending
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  : const Center(
                      child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    ),
            ),
          ),
          const SizedBox(width: 10),

          // Text Field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _msgCtrl,
                focusNode: _focusNode,
                maxLines: 4,
                minLines: 1,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: _replyingTo != null ? 'اكتب ردك هنا...' : 'اكتب رسالتك هنا...',
                  hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onSubmitted: (_) => _handleSend(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
