import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/utils/search_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/firestore_service.dart';
import '../../../core/utils/recent_lawyers_tracker.dart';
import '../../custom_widgets/profile_details_modal.dart';

// ============================================================================
// AdminRecentLawyersScreen
// Dedicated screen displaying verified & active approved lawyers roster.
// ============================================================================

class AdminRecentLawyersScreen extends StatefulWidget {
  const AdminRecentLawyersScreen({super.key});

  @override
  State<AdminRecentLawyersScreen> createState() => _AdminRecentLawyersScreenState();
}

class _AdminRecentLawyersScreenState extends State<AdminRecentLawyersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  late Set<String> _initialSeenIds;

  @override
  void initState() {
    super.initState();
    _initialSeenIds = Set<String>.from(RecentLawyersTracker.seenLawyerIdsNotifier.value);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildAvatar(LawyerModel lawyer, double size) {
    final fallback = _buildFallbackAvatar(lawyer.name, size);
    final content = ClipOval(
      child: AppImageUtils.buildAvatarImage(
        photoBase64: lawyer.photoBase64,
        photoUrl: lawyer.photoUrl,
        width: size,
        height: size,
        fallback: fallback,
      ),
    );

    return GestureDetector(
      // Normal tap → open lawyer profile
      onTap: () => ProfileDetailsModal.showLawyerModal(context, lawyer: lawyer, isAdmin: true),
      // Long press → view full-screen photo
      onLongPress: () {
        if ((lawyer.photoBase64 != null && lawyer.photoBase64!.isNotEmpty) ||
            (lawyer.photoUrl != null && lawyer.photoUrl!.isNotEmpty)) {
          ProfileDetailsModal.openPhotoViewer(
            context,
            name: lawyer.name,
            photoBase64: lawyer.photoBase64,
            photoUrl: lawyer.photoUrl,
            subtitle: 'محامي - موثق العقود',
          );
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0B2A5B),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: ClipOval(child: content),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String name, double size) {
    final letter = name.trim().isNotEmpty ? name.trim().characters.first : 'م';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2A5B), Color(0xFF1E2E60)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(size / 2.8),
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.cairo(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFD49B1A),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0B2A5B), size: 18),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.verified_user_rounded, color: Color(0xFF0B2A5B), size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'آخر المحامين المنضمين',
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0B2A5B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
            ),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.rtl,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'ابحث باسم المحامي، المدينة، أو التخصص...',
                hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5),
                ),
              ),
            ),
          ),

          // Lawyers List
          Expanded(
            child: StreamBuilder<List<LawyerModel>>(
              stream: _firestoreService.getRecentApprovedLawyers(limit: 50),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: headerGold));
                }

                final allApproved = snapshot.data ?? [];
                if (allApproved.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    RecentLawyersTracker.markAllApprovedAsSeen(allApproved);
                  });
                }
                final filtered = allApproved.where((l) {
                  return AppSearchUtils.matchesAny(_searchQuery, [
                    l.name,
                    l.accountId,
                    l.city,
                    l.phone,
                  ]);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Color(0xFFEFF6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_search_rounded, color: Color(0xFF2563EB), size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'لا يوجد محامون معتمدون بعد',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'جرب البحث بكلمات أو مدن أخرى'
                                : 'عند اعتماد طلبات انضمام جديدة ستظهر في هذا السجل فورياً',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final lawyer = filtered[index];
                    return _buildLawyerItem(lawyer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLawyerItem(LawyerModel lawyer) {
    final bool isUnreadBefore = !_initialSeenIds.contains(lawyer.uid);
    final bool isNewlyJoined = isUnreadBefore ||
        DateTime.now().difference(lawyer.effectiveJoinedAt).inHours < 48;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => ProfileDetailsModal.showLawyerModal(
            context,
            lawyer: lawyer,
            isAdmin: true,
            onReject: (uid) => _firestoreService.rejectLawyer(uid),
          ),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _buildAvatar(lawyer, 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lawyer.name,
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0B2A5B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isNewlyJoined) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFEF3C7),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFFDE68A)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.star_rounded, size: 12, color: Color(0xFFD97706)),
                                  const SizedBox(width: 3),
                                  Text(
                                    'منضم حديثاً',
                                    style: GoogleFonts.cairo(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFFB45309),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF10B981),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'معتمد',
                                  style: GoogleFonts.cairo(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF059669),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'محامي - موثق العقود${lawyer.accountId.isNotEmpty ? " • معرّف: ${AccountIdUtils.formatForDisplay(lawyer.accountId)}" : ""}',
                        style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Row(
                        children: [
                          Text(
                            '📍 ${lawyer.city}',
                            style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF94A3B8)),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '📞 ${PhoneUtils.toLocalDisplay(lawyer.phone)}',
                            style: GoogleFonts.cairo(fontSize: 11, color: const Color(0xFF94A3B8)),
                            textDirection: TextDirection.ltr,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
