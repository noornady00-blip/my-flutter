// ==============================================================================
// 🚫 BLOCKED CONTACTS & ACCOUNTS SCREEN (الجهات المحظورة)
// ==============================================================================
// Displays list of blocked users with 12-digit account ID, avatar, and instant
// unblock action. Completely hides private info (phone) while keeping account ID visible.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../network/chat_service.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../custom_widgets/app_logo_badge.dart';

class BlockedUsersScreen extends StatefulWidget {
  final String currentUserId;

  const BlockedUsersScreen({
    super.key,
    required this.currentUserId,
  });

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final ChatService _chatService = ChatService();

  @override
  Widget build(BuildContext context) {
    const Color brandNavy = Color(0xFF0B2A5B);
    const Color brandGold = Color(0xFFD49B1A);
    const Color pageBg = Color(0xFFFCFBF9);

    return Scaffold(
      backgroundColor: pageBg,
      appBar: AppBar(
        backgroundColor: brandGold,
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
              'الجهات المحظورة',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: brandNavy,
              ),
            ),
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
      ),
      body: SafeArea(
        child: StreamBuilder<List<String>>(
          stream: _chatService.getBlockedUsersStream(widget.currentUserId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: brandNavy),
              );
            }

            final blockedUids = snapshot.data ?? [];

            if (blockedUids.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          size: 46,
                          color: Color(0xFF10B981),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'لا توجد جهات محظورة',
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: brandNavy,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'قائمة الحظر فارغة. يمكنك التواصل مع جميع المحامين والعملاء بحرية وأمان.',
                        style: GoogleFonts.cairo(
                          fontSize: 13.5,
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

            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              physics: const BouncingScrollPhysics(),
              itemCount: blockedUids.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final targetUid = blockedUids[index];
                return _buildBlockedUserCard(targetUid, brandNavy, brandGold);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildBlockedUserCard(String targetUid, Color brandNavy, Color brandGold) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: FirebaseFirestore.instance.collection('users').doc(targetUid).get(),
      builder: (context, snapshot) {
        final userData = snapshot.data?.data() ?? {};
        final name = userData['name']?.toString() ?? 'مستخدم المنصة';
        final photoUrl = userData['photoUrl']?.toString();
        final photoBase64 = userData['photoBase64']?.toString();
        final accountId = userData['accountId']?.toString() ?? '';
        final role = userData['role']?.toString() ?? 'client';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.6), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Row: Avatar + Name + Account ID + Unblock Button
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  // Avatar with Red Suspended ring
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFEF4444), width: 1.8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: AppImageUtils.buildAvatarImage(
                        photoBase64: photoBase64,
                        photoUrl: photoUrl,
                        width: 48,
                        height: 48,
                        fallback: Center(
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1) : 'م',
                            style: GoogleFonts.cairo(
                              color: brandNavy,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name and Account ID (Phone is strictly removed)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                name,
                                style: GoogleFonts.cairo(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (role == 'lawyer')
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: brandGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'محامٍ ⚖️',
                                  style: GoogleFonts.cairo(fontSize: 10, color: const Color(0xFFB45309), fontWeight: FontWeight.w800),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // 12-Digit Account ID with copy
                        if (accountId.isNotEmpty)
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: accountId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم نسخ المعرّف (12 رقم) بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                  backgroundColor: brandNavy,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'المعرّف: ${AccountIdUtils.formatForDisplay(accountId)}',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF92400E),
                                  ),
                                  textDirection: TextDirection.ltr,
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.copy_rounded, size: 12, color: Color(0xFFB45309)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Unblock Button
                  ElevatedButton.icon(
                    onPressed: () async {
                      await _chatService.unblockUser(
                        currentUserId: widget.currentUserId,
                        targetUserId: targetUid,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'تم فك الحظر عن $name بنجاح',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                            textDirection: TextDirection.rtl,
                          ),
                          backgroundColor: const Color(0xFF10B981),
                        ),
                      );
                    },
                    icon: const Icon(Icons.lock_open_rounded, size: 15),
                    label: Text(
                      'فك الحظر',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2A5B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Suspended Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.block_rounded, size: 14, color: Color(0xFFDC2626)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'هذا الحساب موقوف ومحظور من المراسلة معك.',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
