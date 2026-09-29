// ==============================================================================
// 💬 CHAT LIST CONVERSATIONS SCREEN
// ==============================================================================
// Displays all conversations for Clients, Lawyers, or Administrators.
// Features luxury Royal Navy & Gold header, interactive search (by name or 12-digit ID),
// pinned chat priority, and full RTL swipe gestures:
// - Swipe Right: [حذف] + [إيقاف / تنشيط]
// - Swipe Left:  [تثبيت / إلغاء التثبيت] + [غير مقروءة / مقروءة]
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  String _activeFilter = 'all'; // 'all', 'unread', 'pinned'
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
            // 🔎 Dedicated Interactive Search Area & Quick Filters
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _searchQuery.isNotEmpty
                            ? headerGold.withValues(alpha: 0.6)
                            : const Color(0xFFE2E8F0),
                        width: _searchQuery.isNotEmpty ? 1.4 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B2A5B).withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Search Action / Icon
                        Padding(
                          padding: const EdgeInsets.only(right: 10, left: 4),
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: headerGold.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Icon(Icons.search_rounded, color: Color(0xFFB45309), size: 20),
                            ),
                          ),
                        ),
                        // Search Input Field
                        Expanded(
                          child: TextField(
                            controller: _searchCtrl,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.cairo(
                              fontSize: 13.5,
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w600,
                            ),
                            decoration: InputDecoration(
                              hintText: 'ابحث بالاسم، الرسالة أو معرّف الحساب...',
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
                ],
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
                  final unreadCount = allChats.where((c) => c.getUnreadCount(_uid!) > 0).length;
                  final pinnedCount = allChats.where((c) => c.isPinnedBy(_uid!)).length;

                  // Apply search and tab filter
                  final filteredChats = allChats.where((c) {
                    if (_activeFilter == 'unread' && c.getUnreadCount(_uid!) == 0) {
                      return false;
                    }
                    if (_activeFilter == 'pinned' && !c.isPinnedBy(_uid!)) {
                      return false;
                    }
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

                  return Column(
                    children: [
                      // Quick Filter Tabs Row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                        child: Row(
                          children: [
                            _buildFilterChip('all', 'الكل', allChats.length, Icons.all_inbox_rounded, brandNavy),
                            const SizedBox(width: 8),
                            _buildFilterChip('unread', 'غير مقروءة', unreadCount, Icons.mark_chat_unread_rounded, const Color(0xFFDC2626)),
                            const SizedBox(width: 8),
                            _buildFilterChip('pinned', 'المثبتة', pinnedCount, Icons.push_pin_rounded, const Color(0xFFD49B1A)),
                          ],
                        ),
                      ),

                      // List of Chats or Empty State
                      Expanded(
                        child: filteredChats.isEmpty
                            ? Center(
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
                                              : (_activeFilter != 'all'
                                                  ? Icons.filter_list_off_rounded
                                                  : Icons.chat_bubble_outline_rounded),
                                          size: 42,
                                          color: brandNavy,
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'لا توجد نتائج بحث'
                                            : (_activeFilter == 'unread'
                                                ? 'لا توجد رسائل غير مقروءة'
                                                : (_activeFilter == 'pinned'
                                                    ? 'لا توجد محادثات مثبتة'
                                                    : 'لا توجد محادثات حتى الآن')),
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
                                            : (_activeFilter != 'all'
                                                ? 'يمكنك التبديل إلى تبويب "الكل" لعرض كافة المحادثات.'
                                                : 'تواصل مع نخبة المحامين المعتمدين وستظهر محادثاتك هنا فوراً.'),
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
                                      else if (_activeFilter != 'all')
                                        OutlinedButton.icon(
                                          onPressed: () => setState(() => _activeFilter = 'all'),
                                          icon: const Icon(Icons.all_inbox_rounded, size: 16),
                                          label: Text(
                                            'عرض كافة المحادثات',
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
                              )
                            : ListView.separated(
                                physics: const BouncingScrollPhysics(),
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
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
                                    onToggleStop: () => _toggleStopChat(chat),
                                    onTogglePin: () => _togglePinChat(chat),
                                    onToggleUnread: () => _toggleUnreadChat(chat),
                                    brandNavy: brandNavy,
                                    headerGold: headerGold,
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String title, int count, IconData icon, Color activeColor) {
    final isSelected = _activeFilter == filterKey;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _activeFilter = filterKey),
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                width: 1.1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.22),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 13.5,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF64748B),
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count > 99 ? '+99' : '$count',
                      style: GoogleFonts.cairo(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
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
              const AppLogoBadge.header(),
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

  Future<void> _toggleStopChat(ChatModel chat) async {
    if (_uid == null) return;
    final isStopped = chat.isStoppedBy(_uid!);
    await _chatService.toggleStopChat(
      chatId: chat.id,
      currentUserId: _uid!,
      stop: !isStopped,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !isStopped
                ? 'تم إيقاف هذا الحساب ⏸️ (لن تصلك رسائل أو إشعارات منه)'
                : 'تم تنشيط المحادثة مع هذا الحساب بنجاح ▶️',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            textDirection: TextDirection.rtl,
          ),
          backgroundColor: !isStopped ? const Color(0xFF991B1B) : const Color(0xFF0B2A5B),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

// -----------------------------------------------------------------------------
// 🌟 SWIPEABLE CHAT TILE COMPONENT
// -----------------------------------------------------------------------------
// Supports tactile horizontal dragging revealing action buttons matching
// the user's reference designs in Mahameek Royal Navy & Gold branding:
// - Swipe Right (RTL): [حذف] + [كتم/تفعيل الإشعارات]
// - Swipe Left  (RTL): [تثبيت] + [غير مقروءة]
// -----------------------------------------------------------------------------
class _SwipeableChatTile extends StatefulWidget {
  final ChatModel chat;
  final String currentUserId;
  final String currentUserRole;
  final String currentUserName;
  final String currentUserAccountId;
  final VoidCallback onDelete;
  final VoidCallback onToggleStop;
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
    required this.onToggleStop,
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
    final otherPhotoBase64 = chat.getOtherPartyPhotoBase64(widget.currentUserId);
    final otherRole = chat.getOtherPartyRole(widget.currentUserId);
    final otherUid = chat.getOtherPartyUid(widget.currentUserId);
    final otherPhone = chat.getOtherPartyPhone(widget.currentUserId);
    final otherAccountId = chat.getOtherPartyAccountId(widget.currentUserId);
    final unread = chat.getUnreadCount(widget.currentUserId);
    final isPinned = chat.isPinnedBy(widget.currentUserId);
    final isStopped = chat.isStoppedBy(widget.currentUserId);
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
                  borderRadius: BorderRadius.circular(18),
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
                      // Stop / Resume User Button
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            _snapTo(0.0);
                            widget.onToggleStop();
                          },
                          child: Container(
                            color: isStopped ? const Color(0xFF065F46) : const Color(0xFF475569),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isStopped ? Icons.play_circle_filled_rounded : Icons.pause_circle_filled_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  isStopped ? 'تنشيط' : 'إيقاف',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                  textAlign: TextAlign.center,
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
                  borderRadius: BorderRadius.circular(18),
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

            // 📄 Main Chat Card Foreground (Executive Card Styling)
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
                      if (unread > 0) {
                        ChatService().markChatAsRead(
                          chatId: chat.id,
                          currentUserId: widget.currentUserId,
                          currentUserRole: widget.currentUserRole,
                        );
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
                      ).then((_) {
                        if (mounted) setState(() {});
                      });
                    },
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: isPinned ? const Color(0xFFFFFDF8) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isPinned
                              ? const Color(0xFFD49B1A).withValues(alpha: 0.60)
                              : (unread > 0
                                  ? const Color(0xFF0B2A5B).withValues(alpha: 0.28)
                                  : const Color(0xFFE2E8F0)),
                          width: isPinned ? 1.4 : (unread > 0 ? 1.2 : 1),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: isPinned
                                ? const Color(0xFFD49B1A).withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: _dragOffset != 0 ? 0.08 : 0.03),
                            blurRadius: _dragOffset != 0 ? 12 : 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // 📸 Reactive Cached Avatar with Auto-Healing & Role Badge
                          _ChatTileAvatar(
                            otherUid: otherUid,
                            otherRole: otherRole,
                            otherName: otherName,
                            otherPhone: otherPhone,
                            otherAccountId: otherAccountId,
                            initialPhotoUrl: otherPhoto,
                            initialPhotoBase64: otherPhotoBase64,
                            chatId: chat.id,
                            brandNavy: widget.brandNavy,
                            headerGold: widget.headerGold,
                          ),
                          const SizedBox(width: 13),

                          // 📝 Details & Message Preview
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
                                                fontSize: 14.8,
                                                fontWeight: unread > 0 ? FontWeight.w900 : FontWeight.w800,
                                                color: const Color(0xFF0F172A),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 7),
                                          _buildRolePill(otherRole, widget.headerGold),
                                        ],
                                      ),
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (isPinned) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEF3C7),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.push_pin_rounded,
                                                  size: 11,
                                                  color: Color(0xFFD49B1A),
                                                ),
                                                const SizedBox(width: 2),
                                                Text(
                                                  'مثبتة',
                                                  style: GoogleFonts.cairo(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: const Color(0xFFB45309),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 5),
                                        ],
                                        if (isStopped) ...[
                                          const Icon(
                                            Icons.pause_circle_filled_rounded,
                                            size: 14,
                                            color: Color(0xFFEF4444),
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          timeStr,
                                          style: GoogleFonts.cairo(
                                            fontSize: 11,
                                            color: unread > 0 ? const Color(0xFF0B2A5B) : const Color(0xFF94A3B8),
                                            fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
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
                                          ] else if (chat.lastSenderId == widget.currentUserId) ...[
                                            Icon(
                                              Icons.done_all_rounded,
                                              size: 15,
                                              color: unread == 0 ? const Color(0xFF0284C7) : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 4),
                                          ],
                                          Expanded(
                                            child: Text(
                                              chat.lastMessage.isNotEmpty ? chat.lastMessage : 'بدء المحادثة...',
                                              style: GoogleFonts.cairo(
                                                fontSize: 12.8,
                                                color: isLastMsgDeleted
                                                    ? const Color(0xFF94A3B8)
                                                    : (unread > 0 ? const Color(0xFF0F172A) : const Color(0xFF64748B)),
                                                fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.normal,
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
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                                          ),
                                          borderRadius: BorderRadius.circular(12),
                                          boxShadow: [
                                            BoxShadow(
                                              color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                                              blurRadius: 5,
                                              offset: const Offset(0, 1.5),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          unread > 99 ? '+99' : '$unread',
                                          style: GoogleFonts.cairo(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
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
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFFD49B1A), width: 0.9),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, size: 10, color: Color(0xFFB45309)),
            const SizedBox(width: 3),
            Text(
              'مشرف',
              style: GoogleFonts.cairo(
                fontSize: 10,
                color: const Color(0xFFB45309),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }
    if (role == 'lawyer') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF93C5FD), width: 0.8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.gavel_rounded, size: 10, color: Color(0xFF1D4ED8)),
            const SizedBox(width: 3),
            Text(
              'محامٍ معتمد',
              style: GoogleFonts.cairo(
                fontSize: 10,
                color: const Color(0xFF1D4ED8),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.person_rounded, size: 10, color: Color(0xFF475569)),
          const SizedBox(width: 3),
          Text(
            'عميل',
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 📸 ULTRA-REACTIVE CACHED AVATAR WITH AUTO-HEALING
// -----------------------------------------------------------------------------
class _ChatTileAvatar extends StatefulWidget {
  final String otherUid;
  final String otherRole;
  final String otherName;
  final String otherPhone;
  final String otherAccountId;
  final String? initialPhotoUrl;
  final String? initialPhotoBase64;
  final String chatId;
  final Color brandNavy;
  final Color headerGold;

  const _ChatTileAvatar({
    required this.otherUid,
    required this.otherRole,
    required this.otherName,
    required this.otherPhone,
    required this.otherAccountId,
    this.initialPhotoUrl,
    this.initialPhotoBase64,
    required this.chatId,
    required this.brandNavy,
    required this.headerGold,
  });

  static final Map<String, String> _urlCache = {};
  static final Map<String, String> _base64Cache = {};
  static final Set<String> _pendingFetches = {};

  @override
  State<_ChatTileAvatar> createState() => _ChatTileAvatarState();
}

class _ChatTileAvatarState extends State<_ChatTileAvatar> {
  String? _resolvedUrl;
  String? _resolvedBase64;

  @override
  void initState() {
    super.initState();
    _initPhotoState();
  }

  @override
  void didUpdateWidget(covariant _ChatTileAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialPhotoUrl != widget.initialPhotoUrl ||
        oldWidget.initialPhotoBase64 != widget.initialPhotoBase64 ||
        oldWidget.otherUid != widget.otherUid) {
      _initPhotoState();
    }
  }

  void _initPhotoState() {
    final hasInitBase64 = widget.initialPhotoBase64 != null &&
        widget.initialPhotoBase64!.trim().isNotEmpty &&
        widget.initialPhotoBase64 != 'default';
    final hasInitUrl = widget.initialPhotoUrl != null &&
        widget.initialPhotoUrl!.trim().isNotEmpty &&
        widget.initialPhotoUrl != 'default';

    if (hasInitBase64) {
      _resolvedBase64 = widget.initialPhotoBase64!.trim();
      _cacheForUser(widget.otherUid, widget.otherPhone, base64: _resolvedBase64);
    }
    if (hasInitUrl) {
      _resolvedUrl = widget.initialPhotoUrl!.trim();
      _cacheForUser(widget.otherUid, widget.otherPhone, url: _resolvedUrl);
    }

    if (!hasInitBase64 && !hasInitUrl) {
      _checkCacheOrFetch();
    }
  }

  void _cacheForUser(String uid, String phone, {String? url, String? base64}) {
    if (uid.isNotEmpty) {
      if (url != null) _ChatTileAvatar._urlCache[uid] = url;
      if (base64 != null) _ChatTileAvatar._base64Cache[uid] = base64;
    }
    final cleanDigits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanDigits.isNotEmpty) {
      if (url != null) _ChatTileAvatar._urlCache[cleanDigits] = url;
      if (base64 != null) _ChatTileAvatar._base64Cache[cleanDigits] = base64;
    }
  }

  void _checkCacheOrFetch() {
    final cleanDigits = widget.otherPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final cachedBase64 = _ChatTileAvatar._base64Cache[widget.otherUid] ??
        (cleanDigits.isNotEmpty ? _ChatTileAvatar._base64Cache[cleanDigits] : null);
    final cachedUrl = _ChatTileAvatar._urlCache[widget.otherUid] ??
        (cleanDigits.isNotEmpty ? _ChatTileAvatar._urlCache[cleanDigits] : null);

    if (cachedBase64 != null || cachedUrl != null) {
      _resolvedBase64 = cachedBase64;
      _resolvedUrl = cachedUrl;
      return;
    }

    final fetchKey = widget.otherUid.isNotEmpty ? widget.otherUid : cleanDigits;
    if (fetchKey.isEmpty || _ChatTileAvatar._pendingFetches.contains(fetchKey)) {
      return;
    }

    _ChatTileAvatar._pendingFetches.add(fetchKey);
    _fetchPhotoAsync(fetchKey, cleanDigits);
  }

  Future<void> _fetchPhotoAsync(String fetchKey, String cleanDigits) async {
    try {
      String? foundUrl;
      String? foundBase64;

      // 1. Try users collection
      if (widget.otherUid.isNotEmpty) {
        final uDoc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUid).get();
        if (uDoc.exists && uDoc.data() != null) {
          final data = uDoc.data()!;
          foundBase64 = (data['photoBase64'] ??
                  data['user_profile_photo_base64'] ??
                  data['photo'] ??
                  data['profileImage'])
              ?.toString()
              .trim();
          foundUrl = (data['photoUrl'] ??
                  data['user_profile_photo_url'] ??
                  data['imageUrl'])
              ?.toString()
              .trim();
        }
      }

      // 2. Try lawyers collection
      if ((foundBase64 == null || foundBase64.isEmpty) &&
          (foundUrl == null || foundUrl.isEmpty) &&
          widget.otherUid.isNotEmpty) {
        final lDoc = await FirebaseFirestore.instance.collection('lawyers').doc(widget.otherUid).get();
        if (lDoc.exists && lDoc.data() != null) {
          final data = lDoc.data()!;
          foundBase64 = (data['photoBase64'] ??
                  data['user_profile_photo_base64'] ??
                  data['photo'])
              ?.toString()
              .trim();
          foundUrl = (data['photoUrl'] ?? data['imageUrl'])?.toString().trim();
        }
      }

      // 3. Try phone_directory
      if ((foundBase64 == null || foundBase64.isEmpty) &&
          (foundUrl == null || foundUrl.isEmpty) &&
          cleanDigits.isNotEmpty) {
        final pdDoc = await FirebaseFirestore.instance.collection('phone_directory').doc(cleanDigits).get();
        if (pdDoc.exists && pdDoc.data() != null) {
          final data = pdDoc.data()!;
          foundBase64 = (data['photoBase64'] ??
                  data['user_profile_photo_base64'] ??
                  data['photo'])
              ?.toString()
              .trim();
          foundUrl = (data['photoUrl'] ?? data['imageUrl'])?.toString().trim();
        }
      }

      if (foundBase64 == 'default') foundBase64 = null;
      if (foundUrl == 'default') foundUrl = null;

      if ((foundBase64 != null && foundBase64.isNotEmpty) ||
          (foundUrl != null && foundUrl.isNotEmpty)) {
        _cacheForUser(widget.otherUid, widget.otherPhone, url: foundUrl, base64: foundBase64);

        if (mounted) {
          setState(() {
            _resolvedBase64 = foundBase64;
            _resolvedUrl = foundUrl;
          });
        }

        // Self-heal the chat document in Firestore so subsequent reads have it natively!
        if (widget.chatId.isNotEmpty) {
          final isLawyer = widget.otherRole == 'lawyer';
          final updateMap = <String, dynamic>{};
          if (isLawyer) {
            if (foundUrl != null && foundUrl.isNotEmpty) updateMap['lawyerPhoto'] = foundUrl;
            if (foundBase64 != null && foundBase64.isNotEmpty) updateMap['lawyerPhotoBase64'] = foundBase64;
          } else {
            if (foundUrl != null && foundUrl.isNotEmpty) updateMap['clientPhoto'] = foundUrl;
            if (foundBase64 != null && foundBase64.isNotEmpty) updateMap['clientPhotoBase64'] = foundBase64;
          }
          if (updateMap.isNotEmpty) {
            FirebaseFirestore.instance.collection('chats').doc(widget.chatId).update(updateMap).catchError((_) {});
          }
        }
      }
    } catch (_) {
      // Graceful fallback
    } finally {
      _ChatTileAvatar._pendingFetches.remove(fetchKey);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = (_resolvedBase64 != null && _resolvedBase64!.isNotEmpty) ||
        (_resolvedUrl != null && _resolvedUrl!.isNotEmpty);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Outer glow & border ring
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: widget.otherRole == 'admin'
                  ? [const Color(0xFFF59E0B), const Color(0xFFD97706)]
                  : (widget.otherRole == 'lawyer'
                      ? [const Color(0xFFD49B1A), const Color(0xFF0B2A5B)]
                      : [const Color(0xFF0B2A5B), const Color(0xFF1E3A8A)]),
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: (widget.otherRole == 'admin' ? const Color(0xFFD49B1A) : widget.brandNavy)
                    .withValues(alpha: 0.16),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2), // 2px border ring
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            padding: const EdgeInsets.all(1.5),
            child: ClipOval(
              child: hasPhoto
                  ? AppImageUtils.buildAvatarImage(
                      photoBase64: _resolvedBase64,
                      photoUrl: _resolvedUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      fallback: _buildFallbackAvatar(),
                    )
                  : _buildFallbackAvatar(),
            ),
          ),
        ),

        // Role / Online Badge Overlay
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(3.5),
            decoration: BoxDecoration(
              color: widget.otherRole == 'admin'
                  ? const Color(0xFFD49B1A)
                  : (widget.otherRole == 'lawyer' ? const Color(0xFF0B2A5B) : const Color(0xFF10B981)),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              widget.otherRole == 'admin'
                  ? Icons.shield_rounded
                  : (widget.otherRole == 'lawyer' ? Icons.gavel_rounded : Icons.person_rounded),
              size: 9,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFallbackAvatar() {
    final letter = widget.otherName.trim().isNotEmpty
        ? widget.otherName.trim().characters.first
        : (widget.otherRole == 'admin' ? 'م' : 'ع');

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: widget.otherRole == 'admin'
              ? [const Color(0xFFFEF3C7), const Color(0xFFFDE68A)]
              : (widget.otherRole == 'lawyer'
                  ? [const Color(0xFF1E2E60), const Color(0xFF0B2A5B)]
                  : [const Color(0xFF0B2A5B), const Color(0xFF1E3A8A)]),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: widget.otherRole == 'admin'
            ? const Icon(Icons.admin_panel_settings_rounded, size: 24, color: Color(0xFFB45309))
            : Text(
                letter,
                style: GoogleFonts.cairo(
                  color: widget.otherRole == 'lawyer' ? const Color(0xFFD49B1A) : Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

