// ==============================================================================
// 💬 CHAT CONVERSATION SCREEN
// ==============================================================================
// WhatsApp-familiar simplicity tailored to Mahameek's Royal Navy & Gold branding.
// Features real-time Firestore synchronization, 12-digit account ID display,
// network disconnection handling, and empty message guards.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import 'package:url_launcher/url_launcher.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../data/models/chat_model.dart';
import '../../../data/models/chat_message_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/chat_service.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/image_utils.dart';

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
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initChat();
  }

  Future<void> _initChat() async {
    if (widget.chat != null) {
      _activeChat = widget.chat;
      _currentUserId = widget.currentUserId ?? FirebaseAuth.instance.currentUser?.uid ?? '';
      _currentUserName = widget.currentUserName ?? 'المستخدم';
      _currentUserRole = widget.currentUserRole ?? 'client';
      _currentUserAccountId = widget.currentUserAccountId ?? '';
      _isLoading = false;
      if (mounted) setState(() {});
      _markRead();
      return;
    }

    final authUser = FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('يرجى تسجيل الدخول أولاً', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        Navigator.pop(context);
      }
      return;
    }

    _currentUserId = widget.currentUserId ?? authUser.uid;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(_currentUserId).get();
      final userData = userDoc.data() ?? {};
      _currentUserName = widget.currentUserName ?? userData['name']?.toString() ?? 'المستخدم';
      _currentUserRole = widget.currentUserRole ?? userData['role']?.toString() ?? 'client';
      _currentUserAccountId = widget.currentUserAccountId ?? userData['accountId']?.toString() ?? '';

      if (_currentUserRole == 'lawyer' && _currentUserAccountId.isEmpty) {
        final lawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(_currentUserId).get();
        _currentUserAccountId = lawyerDoc.data()?['accountId']?.toString() ?? '';
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

        final lDoc = await FirebaseFirestore.instance.collection('lawyers').doc(targetLawyerUid).get();
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
        final cDoc = await FirebaseFirestore.instance.collection('users').doc(targetClientUid).get();
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

        final lDoc = await FirebaseFirestore.instance.collection('lawyers').doc(_currentUserId).get();
        final lData = lDoc.data() ?? {};
        lawyerModel = LawyerModel(
          uid: _currentUserId,
          name: _currentUserName,
          phone: lData['phone']?.toString() ?? '',
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
          _isLoading = false;
        });
        _markRead();
      }
    } catch (e) {
      debugPrint('[ChatScreen] Error initializing chat: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
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
      final recipientId = _currentUserId == _activeChat!.clientId
          ? _activeChat!.lawyerId
          : _activeChat!.clientId;

      await _chatService.sendMessage(
        chatId: _activeChat!.id,
        senderId: _currentUserId,
        senderName: _currentUserName,
        senderRole: _currentUserRole,
        senderAccountId: _currentUserAccountId,
        text: text,
        recipientId: recipientId,
      );
    } catch (e) {
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

    if (_isLoading || _activeChat == null) {
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
        body: const Center(
          child: CircularProgressIndicator(color: brandNavy),
        ),
      );
    }

    final otherName = _activeChat!.getOtherPartyName(_currentUserId);
    final otherPhoto = _activeChat!.getOtherPartyPhoto(_currentUserId);
    final otherAccountId = _activeChat!.getOtherPartyAccountId(_currentUserId);
    final otherPhone = _activeChat!.getOtherPartyPhone(_currentUserId);
    final otherRole = _activeChat!.getOtherPartyRole(_currentUserId);

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

            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 42,
                height: 42,
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
            const SizedBox(width: 10),

            // Name and 12-digit Account ID
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
                  // 12-digit fixed ID chip
                  InkWell(
                    onTap: () {
                      if (otherAccountId.isNotEmpty) {
                        Clipboard.setData(ClipboardData(text: otherAccountId));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'تم نسخ معرّف الحساب: $otherAccountId',
                              style: GoogleFonts.cairo(fontSize: 13),
                              textDirection: TextDirection.rtl,
                            ),
                            backgroundColor: brandNavy,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          otherAccountId.isNotEmpty
                              ? 'معرّف: ${AccountIdUtils.formatDisplay(otherAccountId)}'
                              : 'معرّف الحساب موثق',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            color: brandGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (otherAccountId.isNotEmpty) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.copy_rounded, size: 12, color: brandGold),
                        ],
                      ],
                    ),
                  ),
                ],
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
                stream: _chatService.getMessagesStream(_activeChat!.id),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
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

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
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

  Widget _buildRoleBadge(String role) {
    if (role == 'admin') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF7C3AED),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'مشرف 🛡️',
          style: GoogleFonts.cairo(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
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
    const Color brandGold = Color(0xFFF59E0B);
    final isSpecialAdmin = message.isAdminSender;

    final timeStr = intl.DateFormat('hh:mm a', 'ar').format(message.createdAt);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isMe
              ? brandNavy
              : (isSpecialAdmin ? const Color(0xFFF3E8FF) : Colors.white),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isSpecialAdmin
                ? const Color(0xFFC084FC)
                : (isMe ? Colors.transparent : const Color(0xFFE2E8F0)),
            width: isSpecialAdmin ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Sender indicator if not me or if admin
            if (!isMe || isSpecialAdmin) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isSpecialAdmin ? 'إدارة المنصة (مشرف)' : message.senderName,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isSpecialAdmin
                          ? const Color(0xFF7C3AED)
                          : (isMe ? brandGold : brandNavy),
                    ),
                  ),
                  if (message.senderAccountId.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(
                      '#${message.senderAccountId}',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        color: isMe ? Colors.white60 : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 3),
            ],

            // Message text
            SelectableText(
              message.text,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: isMe ? Colors.white : const Color(0xFF1E293B),
                height: 1.45,
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
                    size: 14,
                    color: message.isRead ? brandGold : Colors.white60,
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
