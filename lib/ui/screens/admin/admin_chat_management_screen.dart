// ==============================================================================
// 🛡️ ADMIN CHAT MANAGEMENT SCREEN
// ==============================================================================
// Dedicated oversight interface for Platform Administrators to view all conversations,
// search by Lawyer/Client/12-digit Account ID, and intervene as Admin if needed.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../data/models/chat_model.dart';
import '../../../network/chat_service.dart';
import '../../../network/auth_service.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../chat/chat_screen.dart';

class AdminChatManagementScreen extends StatefulWidget {
  const AdminChatManagementScreen({super.key});

  @override
  State<AdminChatManagementScreen> createState() => _AdminChatManagementScreenState();
}

class _AdminChatManagementScreenState extends State<AdminChatManagementScreen> {
  final ChatService _chatService = ChatService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  String? _adminUid;
  String? _adminName;
  String? _adminAccountId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAdminSession();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAdminSession() async {
    final session = await _authService.getSavedSession();
    final user = _authService.currentUser;

    setState(() {
      _adminUid = session['uid'] ?? user?.uid;
      _adminName = session['name'] ?? 'مشرف المنصة';
      _adminAccountId = session['accountId'] ?? '';
      _isLoading = false;
    });

    if (_adminUid != null && (_adminAccountId == null || _adminAccountId!.isEmpty)) {
      AccountIdUtils.ensureUserHasAccountId(
        uid: _adminUid!,
        role: 'admin',
      ).then((val) {
        if (mounted && val.isNotEmpty) {
          setState(() => _adminAccountId = val);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF0B2A5B);
    const Color headerGold = Color(0xFFD49B1A);
    const Color pageBg = Color(0xFFFCFBF9);

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
                  'إدارة المحادثات (مشرف)',
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
                    hintText: 'ابحث باسم المحامي، العميل، الهاتف، أو المعرّف...',
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

            // Stream of all chats
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: brandNavy))
                  : StreamBuilder<List<ChatModel>>(
                      stream: _chatService.getChatsForUser(_adminUid ?? 'admin', 'admin'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator(color: brandNavy));
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'تعذر تحميل المحادثات: ${snapshot.error}',
                                style: GoogleFonts.cairo(color: const Color(0xFFDC2626), fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final allChats = snapshot.data ?? [];

                        final filtered = allChats.where((c) {
                          if (_searchQuery.isEmpty) return true;
                          return c.clientName.toLowerCase().contains(_searchQuery) ||
                              c.lawyerName.toLowerCase().contains(_searchQuery) ||
                              c.clientPhone.contains(_searchQuery) ||
                              c.lawyerPhone.contains(_searchQuery) ||
                              c.clientAccountId.contains(_searchQuery) ||
                              c.lawyerAccountId.contains(_searchQuery) ||
                              c.lastMessage.toLowerCase().contains(_searchQuery);
                        }).toList();

                        if (filtered.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFF94A3B8)),
                                  const SizedBox(height: 12),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'لا توجد نتائج بحث' : 'لا توجد محادثات نشطة حالياً',
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: brandNavy,
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
                          itemCount: filtered.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final chat = filtered[index];
                            return _buildAdminChatCard(chat, brandNavy, headerGold);
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

  Widget _buildAdminChatCard(ChatModel chat, Color brandNavy, Color headerGold) {
    final timeStr = _formatChatTime(chat.lastMessageTime);

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              chat: chat,
              currentUserId: _adminUid ?? 'admin',
              currentUserName: _adminName ?? 'مشرف المنصة',
              currentUserRole: 'admin',
              currentUserAccountId: _adminAccountId ?? '',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Participants row
            Row(
              children: [
                // Lawyer Side
                Expanded(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 34,
                          height: 34,
                          color: const Color(0xFFFEF3C7),
                          child: chat.lawyerPhoto != null && chat.lawyerPhoto!.isNotEmpty
                              ? ImageUtils.buildSafeImage(photoUrl: chat.lawyerPhoto, fit: BoxFit.cover)
                              : const Center(child: Icon(Icons.gavel_rounded, size: 18, color: Color(0xFFD49B1A))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chat.lawyerName,
                              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: brandNavy),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              chat.lawyerAccountId.isNotEmpty
                                  ? 'معرّف: ${chat.lawyerAccountId}'
                                  : 'محامٍ',
                              style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFFD49B1A), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.sync_alt_rounded, size: 18, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),

                // Client Side
                Expanded(
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: 34,
                          height: 34,
                          color: const Color(0xFFE0E7FF),
                          child: chat.clientPhoto != null && chat.clientPhoto!.isNotEmpty
                              ? ImageUtils.buildSafeImage(photoUrl: chat.clientPhoto, fit: BoxFit.cover)
                              : const Center(child: Icon(Icons.person_rounded, size: 18, color: Color(0xFF4338CA))),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              chat.clientName,
                              style: GoogleFonts.cairo(fontSize: 13, fontWeight: FontWeight.w800, color: brandNavy),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              chat.clientAccountId.isNotEmpty
                                  ? 'معرّف: ${chat.clientAccountId}'
                                  : 'عميل',
                              style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 18, color: Color(0xFFF1F5F9)),

            // Last message and time
            Row(
              children: [
                Expanded(
                  child: Text(
                    chat.lastMessage.isNotEmpty ? chat.lastMessage : 'محادثة نشطة',
                    style: GoogleFonts.cairo(fontSize: 12.5, color: const Color(0xFF475569)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  timeStr,
                  style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
