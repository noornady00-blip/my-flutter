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
import '../auth/auth_gateway_screen.dart';
import '../lawyers/all_lawyers_screen.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String? initialUserId;
  final String? initialRole;
  final bool isEmbeddedInNav;
  final VoidCallback? onOpenDrawer;

  const ChatListScreen({
    super.key,
    this.initialUserId,
    this.initialRole,
    this.isEmbeddedInNav = false,
    this.onOpenDrawer,
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
    final authUser = _authService.currentUser;
    _uid = widget.initialUserId ?? authUser?.uid;
    _role = widget.initialRole ?? 'client';
    // If user is already authenticated at mount time, avoid full-screen spinner
    if (_uid != null) {
      _isLoading = false;
    }
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
    try {
      final session = await _authService.getSavedSession();
      final currentFirebaseUser = _authService.currentUser;

      if (mounted) {
        setState(() {
          _uid = widget.initialUserId ?? session['uid'] ?? currentFirebaseUser?.uid;
          _role = widget.initialRole ?? session['role'] ?? 'client';
          _name = session['name'] ?? 'المستخدم';
          _accountId = session['accountId'] ?? '';
          _isLoading = false;
        });
      }

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
    } catch (e) {
      debugPrint('[ChatListScreen] _loadUserSession notice: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF0B2A5B);
    const Color headerGold = Color(0xFFD49B1A);
    const Color pageBg = Color(0xFFFCFBF9);

    if (_isLoading && _uid == null) {
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
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
          ),
          automaticallyImplyLeading: false,
          titleSpacing: 16,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const AppLogoBadge(height: 28, withPillBackground: true),
              Text(
                'المحادثات المباشرة',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: brandNavy,
                ),
              ),
              if (widget.isEmbeddedInNav && widget.onOpenDrawer != null)
                InkWell(
                  onTap: widget.onOpenDrawer,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                    ),
                    child: const Center(
                      child: Icon(Icons.menu_rounded, color: brandNavy, size: 22),
                    ),
                  ),
                )
              else if (!widget.isEmbeddedInNav)
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
                )
              else
                const SizedBox(width: 38),
            ],
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: brandNavy.withValues(alpha: 0.07),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.chat_bubble_outline_rounded, size: 40, color: brandNavy),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'سجّل دخولك لبدء المحادثات',
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: brandNavy,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'تواصل مع نخبة المحامين المعتمدين وطرح استفساراتك القانونية ومتابعة قضاياك بكل سهولة وأمان.',
                  style: GoogleFonts.cairo(fontSize: 13.5, color: const Color(0xFF64748B), height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AuthGatewayScreen()),
                    );
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: Text(
                    'تسجيل الدخول / إنشاء حساب',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: brandNavy,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
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
                const SizedBox(width: 10),
                if (widget.isEmbeddedInNav && widget.onOpenDrawer != null)
                  InkWell(
                    onTap: widget.onOpenDrawer,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                      ),
                      child: const Center(
                        child: Icon(Icons.menu_rounded, color: brandNavy, size: 22),
                      ),
                    ),
                  )
                else if (!widget.isEmbeddedInNav)
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
                  )
                else
                  const SizedBox(width: 38),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🔎 Dedicated Interactive Search Area with Action Button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Search Action Button
                    Padding(
                      padding: const EdgeInsets.only(left: 6, right: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            FocusScope.of(context).unfocus();
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: headerGold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: headerGold.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search_rounded, color: Color(0xFFB45309), size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  'بحث',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Search Input Field
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        textDirection: TextDirection.rtl,
                        decoration: InputDecoration(
                          hintText: 'ابحث بالاسم، الرسالة أو معرّف الحساب (12 رقماً)...',
                          hintStyle: GoogleFonts.cairo(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                                  onPressed: () => _searchCtrl.clear(),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Chats Stream
            Expanded(
              child: StreamBuilder<List<ChatModel>>(
                stream: _chatService.getChatsForUser(_uid!, _role ?? 'client'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(color: brandNavy),
                          const SizedBox(height: 12),
                          Text(
                            'جارٍ جلب المحادثات...',
                            style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
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
                              child: Icon(
                                _searchQuery.isNotEmpty
                                    ? Icons.search_off_rounded
                                    : Icons.chat_bubble_outline_rounded,
                                size: 42,
                                color: brandNavy,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              _searchQuery.isNotEmpty ? 'لا توجد نتائج بحث' : 'لا توجد محادثات حتى الآن',
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: brandNavy,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'تأكد من كتابة الاسم أو رقم الحساب بشكل صحيح.'
                                  : 'تواصل مع نخبة المحامين المعتمدين وستظهر محادثاتك هنا فوراً.',
                              style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (_searchQuery.isNotEmpty)
                              OutlinedButton.icon(
                                onPressed: () => _searchCtrl.clear(),
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                label: Text(
                                  'مسح البحث',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: brandNavy,
                                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              )
                            else if (_role != 'lawyer')
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const AllLawyersScreen()),
                                  );
                                },
                                icon: const Icon(Icons.people_alt_rounded, size: 16),
                                label: Text(
                                  'تصفح المحامين وبدء استشارة',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: brandNavy,
                                  foregroundColor: Colors.white,
                                  elevation: 1,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                ),
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
