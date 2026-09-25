import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/search_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/firestore_service.dart';
import '../../../network/notification_service.dart';
import '../../custom_widgets/profile_details_modal.dart';
import '../../custom_widgets/glass_widgets.dart';
import '../../custom_widgets/app_dialog.dart';

// ============================================================================
// AdminPendingLawyersScreen
// Dedicated screen for reviewing, approving, or rejecting new lawyer registrations.
// ============================================================================

class AdminPendingLawyersScreen extends StatefulWidget {
  const AdminPendingLawyersScreen({super.key});

  @override
  State<AdminPendingLawyersScreen> createState() => _AdminPendingLawyersScreenState();
}

class _AdminPendingLawyersScreenState extends State<AdminPendingLawyersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    NotificationService().markNotificationsReadForEntity(type: 'lawyer_pending');
    NotificationService().markNotificationsReadForEntity(type: 'lawyer_registration');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _confirmAction({
    required String title,
    required String message,
    required bool isApprove,
    required Future<void> Function() onConfirm,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final bool? confirmed;
    if (isApprove) {
      confirmed = await AppDialog.confirm(
        context,
        title: title,
        message: message,
        confirmLabel: 'تأكيد الاعتماد',
        cancelLabel: 'إلغاء',
        icon: Icons.verified_user_rounded,
        primaryColor: const Color(0xFF10B981),
        lightBgColor: const Color(0xFFECFDF5),
        borderColor: const Color(0xFFA7F3D0),
      );
    } else {
      confirmed = await AppDialog.deleteConfirm(
        context,
        title: title,
        message: message,
        confirmLabel: 'تأكيد الرفض',
        cancelLabel: 'إلغاء',
        icon: Icons.warning_amber_rounded,
      );
    }

    if (confirmed == true && mounted) {
      await onConfirm();
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              isApprove ? 'تم اعتماد المحامي بنجاح وتفعيل حسابه' : 'تم رفض الطلب وحذف بيانات المحامي نهائياً',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
            backgroundColor: isApprove ? const Color(0xFF10B981) : const Color(0xFFDC2626),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
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
            subtitle: 'محامٍ ومستشار قانوني',
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
              child: const Icon(Icons.gavel_rounded, color: Color(0xFF0B2A5B), size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'طلبات انضمام المحامين',
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
          // Search Box & Header Stats
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

          // Requests List
          Expanded(
            child: StreamBuilder<List<LawyerModel>>(
              stream: _firestoreService.getPendingLawyers(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: headerGold),
                  );
                }

                final allPending = snapshot.data ?? [];
                final filtered = allPending.where((l) {
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
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'لا توجد طلبات انضمام جديدة حالياً',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'جرب البحث بكلمات أخرى أو مسح شريط البحث'
                                : 'تمت مراجعة واعتماد كافة طلبات المحامين المسجلة بالمنصة',
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
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final lawyer = filtered[index];
                    return _buildPendingCard(lawyer);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCard(LawyerModel lawyer) {
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row: Avatar, Info, and Inspect Profile Button
          InkWell(
            onTap: () => ProfileDetailsModal.showLawyerModal(
              context,
              lawyer: lawyer,
              isAdmin: true,
              onApprove: (uid) => _firestoreService.approveLawyer(uid),
              onReject: (uid) => _firestoreService.rejectLawyer(uid),
            ),
            borderRadius: BorderRadius.circular(14),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                _buildAvatar(lawyer, 56),
                const SizedBox(width: 14),
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
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF0B2A5B),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                            ),
                            child: Text(
                              'بانتظار المراجعة',
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFD97706),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '⚖️ محامٍ ومستشار قانوني',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF2563EB),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '📍 ${lawyer.city}${lawyer.accountId.isNotEmpty ? " • معرّف: ${lawyer.accountId}" : ""}',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Contact details bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              textDirection: TextDirection.rtl,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'رقم الهاتف: ',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      PhoneUtils.formatForDisplay(lawyer.phone),
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  ],
                ),
                InkWell(
                  onTap: () => ProfileDetailsModal.showLawyerModal(
                    context,
                    lawyer: lawyer,
                    isAdmin: true,
                    onApprove: (uid) => _firestoreService.approveLawyer(uid),
                    onReject: (uid) => _firestoreService.rejectLawyer(uid),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'فحص المستندات',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFD49B1A),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Color(0xFFD49B1A)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Approve / Reject / Call
          Row(
            children: [
              // Reject
              Expanded(
                flex: 2,
                child: GlassButton(
                  onPressed: () => _confirmAction(
                    title: 'رفض وحذف الطلب نهائياً',
                    message: 'سيتم حذف بيانات المحامي ${lawyer.name} نهائياً من المنصة. هذا الإجراء لا يمكن التراجع عنه.',
                    isApprove: false,
                    onConfirm: () => _firestoreService.rejectLawyer(lawyer.uid),
                  ),
                  backgroundColor: const Color(0xFFFFF1F2),
                  borderColor: const Color(0xFFFDA4AF).withValues(alpha: 0.6),
                  textColor: const Color(0xFFE11D48),
                  icon: Icons.close_rounded,
                  label: 'رفض',
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 10),
                  borderRadius: 12,
                ),
              ),
              const SizedBox(width: 8),

              // Approve
              Expanded(
                flex: 3,
                child: GlassButton(
                  onPressed: () => _confirmAction(
                    title: 'اعتماد وتفعيل المحامي',
                    message: 'هل أنت متأكد من قبول واعتماد المحامي ${lawyer.name} وتفعيل ظهوره في المنصة؟',
                    isApprove: true,
                    onConfirm: () => _firestoreService.approveLawyer(lawyer.uid),
                  ),
                  backgroundColor: const Color(0xFFECFDF5),
                  borderColor: const Color(0xFFA7F3D0).withValues(alpha: 0.8),
                  textColor: const Color(0xFF059669),
                  icon: Icons.check_circle_rounded,
                  label: 'الموافقة والاعتماد',
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
                  borderRadius: 12,
                ),
              ),
              const SizedBox(width: 8),

              // Call
              GlassButton(
                onPressed: () async {
                  final clean = lawyer.phone.replaceAll(RegExp(r'[^0-9+]'), '');
                  final uri = Uri.parse('tel:$clean');
                  if (await canLaunchUrl(uri)) launchUrl(uri);
                },
                backgroundColor: const Color(0xFFEFF6FF),
                borderColor: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                padding: const EdgeInsets.all(9),
                borderRadius: 12,
                child: const Icon(Icons.phone_rounded, size: 18, color: Color(0xFF2563EB)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
