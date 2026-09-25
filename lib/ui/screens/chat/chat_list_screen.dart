// ==============================================================================
// 💬 CHAT LIST CONVERSATIONS SCREEN
// ==============================================================================
// Displays all conversations for Clients, Lawyers, or Administrators.
// Provides search by name or 12-digit Account ID, unread indicators, and smooth navigation.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../data/models/chat_model.dart';
import '../../../network/chat_service.dart';
import '../../../network/auth_service.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../custom_widgets/app_logo_badge.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String? initialUserId;
  final String? initialRole;

  const ChatListScreen({
    super.key,
    this.initialUserId,
    this.initialRole,
  });

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String? _uid;
  String? _role;
  String? _name;
  String? _accountId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserSession() async {
    final session = await _authService.getSavedSession();
    final currentFirebaseUser = _authService.currentUser;

    setState(() {
      _uid = widget.initialUserId ?? session['uid'] ?? currentFirebaseUser?.uid;
      _role = widget.initialRole ?? session['role'] ?? 'client';
      _name = session['name'] ?? 'المستخدم';
      _accountId = session['accountId'] ?? '';
      _isLoading = false;
    });

    if (_uid != null && (_accountId == null || _accountId!.isEmpty)) {
      AccountIdUtils.ensureUserHasAccountId(
        uid: _uid!,
        role: _role ?? 'client',
      ).then((val) {
        if (mounted && val.isNotEmpty) {
          setState(() => _accountId = val);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF0B2A5B);
    const Color headerGold = Color(0xFFD49B1A);
    const Color pageBg = Color(0xFFFCFBF9);

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: pageBg,
        body: Center(
          child: CircularProgressIndicator(color: brandNavy),
        ),
      );
    }

    if (_uid == null) {
      return Scaffold(
        backgroundColor: pageBg,
        appBar: AppBar(
          backgroundColor: headerGold,
          elevation: 0,
          title: Text('المحادثات', style: GoogleFonts.cairo(color: brandNavy, fontWeight: FontWeight.w800)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 48, color: brandNavy),
                const SizedBox(height: 12),
                Text(
                  'يرجى تسجيل الدخول لعرض محادثاتك',
                  style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700, color: brandNavy),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: headerGold,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const AppLogoBadge(height: 28, withPillBackground: true),
            Row(
              children: [
                Text(
                  'المحادثات المباشرة',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: brandNavy,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: const Center(
                      child: Icon(Icons.arrow_forward_ios_rounded, color: brandNavy, size: 18),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم أو المعرّف (12 رقماً)...',
                    hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.search_rounded, color: headerGold),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                            onPressed: () => _searchCtrl.clear(),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ),

            // Chats Stream
            Expanded(
              child: StreamBuilder<List<ChatModel>>(
                stream: _chatService.getChatsForUser(_uid!, _role!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator(color: brandNavy));
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
                              'تعذر تحميل قائمة المحادثات، يرجى المحاولة مجدداً.',
                              style: GoogleFonts.cairo(color: const Color(0xFF64748B), fontSize: 13.5),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final allChats = snapshot.data ?? [];

                  // Apply search filter
                  final filteredChats = allChats.where((c) {
                    if (_searchQuery.isEmpty) return true;
                    final otherName = c.getOtherPartyName(_uid!).toLowerCase();
                    final otherAccount = c.getOtherPartyAccountId(_uid!);
                    final otherPhone = c.getOtherPartyPhone(_uid!);
                    final lastMsg = c.lastMessage.toLowerCase();
                    return otherName.contains(_searchQuery) ||
                        otherAccount.contains(_searchQuery) ||
                        otherPhone.contains(_searchQuery) ||
                        lastMsg.contains(_searchQuery);
                  }).toList();

                  if (filteredChats.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: brandNavy.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 42,
                                color: brandNavy,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty ? 'لا توجد نتائج بحث' : 'لا توجد محادثات حتى الآن',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: brandNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'تأكد من كتابة الاسم أو المعرّف بشكل صحيح.'
                                  : 'عند بدء التواصل مع محامٍ ستظهر محادثاتك هنا مباشرة.',
                              style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: filteredChats.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final chat = filteredChats[index];
                      return _buildChatCard(chat, brandNavy, headerGold);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatCard(ChatModel chat, Color brandNavy, Color headerGold) {
    final otherName = chat.getOtherPartyName(_uid!);
    final otherPhoto = chat.getOtherPartyPhoto(_uid!);
    final otherAccountId = chat.getOtherPartyAccountId(_uid!);
    final otherRole = chat.getOtherPartyRole(_uid!);
    final unread = chat.getUnreadCount(_uid!);

    final timeStr = intl.DateFormat('dd/MM hh:mm a', 'ar').format(chat.lastMessageTime);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chat: chat,
              currentUserId: _uid!,
              currentUserName: _name ?? 'المستخدم',
              currentUserRole: _role ?? 'client',
              currentUserAccountId: _accountId ?? '',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unread > 0 ? headerGold.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
            width: unread > 0 ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 48,
                height: 48,
                color: brandNavy.withValues(alpha: 0.08),
                child: otherPhoto != null && otherPhoto.isNotEmpty
                    ? ImageUtils.buildSafeImage(
                        photoUrl: otherPhoto,
                        fit: BoxFit.cover,
                      )
                    : Center(
                        child: Text(
                          otherName.isNotEmpty ? otherName.substring(0, 1) : 'م',
                          style: GoogleFonts.cairo(
                            color: brandNavy,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                otherName,
                                style: GoogleFonts.cairo(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: brandNavy,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            _buildRolePill(otherRole),
                          ],
                        ),
                      ),
                      Text(
                        timeStr,
                        style: GoogleFonts.cairo(
                          fontSize: 10.5,
                          color: const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (otherAccountId.isNotEmpty) ...[
                    Text(
                      'معرّف الحساب: ${AccountIdUtils.formatDisplay(otherAccountId)}',
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        color: headerGold,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage.isNotEmpty ? chat.lastMessage : 'لا توجد رسائل',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            color: unread > 0 ? brandNavy : const Color(0xFF64748B),
                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (unread > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '$unread',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRolePill(String role) {
    if (role == 'lawyer') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          'محامٍ',
          style: GoogleFonts.cairo(fontSize: 9.5, color: const Color(0xFFB45309), fontWeight: FontWeight.w700),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        'عميل',
        style: GoogleFonts.cairo(fontSize: 9.5, color: const Color(0xFF475569), fontWeight: FontWeight.w700),
      ),
    );
  }
}
