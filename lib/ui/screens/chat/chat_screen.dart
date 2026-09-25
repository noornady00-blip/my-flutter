// ==============================================================================
// 💬 CHAT CONVERSATION SCREEN
// ==============================================================================
// WhatsApp-familiar simplicity tailored to Mahameek's Royal Navy & Gold branding.
// Features real-time Firestore synchronization, 12-digit account ID display,
// network disconnection handling, and empty message guards.
// ==============================================================================

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

  ChatModel? _activeChat;
  String _currentUserId = '';
  String _currentUserName = '';
  String _currentUserRole = 'client';
  String _currentUserAccountId = '';
  String _detectedOtherRole = '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    if (widget.chat != null) {
      _activeChat = widget.chat;
      NotificationService.activeChatId = widget.chat!.id;
    }
    _initChat();
  }

  Future<void> _fetchOtherPartyRoleIfNeeded() async {
    if (_activeChat == null) return;
    try {
      final otherUid = _activeChat!.getOtherPartyUid(_currentUserId);
      if (otherUid.isNotEmpty) {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(otherUid).get().timeout(const Duration(seconds: 3));
        if (uDoc.exists && uDoc.data() != null) {
          final r = uDoc.data()!['role']?.toString();
          if (r != null && r.isNotEmpty && mounted) {
            setState(() => _detectedOtherRole = r);
          }
        }
      }
    } catch (_) {}
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

    if (widget.chat != null) {
      _activeChat = widget.chat;
      NotificationService.activeChatId = widget.chat!.id;
      if (mounted) setState(() {});
      _markRead();
      _fetchOtherPartyRoleIfNeeded();
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
      // Current user is chatting with a lawyer
      effectiveLawyerUid = targetLawyerUid;
      effectiveClientUid = _currentUserId;
    } else if (targetClientUid.isNotEmpty) {
      // Current user is chatting with a client
      effectiveClientUid = targetClientUid;
      effectiveLawyerUid = _currentUserId;
    } else {
      effectiveClientUid = _currentUserId;
      effectiveLawyerUid = widget.otherUserUid ?? '';
    }

    // Synchronous optimistic chat model: allows the chat UI to render instantly without waiting for network
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
    if (mounted) setState(() {});
    _markRead();

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
        clientModel = UserModel(
          uid: _currentUserId,
          name: _currentUserName,
          phone: userData['phone']?.toString() ?? '',
          role: _currentUserRole,
          accountId: _currentUserAccountId,
        );

        final lDoc = await FirebaseFirestore.instance.collection('lawyers').doc(targetLawyerUid).get().timeout(const Duration(seconds: 4));
        final lData = lDoc.data() ?? {};
        lawyerModel = LawyerModel(
          uid: targetLawyerUid,
          name: widget.lawyerName ?? lData['name']?.toString() ?? 'محامٍ',
          phone: widget.lawyerPhone ?? lData['phone']?.toString() ?? '',
          whatsapp: lData['whatsapp']?.toString() ?? '',
          city: lData['city']?.toString() ?? 'السودان',
          accountId: widget.lawyerAccountId ?? lData['accountId']?.toString() ?? '',
          photoUrl: widget.lawyerPhotoUrl ?? lData['photoUrl']?.toString(),
          photoBase64: widget.lawyerPhotoBase64 ?? lData['photoBase64']?.toString(),
          status: 'approved',
        );
      } else {
        final cDoc = await FirebaseFirestore.instance.collection('users').doc(targetClientUid).get().timeout(const Duration(seconds: 4));
        final cData = cDoc.data() ?? {};
        clientModel = UserModel(
          uid: targetClientUid,
          name: widget.clientName ?? cData['name']?.toString() ?? 'عميل',
          phone: widget.clientPhone ?? cData['phone']?.toString() ?? '',
          role: 'client',
          accountId: widget.clientAccountId ?? cData['accountId']?.toString() ?? '',
          photoUrl: widget.clientPhotoUrl ?? cData['photoUrl']?.toString(),
          photoBase64: widget.clientPhotoBase64 ?? cData['photoBase64']?.toString(),
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
        _markRead();
        _fetchOtherPartyRoleIfNeeded();
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error background initializing chat: $e');
    }
  }

  @override
  void dispose() {
    if (NotificationService.activeChatId == _activeChat?.id) {
      NotificationService.activeChatId = null;
    }
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _markRead() {
    if (_activeChat == null) return;
    _chatService.markChatAsRead(
      chatId: _activeChat!.id,
      currentUserId: _currentUserId,
      currentUserRole: _currentUserRole,
    );
  }

  Future<void> _handleSend() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending || _activeChat == null) return;

    setState(() => _isSending = true);
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

      await _chatService.sendMessage(
        chatId: _activeChat!.id,
        senderId: activeUserId,
        senderName: _currentUserName,
        senderRole: _currentUserRole,
        senderAccountId: _currentUserAccountId,
        text: text,
        recipientId: recipientId,
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
    final normalized = PhoneUtils.normalizeSudanPhone(phone, withPlus: true);
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
    final otherAccountId = _activeChat!.getOtherPartyAccountId(_currentUserId);
    final otherPhone = _activeChat!.getOtherPartyPhone(_currentUserId);
    final otherRole = _detectedOtherRole.isNotEmpty
        ? _detectedOtherRole
        : (widget.otherUserRole ?? _activeChat!.getOtherPartyRole(_currentUserId));

    return Scaffold(
      backgroundColor: chatBg,
      appBar: AppBar(
        backgroundColor: brandNavy,
        elevation: 1,
        automaticallyImplyLeading: false,
        titleSpacing: 8,
        title: Row(
          children: [
            // Back Button
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
              onPressed: () => Navigator.of(context).pop(),
            ),

            // Avatar & Name with interactive profile opening (No ID shown)
            Expanded(
              child: InkWell(
                onTap: () {
                  final otherUid = _activeChat?.getOtherPartyUid(_currentUserId) ?? '';
                  final targetUid = otherUid.isNotEmpty
                      ? otherUid
                      : (widget.lawyerUid ?? widget.clientUid ?? widget.otherUserUid ?? '');
                  final fallbackName = otherName.isNotEmpty
                      ? otherName
                      : (widget.clientName ?? widget.lawyerName ?? widget.otherUserName ?? 'مستخدم المنصة');
                  final fallbackPhone = otherPhone.isNotEmpty
                      ? otherPhone
                      : (widget.clientPhone ?? widget.lawyerPhone ?? '');
                  final fallbackPhoto = otherPhoto ?? widget.clientPhotoUrl ?? widget.lawyerPhotoUrl;
                  final fallbackAccountId = otherAccountId.isNotEmpty
                      ? otherAccountId
                      : (widget.clientAccountId ?? widget.lawyerAccountId ?? widget.otherUserAccountId ?? '');

                  ProfileDetailsModal.showProfileByUid(
                    context,
                    uid: targetUid,
                    role: otherRole,
                    fallbackName: fallbackName,
                    fallbackPhone: fallbackPhone,
                    fallbackPhoto: fallbackPhoto,
                    fallbackAccountId: fallbackAccountId,
                    isAdmin: _currentUserRole == 'admin',
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      // Avatar
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: brandGold.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: 40,
                            height: 40,
                            color: brandGold.withValues(alpha: 0.2),
                            child: otherPhoto != null && otherPhoto.isNotEmpty
                                ? ImageUtils.buildSafeImage(
                                    photoUrl: otherPhoto,
                                    fit: BoxFit.cover,
                                  )
                                : Center(
                                    child: Text(
                                      otherName.isNotEmpty ? otherName.substring(0, 1) : 'م',
                                      style: GoogleFonts.cairo(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Name and Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    otherName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildRoleBadge(otherRole),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'اضغط لعرض الملف الشخصي',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10.5,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 9,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Call Action if available
            if (otherPhone.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.phone_rounded, color: Colors.white, size: 21),
                tooltip: 'اتصال هاتفياً',
                onPressed: () => _callOtherParty(otherPhone),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Messages Stream Area
            Expanded(
              child: StreamBuilder<List<ChatMessageModel>>(
                initialData: const <ChatMessageModel>[],
                stream: _chatService.getMessagesStream(_activeChat!.id),
                builder: (context, snapshot) {
                  final messages = snapshot.data ?? [];
                  if (messages.any((m) => m.senderId != _currentUserId && !m.isRead)) {
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
                              'ابدأ بإرسال رسالتك الأولى الآن. المحادثة مشفرة ومحمية ضمن سياسة المنصة.',
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
                    reverse: true, // newest messages at the bottom like WhatsApp
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      final isMe = message.senderId == _currentUserId;
                      return _buildMessageBubble(message, isMe);
                    },
                  );
                },
              ),
            ),

            // Bottom Input Bar
            _buildInputBar(brandNavy, brandGold),
          ],
        ),
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

  Widget _buildMessageBubble(ChatMessageModel message, bool isMe) {
    const Color brandNavy = Color(0xFF0B2A5B);
    const Color brandGold = Color(0xFFD49B1A);
    final isSpecialAdmin = message.isAdminSender || message.senderRole == 'admin';

    final timeStr = _formatMessageTime(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
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
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
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

            // Message text
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
            const SizedBox(height: 4),

            // Timestamp & Read indicator
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.end,
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
                    color: message.isRead ? const Color(0xFF22C55E) : Colors.white60,
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
                maxLines: 4,
                minLines: 1,
                textDirection: TextDirection.rtl,
                style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0F172A)),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالتك هنا...',
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
