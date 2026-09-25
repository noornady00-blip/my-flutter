// ==============================================================================
// 💬 CHAT LIST CONVERSATIONS SCREEN
// ==============================================================================
// Displays all conversations for Clients, Lawyers, or Administrators.
// Features luxury Royal Navy & Gold header, interactive search (by name or 12-digit ID),
// pinned chat priority, and full RTL swipe gestures:
// - Swipe Right: [حذف] + [حظر]
// - Swipe Left:  [تثبيت / إلغاء التثبيت] + [غير مقروءة / مقروءة]
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/chat_model.dart';
import '../../../network/chat_service.dart';
import '../../../network/auth_service.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/awake_badge.dart';
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
      final currentFirebaseUser = _authService.currentUser;
      final session = await _authService.getSavedSession();

      if (mounted) {
        setState(() {
          _uid = currentFirebaseUser?.uid ?? widget.initialUserId ?? session['uid'];
          _role = widget.initialRole ?? session['role'] ?? 'client';
          _name = session['name'] ?? 'المستخدم';
          _accountId = session['accountId'] ?? '';
          _isLoading = false;
        });
      }

      if (_uid != null && _uid!.isNotEmpty && (_accountId == null || _accountId!.isEmpty)) {
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
        appBar: _buildStandardAppBar(headerGold, brandNavy),
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
      appBar: _buildStandardAppBar(headerGold, brandNavy),
      body: SafeArea(
        child: Column(
          children: [
            // 🔎 Dedicated Interactive Search Area
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

                  // Sort pinned chats to top
                  filteredChats.sort((a, b) {
                    final aPinned = a.isPinnedBy(_uid!);
                    final bPinned = b.isPinnedBy(_uid!);
                    if (aPinned && !bPinned) return -1;
                    if (!aPinned && bPinned) return 1;
                    return b.lastMessageTime.compareTo(a.lastMessageTime);
                  });

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
                      return _SwipeableChatTile(
                        key: ValueKey('chat_${chat.id}'),
                        chat: chat,
                        currentUserId: _uid!,
                        currentUserRole: _role ?? 'client',
                        currentUserName: _name ?? 'المستخدم',
                        currentUserAccountId: _accountId ?? '',
                        onDelete: () => _confirmDeleteChat(chat),
                        onBlock: () => _confirmBlockUser(chat),
                        onTogglePin: () => _togglePinChat(chat),
                        onToggleUnread: () => _toggleUnreadChat(chat),
                        brandNavy: brandNavy,
                        headerGold: headerGold,
                      );
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

  /// App bar styled identically to ProfileScreen and AllLawyersScreen (NO 3-lines menu icon)
  PreferredSizeWidget _buildStandardAppBar(Color headerGold, Color brandNavy) {
    return AppBar(
      backgroundColor: headerGold,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      centerTitle: false,
      automaticallyImplyLeading: false,
      titleSpacing: 16,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogoBadge(
                height: 26,
                withPillBackground: true,
              ),
              const SizedBox(width: 8),
              const Awake247Badge(),
            ],
          ),
          if (!widget.isEmbeddedInNav)
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF0B2A5B),
                    size: 18,
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.55),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.chat_bubble_rounded,
                    color: Color(0xFF0B2A5B),
                    size: 14,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'المحادثات المباشرة',
                    style: GoogleFonts.cairo(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _togglePinChat(ChatModel chat) async {
    if (_uid == null) return;
    final isPinned = chat.isPinnedBy(_uid!);
    await _chatService.togglePinChat(
      chatId: chat.id,
      currentUserId: _uid!,
      pin: !isPinned,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isPinned ? 'تم تثبيت المحادثة في الأعلى 📌' : 'تم إلغاء تثبيت المحادثة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: const Color(0xFF0B2A5B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleUnreadChat(ChatModel chat) async {
    if (_uid == null) return;
    final unread = chat.getUnreadCount(_uid!);
    await _chatService.toggleUnreadChat(
      chatId: chat.id,
      currentUserId: _uid!,
      role: _role ?? 'client',
      markUnread: unread == 0,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unread == 0 ? 'تم تمييز المحادثة كغير مقروءة' : 'تم تمييز المحادثة كمقروءة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: const Color(0xFF10B981),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _confirmDeleteChat(ChatModel chat) {
    if (_uid == null) return;
    final otherName = chat.getOtherPartyName(_uid!);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                  ),
                  child: const Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 28),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'حذف المحادثة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد من حذف محادثتك مع "$otherName" من قائمتك؟',
                style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _chatService.deleteChatForUser(
                          chatId: chat.id,
                          currentUserId: _uid!,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم حذف المحادثة من قائمتك', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('حذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBlockUser(ChatModel chat) {
    if (_uid == null) return;
    final otherUid = chat.getOtherPartyUid(_uid!);
    final otherName = chat.getOtherPartyName(_uid!);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                  ),
                  child: const Icon(Icons.block_rounded, color: Color(0xFFDC2626), size: 28),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'حظر المستخدم',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: const Color(0xFF0F172A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'هل أنت متأكد من حظر "$otherName"؟ لن يتمكن من مراسلتك مجدداً وسيتم إيقاف التواصل معه.',
                style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _chatService.blockUser(
                          currentUserId: _uid!,
                          targetUserId: otherUid,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم حظر المستخدم بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                              backgroundColor: const Color(0xFFDC2626),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('حظر', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 🌟 SWIPEABLE CHAT TILE COMPONENT
// -----------------------------------------------------------------------------
// Supports tactile horizontal dragging revealing action buttons matching
// the user's reference designs in Mahameek Royal Navy & Gold branding:
// - Swipe Right (RTL): [حذف] + [حظر]
// - Swipe Left  (RTL): [تثبيت] + [غير مقروءة]
// -----------------------------------------------------------------------------
class _SwipeableChatTile extends StatefulWidget {
  final ChatModel chat;
  final String currentUserId;
  final String currentUserRole;
  final String currentUserName;
  final String currentUserAccountId;
  final VoidCallback onDelete;
  final VoidCallback onBlock;
  final VoidCallback onTogglePin;
  final VoidCallback onToggleUnread;
  final Color brandNavy;
  final Color headerGold;

  const _SwipeableChatTile({
    super.key,
    required this.chat,
    required this.currentUserId,
    required this.currentUserRole,
    required this.currentUserName,
    required this.currentUserAccountId,
    required this.onDelete,
    required this.onBlock,
    required this.onTogglePin,
    required this.onToggleUnread,
    required this.brandNavy,
    required this.headerGold,
  });

  @override
  State<_SwipeableChatTile> createState() => _SwipeableChatTileState();
}

class _SwipeableChatTileState extends State<_SwipeableChatTile>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  double _dragOffset = 0.0;
  static const double _maxSwipeExtent = 160.0;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _animCtrl.addListener(() {
      setState(() {
        _dragOffset = _animCtrl.value;
      });
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  void _snapTo(double target) {
    final start = _dragOffset;
    _animCtrl.stop();
    _animCtrl.reset();
    final anim = Tween<double>(begin: start, end: target).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    anim.addListener(() {
      setState(() {
        _dragOffset = anim.value;
      });
    });
    _animCtrl.forward();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    final delta = details.primaryDelta ?? 0;
    setState(() {
      _dragOffset = (_dragOffset + delta).clamp(-_maxSwipeExtent, _maxSwipeExtent);
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragOffset > 60) {
      _snapTo(_maxSwipeExtent);
    } else if (_dragOffset < -60) {
      _snapTo(-_maxSwipeExtent);
    } else {
      _snapTo(0.0);
    }
  }

  String _formatChatTime(DateTime dt) {
    try {
      final now = DateTime.now();
      final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
      final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'م' : 'ص';
      final timePart = '$hour:$minute $period';
      if (isToday) {
        return timePart;
      }
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      return '$day/$month $timePart';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = widget.chat;
    final otherName = chat.getOtherPartyName(widget.currentUserId);
    final otherPhoto = chat.getOtherPartyPhoto(widget.currentUserId);
    final otherRole = chat.getOtherPartyRole(widget.currentUserId);
    final unread = chat.getUnreadCount(widget.currentUserId);
    final isPinned = chat.isPinnedBy(widget.currentUserId);
    final timeStr = _formatChatTime(chat.lastMessageTime);
    final isLastMsgDeleted = chat.lastMessage == 'تم حذف هذه الرسالة';

    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onHorizontalDragUpdate: _handleDragUpdate,
        onHorizontalDragEnd: _handleDragEnd,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // 🎨 Background Action Buttons (Positioned under the sliding card)
            if (_dragOffset > 0)
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: _maxSwipeExtent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      // Delete Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _snapTo(0.0);
                            widget.onDelete();
                          },
                          child: Container(
                            color: const Color(0xFFDC2626),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                const SizedBox(height: 3),
                                Text(
                                  'حذف',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Block Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _snapTo(0.0);
                            widget.onBlock();
                          },
                          child: Container(
                            color: const Color(0xFF334155),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.block_rounded, color: Colors.white, size: 22),
                                const SizedBox(height: 3),
                                Text(
                                  'حظر',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (_dragOffset < 0)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                width: _maxSwipeExtent,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    children: [
                      // Pin / Unpin Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _snapTo(0.0);
                            widget.onTogglePin();
                          },
                          child: Container(
                            color: const Color(0xFF1E293B),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded,
                                  color: isPinned ? const Color(0xFFFBBF24) : Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isPinned ? 'إلغاء التثبيت' : 'تثبيت',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: isPinned ? const Color(0xFFFBBF24) : Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Mark Unread Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _snapTo(0.0);
                            widget.onToggleUnread();
                          },
                          child: Container(
                            color: const Color(0xFF10B981),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.mark_chat_unread_rounded, color: Colors.white, size: 22),
                                const SizedBox(height: 3),
                                Text(
                                  unread > 0 ? 'مقروءة' : 'غير مقروءة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // 📄 Main Chat Card Foreground (Guaranteed 100% Full Width)
            Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: SizedBox(
                width: double.infinity,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      if (_dragOffset != 0) {
                        _snapTo(0.0);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            chat: chat,
                            currentUserId: widget.currentUserId,
                            currentUserName: widget.currentUserName,
                            currentUserRole: widget.currentUserRole,
                            currentUserAccountId: widget.currentUserAccountId,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isPinned ? const Color(0xFFFFFDF5) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPinned
                              ? widget.headerGold.withValues(alpha: 0.75)
                              : (unread > 0 ? widget.headerGold.withValues(alpha: 0.6) : const Color(0xFFE2E8F0)),
                          width: isPinned || unread > 0 ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: _dragOffset != 0 ? 0.08 : 0.03),
                            blurRadius: _dragOffset != 0 ? 10 : 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                      // Avatar
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: otherRole == 'admin' ? widget.headerGold : Colors.transparent,
                                width: otherRole == 'admin' ? 2 : 0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                width: 48,
                                height: 48,
                                color: otherRole == 'admin'
                                    ? widget.headerGold.withValues(alpha: 0.12)
                                    : widget.brandNavy.withValues(alpha: 0.08),
                                child: otherPhoto != null && otherPhoto.isNotEmpty
                                    ? ImageUtils.buildSafeImage(
                                        photoUrl: otherPhoto,
                                        fit: BoxFit.cover,
                                      )
                                    : Center(
                                        child: otherRole == 'admin'
                                            ? const Icon(Icons.admin_panel_settings_rounded, size: 24, color: Color(0xFFB45309))
                                            : Text(
                                                otherName.isNotEmpty ? otherName.substring(0, 1) : 'م',
                                                style: GoogleFonts.cairo(
                                                  color: widget.brandNavy,
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                      ),
                              ),
                            ),
                          ),
                          if (otherRole == 'admin')
                            Positioned(
                              bottom: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFD49B1A),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.shield_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
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
                                            color: widget.brandNavy,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildRolePill(otherRole, widget.headerGold),
                                    ],
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (isPinned) ...[
                                      const Icon(
                                        Icons.push_pin_rounded,
                                        size: 14,
                                        color: Color(0xFFD49B1A),
                                      ),
                                      const SizedBox(width: 4),
                                    ],
                                    Text(
                                      timeStr,
                                      style: GoogleFonts.cairo(
                                        fontSize: 10.5,
                                        color: isPinned ? const Color(0xFFB45309) : const Color(0xFF94A3B8),
                                        fontWeight: isPinned ? FontWeight.w700 : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 5),
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      if (isLastMsgDeleted) ...[
                                        const Icon(
                                          Icons.block_rounded,
                                          size: 13,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          chat.lastMessage.isNotEmpty ? chat.lastMessage : 'لا توجد رسائل',
                                          style: GoogleFonts.cairo(
                                            fontSize: 12.5,
                                            color: isLastMsgDeleted
                                                ? const Color(0xFF94A3B8)
                                                : (unread > 0 ? widget.brandNavy : const Color(0xFF64748B)),
                                            fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.normal,
                                            fontStyle: isLastMsgDeleted ? FontStyle.italic : FontStyle.normal,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
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
                                      unread > 9 ? '+9' : '$unread',
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
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);
}

  Widget _buildRolePill(String role, Color headerGold) {
    if (role == 'admin') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
          ),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(color: const Color(0xFFD49B1A), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.admin_panel_settings_rounded, size: 11, color: Color(0xFF92400E)),
            const SizedBox(width: 3),
            Text(
              'مشرف',
              style: GoogleFonts.cairo(
                fontSize: 9.5,
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
