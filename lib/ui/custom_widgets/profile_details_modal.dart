// ==============================================================================
// 📋 PROFILE DETAILS MODAL COMPONENT (LAWYER & CLIENT)
// ==============================================================================
// Displays interactive bottom sheet modal with lawyer/client credentials,
// high-resolution lightbox photo viewer, WhatsApp direct action, and call triggers.
// ==============================================================================

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/lawyer.dart';
import '../../data/models/user_model.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/utils/image_utils.dart';
import '../../core/utils/account_id_utils.dart';
import '../screens/chat/chat_screen.dart';

OverlayEntry? _activeProfileToast;

void _showFloatingCopyToast(BuildContext context, String message) {
  _activeProfileToast?.remove();
  _activeProfileToast = null;

  final overlay =
      Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.of(context);

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      top: MediaQuery.of(ctx).padding.top + 16,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, (1 - value) * -20),
                child: Opacity(
                  opacity: value.clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2A5B),
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: const Color(0xFFD49B1A), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );

  _activeProfileToast = entry;
  overlay.insert(entry);

  Future.delayed(const Duration(milliseconds: 2400), () {
    if (_activeProfileToast == entry) {
      entry.remove();
      _activeProfileToast = null;
    }
  });
}

/// Ultra-Executive 3D Glassmorphic Profile Details Modal for Lawyers & Clients
class ProfileDetailsModal {
  static Future<void> launchCall(String phone) async {
    final cleanPhone = PhoneUtils.tryNormalize(phone) ?? phone;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  static Future<void> launchWhatsApp(String phone) async {
    final cleanPhone = PhoneUtils.formatWhatsAppNumber(phone);
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// Opens an interactive full-screen photo viewer (Glassmorphism Lightbox)
  static void openPhotoViewer(
    BuildContext context, {
    required String name,
    String? photoBase64,
    String? photoUrl,
    String? subtitle,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => _PhotoViewerDialog(
        name: name,
        photoBase64: photoBase64,
        photoUrl: photoUrl,
        subtitle: subtitle,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Lawyer Details Modal Sheet
  // ---------------------------------------------------------------------------
  static void showLawyerModal(
    BuildContext context, {
    required LawyerModel lawyer,
    bool isAdmin = false,
    Future<void> Function(String uid)? onApprove,
    Future<void> Function(String uid)? onReject,
    bool isAlreadyInChat = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      useSafeArea: false,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: _LawyerModalSheet(
            lawyer: lawyer,
            isAdmin: isAdmin,
            onApprove: onApprove,
            onReject: onReject,
            isAlreadyInChat: isAlreadyInChat,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Client Details Modal Sheet
  // ---------------------------------------------------------------------------
  static void showClientModal(
    BuildContext context, {
    required UserModel client,
    bool isAdmin = false,
    VoidCallback? onDelete,
    bool isAlreadyInChat = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      useSafeArea: false,
      builder: (ctx) => Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: _ClientModalSheet(
            client: client,
            isAdmin: isAdmin,
            onDelete: onDelete,
            isAlreadyInChat: isAlreadyInChat,
          ),
        ),
      ),
    );
  }

  /// Opens lawyer or client profile modal automatically based on UID/role
  static Future<void> showProfileByUid(
    BuildContext context, {
    required String uid,
    String? role,
    String? fallbackName,
    String? fallbackPhone,
    String? fallbackPhoto,
    String? fallbackPhotoBase64,
    String? fallbackAccountId,
    bool isAdmin = false,
    bool isAlreadyInChat = false,
  }) async {
    final effectiveRole = role?.toLowerCase() ?? '';
    final cleanUid = uid.trim();
    final cleanName = (fallbackName != null && fallbackName.trim().isNotEmpty)
        ? fallbackName.trim()
        : (effectiveRole == 'lawyer' ? 'محامي - موثق العقود' : 'مستخدم المنصة');

    if (effectiveRole == 'lawyer') {
      final initialLawyer = LawyerModel(
        uid: cleanUid,
        name: cleanName,
        phone: fallbackPhone ?? '',
        whatsapp: fallbackPhone ?? '',
        city: 'السودان',
        accountId: fallbackAccountId ?? '',
        photoUrl: fallbackPhoto,
        photoBase64: fallbackPhotoBase64,
        status: 'approved',
      );
      showLawyerModal(context, lawyer: initialLawyer, isAdmin: isAdmin, isAlreadyInChat: isAlreadyInChat);
    } else {
      final initialClient = UserModel(
        uid: cleanUid,
        name: cleanName,
        phone: fallbackPhone ?? '',
        photoUrl: fallbackPhoto,
        photoBase64: fallbackPhotoBase64,
        accountId: fallbackAccountId ?? '',
        role: effectiveRole.isNotEmpty ? effectiveRole : 'client',
        createdAt: DateTime.now(),
      );
      showClientModal(context, client: initialClient, isAdmin: isAdmin, isAlreadyInChat: isAlreadyInChat);
    }
  }
}

// -----------------------------------------------------------------------------
// Official WhatsApp Vector Icon
// -----------------------------------------------------------------------------
class WhatsAppIcon extends StatelessWidget {
  final double size;
  final Color color;

  const WhatsAppIcon({super.key, this.size = 24, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _WhatsAppPainter(color: color),
      ),
    );
  }
}

class _WhatsAppPainter extends CustomPainter {
  final Color color;
  _WhatsAppPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final bubblePath = Path();
    bubblePath.moveTo(19.05, 4.95);
    bubblePath.cubicTo(17.18, 3.08, 14.69, 2.05, 12.04, 2.05);
    bubblePath.cubicTo(6.58, 2.05, 2.13, 6.5, 2.13, 11.96);
    bubblePath.cubicTo(2.13, 13.71, 2.59, 15.41, 3.45, 16.91);
    bubblePath.lineTo(2.05, 22.05);
    bubblePath.lineTo(7.3, 20.67);
    bubblePath.cubicTo(8.75, 21.46, 10.38, 21.88, 12.04, 21.88);
    bubblePath.cubicTo(17.5, 21.88, 21.95, 17.43, 21.95, 11.96);
    bubblePath.cubicTo(21.95, 9.31, 20.92, 6.82, 19.05, 4.95);
    bubblePath.close();

    canvas.drawPath(bubblePath, strokePaint);

    final phonePath = Path();
    phonePath.moveTo(15.8, 13.8);
    phonePath.cubicTo(15.55, 13.68, 14.33, 13.08, 14.11, 12.99);
    phonePath.cubicTo(13.88, 12.91, 13.72, 12.87, 13.55, 13.11);
    phonePath.cubicTo(13.38, 13.36, 12.91, 13.92, 12.77, 14.09);
    phonePath.cubicTo(12.62, 14.26, 12.48, 14.28, 12.23, 14.16);
    phonePath.cubicTo(11.98, 14.04, 11.18, 13.76, 10.23, 12.92);
    phonePath.cubicTo(9.49, 12.26, 9.0, 11.45, 8.85, 11.2);
    phonePath.cubicTo(8.71, 10.95, 8.83, 10.82, 8.96, 10.69);
    phonePath.cubicTo(9.07, 10.58, 9.21, 10.4, 9.33, 10.26);
    phonePath.cubicTo(9.45, 10.11, 9.5, 10.01, 9.58, 9.84);
    phonePath.cubicTo(9.66, 9.67, 9.62, 9.53, 9.56, 9.4);
    phonePath.cubicTo(9.5, 9.28, 9.0, 8.06, 8.8, 7.56);
    phonePath.cubicTo(8.6, 7.08, 8.39, 7.14, 8.24, 7.13);
    phonePath.lineTo(7.76, 7.13);
    phonePath.cubicTo(7.59, 7.13, 7.32, 7.19, 7.1, 7.44);
    phonePath.cubicTo(6.87, 7.69, 6.22, 8.3, 6.22, 9.53);
    phonePath.cubicTo(6.22, 10.76, 7.12, 11.96, 7.25, 12.13);
    phonePath.cubicTo(7.37, 12.3, 9.02, 14.83, 11.53, 15.92);
    phonePath.cubicTo(12.13, 16.18, 12.6, 16.33, 12.96, 16.45);
    phonePath.cubicTo(13.56, 16.64, 14.11, 16.61, 14.54, 16.55);
    phonePath.cubicTo(15.02, 16.48, 16.01, 15.95, 16.22, 15.37);
    phonePath.cubicTo(16.43, 14.79, 16.43, 14.3, 16.37, 14.19);
    phonePath.cubicTo(16.3, 14.07, 16.14, 14.0, 15.8, 13.8);
    phonePath.close();

    canvas.drawPath(phonePath, fillPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// -----------------------------------------------------------------------------
// Lawyer Modal Sheet Widget
// -----------------------------------------------------------------------------
class _LawyerModalSheet extends StatefulWidget {
  final LawyerModel lawyer;
  final bool isAdmin;
  final Future<void> Function(String uid)? onApprove;
  final Future<void> Function(String uid)? onReject;
  final bool isAlreadyInChat;

  const _LawyerModalSheet({
    required this.lawyer,
    required this.isAdmin,
    this.onApprove,
    this.onReject,
    this.isAlreadyInChat = false,
  });

  @override
  State<_LawyerModalSheet> createState() => _LawyerModalSheetState();
}

class _LawyerModalSheetState extends State<_LawyerModalSheet> {
  bool _isActionLoading = false;
  late LawyerModel _lawyer;

  @override
  void initState() {
    super.initState();
    _lawyer = widget.lawyer;
    if (_lawyer.city.isEmpty ||
        _lawyer.photoBase64 == null ||
        _lawyer.photoBase64!.trim().isEmpty ||
        _lawyer.photoUrl == null ||
        _lawyer.photoUrl!.trim().isEmpty) {
      _loadFullLawyerData();
    }
  }

  Future<void> _loadFullLawyerData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? lawyerDoc;
      if (_lawyer.uid.isNotEmpty && !_lawyer.uid.startsWith('guest_')) {
        lawyerDoc = await FirebaseFirestore.instance
            .collection('lawyers')
            .doc(_lawyer.uid)
            .get();
      }
      if ((lawyerDoc == null || !lawyerDoc.exists) && _lawyer.phone.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('lawyers')
            .where('phone', isEqualTo: _lawyer.phone.trim())
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) lawyerDoc = snap.docs.first;
      }

      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      final targetUid = _lawyer.uid.isNotEmpty && !_lawyer.uid.startsWith('guest_')
          ? _lawyer.uid
          : lawyerDoc?.id;
      if (targetUid != null && targetUid.isNotEmpty) {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(targetUid)
            .get();
      }

      if (mounted) {
        final lData = lawyerDoc?.exists == true ? lawyerDoc!.data() : null;
        final uData = userDoc?.exists == true ? userDoc!.data() : null;

        if (lData != null || uData != null) {
          final mergedMap = <String, dynamic>{
            ...?uData,
            ...?lData,
          };
          final lRawPhoto = lData?['photo']?.toString() ?? uData?['photo']?.toString();
          final resolvedBase64 = lData?['photoBase64']?.toString() ??
              lData?['user_profile_photo_base64']?.toString() ??
              lData?['user_profile_photo']?.toString() ??
              uData?['photoBase64']?.toString() ??
              uData?['user_profile_photo_base64']?.toString() ??
              uData?['user_profile_photo']?.toString() ??
              (lRawPhoto != null && !lRawPhoto.startsWith('http') && lRawPhoto.length > 50 ? lRawPhoto : null);

          final resolvedUrl = lData?['photoUrl']?.toString() ??
              lData?['user_profile_photo_url']?.toString() ??
              lData?['imageUrl']?.toString() ??
              uData?['photoUrl']?.toString() ??
              uData?['user_profile_photo_url']?.toString() ??
              uData?['imageUrl']?.toString() ??
              (lRawPhoto != null && (lRawPhoto.startsWith('http') || lRawPhoto.startsWith('data:image')) ? lRawPhoto : null);

          if (resolvedBase64 != null && resolvedBase64.isNotEmpty) {
            mergedMap['photoBase64'] = resolvedBase64;
          }
          if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
            mergedMap['photoUrl'] = resolvedUrl;
          }

          setState(() {
            _lawyer = LawyerModel.fromMap(
              mergedMap,
              targetUid ?? _lawyer.uid,
            );
          });
        }
      }
    } catch (_) {}
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final lawyer = _lawyer;
    final isApproved = lawyer.status == 'approved';
    final isPending = lawyer.status == 'pending';
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 36,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        bottomInset + bottomPadding + 18,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Handle & Close
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF475569),
                      size: 19,
                    ),
                  ),
                ),
                Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 36), // Balanced spacing
              ],
            ),
            const SizedBox(height: 14),

            // Avatar & Lightbox Trigger (Clean, modern, no intrusive overlay icons)
            Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => ProfileDetailsModal.openPhotoViewer(
                  context,
                  name: lawyer.name,
                  photoBase64: lawyer.photoBase64,
                  photoUrl: lawyer.photoUrl,
                  subtitle: lawyer.city.trim().isNotEmpty
                      ? lawyer.city
                      : 'محامٍ مُعتمد',
                ),
                child: Container(
                  width: 96,
                  height: 96,
                  padding: const EdgeInsets.all(3.0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD49B1A), Color(0xFF0B2A5B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.18),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: ClipOval(
                      child: _buildAvatarContent(lawyer),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Name & Verified Tag
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    lawyer.name,
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isApproved) ...[
                  const SizedBox(width: 6),
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFFD49B1A),
                    size: 22,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),

            // Location Badge (if available)
            if (lawyer.city.trim().isNotEmpty) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 14, color: Color(0xFFD49B1A)),
                      const SizedBox(width: 5),
                      Text(
                        lawyer.city.trim(),
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B2A5B),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],

              const SizedBox(height: 16),
              // Iconic Action Buttons
              _buildIconic3DActionButtons(context, lawyer),
              const SizedBox(height: 16),

            // Detailed Info Cards
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // ID (ALWAYS VISIBLE & ONLY SENSITIVE ITEM SHOWN WHEN BLOCKED)
                  if (lawyer.accountId.isNotEmpty) ...[
                    _buildDetailRow(
                      iconWidget: const Icon(Icons.badge_rounded,
                          color: Color(0xFFD49B1A), size: 18),
                      label: 'ID',
                      value: AccountIdUtils.formatForDisplay(lawyer.accountId),
                      color: const Color(0xFFD49B1A),
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: lawyer.accountId));
                        _showFloatingCopyToast(context, 'تم نسخ ID بنجاح');
                      },
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  ],

                  // Phone & WhatsApp
                  _buildDetailRow(
                    iconWidget: const Icon(Icons.phone_android_rounded,
                        color: Color(0xFF3B82F6), size: 18),
                    label: 'رقم الهاتف',
                    value: lawyer.phone,
                    isPhone: true,
                    color: const Color(0xFF3B82F6),
                    onCopy: () {
                      Clipboard.setData(ClipboardData(text: lawyer.phone));
                      _showCopyToast(context, 'تم نسخ رقم الهاتف بنجاح');
                    },
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  _buildDetailRow(
                    iconWidget: const WhatsAppIcon(
                        size: 18, color: Color(0xFF10B981)),
                    label: 'رقم الواتساب',
                    value: lawyer.whatsapp.isNotEmpty
                        ? lawyer.whatsapp
                        : lawyer.phone,
                    isPhone: true,
                    color: const Color(0xFF10B981),
                    onCopy: () {
                      final val = lawyer.whatsapp.isNotEmpty
                          ? lawyer.whatsapp
                          : lawyer.phone;
                      Clipboard.setData(ClipboardData(text: val));
                      _showCopyToast(context, 'تم نسخ رقم الواتساب بنجاح');
                    },
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),

                  _buildDetailRow(
                    iconWidget: Icon(
                      isApproved
                          ? Icons.verified_user_rounded
                          : (isPending
                              ? Icons.pending_rounded
                              : Icons.error_rounded),
                      color: isApproved
                          ? const Color(0xFF10B981)
                          : (isPending
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444)),
                      size: 18,
                    ),
                    label: 'حالة الحساب',
                    value: isApproved
                        ? 'محامي - موثق العقود'
                        : (isPending ? 'قيد مراجعة الإدارة' : 'مرفوض'),
                    color: isApproved
                        ? const Color(0xFF10B981)
                        : (isPending
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFFEF4444)),
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  _buildDetailRow(
                    iconWidget: const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF8B5CF6), size: 18),
                    label: 'تاريخ الانضمام',
                    value: _formatDate(lawyer.createdAt),
                    color: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
            ),

            // Admin Actions
            if (widget.isAdmin && isPending) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _isActionLoading
                          ? null
                          : () async {
                              if (widget.onReject != null) {
                                final nav = Navigator.of(context);
                                setState(() => _isActionLoading = true);
                                await widget.onReject!(lawyer.uid);
                                if (!mounted) return;
                                nav.pop();
                              }
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: const Color(0xFFFECACA), width: 1.5),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.close_rounded,
                                color: Color(0xFFDC2626), size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'رفض الطلب',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFDC2626),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: InkWell(
                      onTap: _isActionLoading
                          ? null
                          : () async {
                              if (widget.onApprove != null) {
                                final nav = Navigator.of(context);
                                setState(() => _isActionLoading = true);
                                await widget.onApprove!(lawyer.uid);
                                if (!mounted) return;
                                nav.pop();
                              }
                            },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981)
                                  .withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_rounded,
                                color: Colors.white, size: 18),
                            const SizedBox(width: 6),
                            Text(
                              'قبول واعتماد المحامي',
                              style: GoogleFonts.cairo(
                                fontSize: 14,
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
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent(LawyerModel lawyer) {
    return AppImageUtils.buildAvatarImage(
      photoBase64: lawyer.photoBase64,
      photoUrl: lawyer.photoUrl,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      fallback: _buildAvatarFallback(lawyer),
    );
  }

  Widget _buildAvatarFallback([LawyerModel? lawyer]) {
    final String initial = (lawyer != null && lawyer.name.trim().isNotEmpty)
        ? lawyer.name.trim().characters.first
        : 'م';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E2E5C),
            Color(0xFF0B2A5B),
            Color(0xFF0A1229),
          ],
        ),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE082),
              Color(0xFFD49B1A),
            ],
          ).createShader(bounds),
          child: Text(
            initial,
            style: GoogleFonts.cairo(
              fontSize: 42,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }

  void _showCopyToast(BuildContext context, String message) {
    _showFloatingCopyToast(context, message);
  }



  Widget _buildIconic3DActionButtons(
      BuildContext context, LawyerModel lawyer) {
    final phone = lawyer.phone;
    final whatsapp = lawyer.whatsapp;
    final targetWhatsapp = whatsapp.isNotEmpty ? whatsapp : phone;

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        // 1. Direct Chat
        Expanded(
          child: _ExecutiveModalActionButton(
            title: 'محادثة',
            iconWidget: const Icon(Icons.chat_bubble_rounded,
                color: Colors.white, size: 17),
            backgroundColor: const Color(0xFFD49B1A),
            borderColor: const Color(0xFFB8820B),
            shadowColor: const Color(0xFFD49B1A),
            onTap: () {
              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                _showCopyToast(context, 'يرجى تسجيل الدخول لبدء محادثة');
                return;
              }
              if (currentUser.uid == lawyer.uid) {
                _showCopyToast(context, 'لا يمكنك بدء محادثة مع نفسك');
                return;
              }
              if (widget.isAlreadyInChat) {
                Navigator.of(context).pop();
                return;
              }
              final navigator = Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              navigator.push(
                MaterialPageRoute(
                  builder: (_) => ChatScreen(
                    lawyerUid: lawyer.uid,
                    lawyerName: lawyer.name,
                    lawyerAccountId: lawyer.accountId,
                    lawyerPhone: lawyer.phone,
                    lawyerPhotoUrl: lawyer.photoUrl,
                    lawyerPhotoBase64: lawyer.photoBase64,
                    currentUserRole: widget.isAdmin ? 'admin' : null,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),

        // 2. Direct Call
        Expanded(
          child: _ExecutiveModalActionButton(
            title: 'اتصال',
            iconWidget: const Icon(Icons.phone_rounded,
                color: Color(0xFFD49B1A), size: 17),
            backgroundColor: const Color(0xFF0B2A5B),
            borderColor: const Color(0xFF1E2E5C),
            shadowColor: const Color(0xFF0B2A5B),
            onTap: () => ProfileDetailsModal.launchCall(phone),
          ),
        ),
        const SizedBox(width: 8),

        // 3. WhatsApp
        Expanded(
          child: _ExecutiveModalActionButton(
            title: 'واتساب',
            iconWidget: const WhatsAppIcon(size: 17, color: Colors.white),
            backgroundColor: const Color(0xFF16A34A),
            borderColor: const Color(0xFF15803D),
            shadowColor: const Color(0xFF16A34A),
            onTap: () => ProfileDetailsModal.launchWhatsApp(targetWhatsapp),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required Widget iconWidget,
    required String label,
    required String value,
    required Color color,
    bool isPhone = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: iconWidget,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isPhone ? PhoneUtils.toLocalDisplay(value) : value,
              textDirection: (isPhone || label.toUpperCase().contains('ID') || label.contains('معرّف'))
                  ? TextDirection.ltr
                  : null,
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.copy_rounded,
                  size: 14, color: Color(0xFF334155)),
            ),
          ),
        ],
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Executive Action Button
// -----------------------------------------------------------------------------
class _ExecutiveModalActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final String title;
  final Widget iconWidget;
  final Color backgroundColor;
  final Color borderColor;
  final Color shadowColor;

  const _ExecutiveModalActionButton({
    required this.onTap,
    required this.title,
    required this.iconWidget,
    required this.backgroundColor,
    required this.borderColor,
    required this.shadowColor,
  });

  @override
  State<_ExecutiveModalActionButton> createState() =>
      _ExecutiveModalActionButtonState();
}

class _ExecutiveModalActionButtonState
    extends State<_ExecutiveModalActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        transform: Matrix4.diagonal3Values(
            _isPressed ? 0.98 : 1.0, _isPressed ? 0.98 : 1.0, 1.0),
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: widget.borderColor,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.shadowColor
                  .withValues(alpha: _isPressed ? 0.08 : 0.18),
              blurRadius: _isPressed ? 4 : 8,
              offset: Offset(0, _isPressed ? 1 : 2.5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          textDirection: TextDirection.rtl,
          children: [
            widget.iconWidget,
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                widget.title,
                style: GoogleFonts.cairo(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Lightbox Photo Viewer Dialog
// -----------------------------------------------------------------------------
class _PhotoViewerDialog extends StatelessWidget {
  final String name;
  final String? photoBase64;
  final String? photoUrl;
  final String? subtitle;

  const _PhotoViewerDialog({
    required this.name,
    this.photoBase64,
    this.photoUrl,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final imageWidget = AppImageUtils.buildAvatarImage(
      photoBase64: photoBase64,
      photoUrl: photoUrl,
      fit: BoxFit.contain,
      fallback: _buildBase64OrPlaceholder(),
    );

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF050B14).withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar: Close Button + Centered Name Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  textDirection: TextDirection.rtl,
                  children: [
                    // Close Glass Button
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        padding: const EdgeInsets.all(9),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.28),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),

                    // Name & Verified Badge Capsule
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1B2A),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFD49B1A),
                          width: 1.3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFD49B1A).withValues(alpha: 0.25),
                            blurRadius: 12,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFFD49B1A),
                            size: 17,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            name,
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 40),
                  ],
                ),
                const SizedBox(height: 16),

                // Main Image Container (Deep Slate/Navy Card from Screenshot)
                Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.64,
                    maxWidth: 410,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B172A),
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: InteractiveViewer(
                      minScale: 0.8,
                      maxScale: 5.0,
                      clipBehavior: Clip.antiAlias,
                      child: Center(
                        child: imageWidget,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Bottom Zoom Hint Pill
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 0.8,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.pinch_rounded,
                        color: Color(0xFFD49B1A),
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'يمكنك التكبير والسحب بإصبعين بحرية',
                        style: GoogleFonts.cairo(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBase64OrPlaceholder() {
    final bytes = AppImageUtils.safeDecodeBase64(photoBase64);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(
                color: const Color(0xFFD49B1A).withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.person_rounded,
              size: 64,
              color: Color(0xFFD49B1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد صورة شخصية مرفوعة بعد',
            style: GoogleFonts.cairo(
              color: Colors.white70,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Client Modal Sheet Widget
// -----------------------------------------------------------------------------
class _ClientModalSheet extends StatefulWidget {
  final UserModel client;
  final bool isAdmin;
  final VoidCallback? onDelete;
  final bool isAlreadyInChat;

  const _ClientModalSheet({
    required this.client,
    required this.isAdmin,
    this.onDelete,
    this.isAlreadyInChat = false,
  });

  @override
  State<_ClientModalSheet> createState() => _ClientModalSheetState();
}

class _ClientModalSheetState extends State<_ClientModalSheet> {
  late UserModel _client;

  @override
  void initState() {
    super.initState();
    _client = widget.client;
    if (_client.accountId.isEmpty ||
        _client.photoBase64 == null ||
        _client.photoBase64!.trim().isEmpty ||
        _client.photoUrl == null ||
        _client.photoUrl!.trim().isEmpty) {
      _loadFullClientData();
    }
  }

  Future<void> _loadFullClientData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? userDoc;
      Map<String, dynamic> directoryData = {};

      if (_client.uid.isNotEmpty && !_client.uid.startsWith('guest_')) {
        try {
          userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(_client.uid)
              .get()
              .timeout(const Duration(seconds: 3));
        } catch (_) {}
      }

      final cleanDigits = PhoneUtils.tryNormalize(_client.phone) ?? _client.phone;

      // Check phone_directory for immediate linked data and photo
      if (cleanDigits.isNotEmpty) {
        try {
          final dirDoc = await FirebaseFirestore.instance
              .collection('phone_directory')
              .doc(cleanDigits)
              .get()
              .timeout(const Duration(seconds: 3));
          if (dirDoc.exists && dirDoc.data() != null) {
            directoryData = dirDoc.data()!;
            final linkedUid = directoryData['uid']?.toString();
            if ((userDoc == null || !userDoc.exists) && linkedUid != null && linkedUid.isNotEmpty) {
              try {
                userDoc = await FirebaseFirestore.instance.collection('users').doc(linkedUid).get().timeout(const Duration(seconds: 3));
              } catch (_) {}
            }
          }
        } catch (_) {}
      }

      // Check users collection across all normalized phone variations
      if ((userDoc == null || !userDoc.exists) && _client.phone.isNotEmpty) {
        final phoneCandidates = <String>{
          _client.phone.trim(),
          _client.phone.replaceAll(' ', ''),
          if (cleanDigits.isNotEmpty) cleanDigits,
          if (cleanDigits.isNotEmpty) '0$cleanDigits',
          if (cleanDigits.isNotEmpty) '+249$cleanDigits',
          if (cleanDigits.isNotEmpty) '249$cleanDigits',
        }.where((p) => p.isNotEmpty).toList();

        for (final p in phoneCandidates) {
          try {
            final snap = await FirebaseFirestore.instance
                .collection('users')
                .where('phone', isEqualTo: p)
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 3));
            if (snap.docs.isNotEmpty) {
              userDoc = snap.docs.first;
              break;
            }
          } catch (_) {}
        }
      }

      // Check users collection by accountId
      if ((userDoc == null || !userDoc.exists) && _client.accountId.isNotEmpty) {
        final cleanAcc = AccountIdUtils.clean12Digits(_client.accountId);
        if (cleanAcc.isNotEmpty) {
          try {
            final accSnap = await FirebaseFirestore.instance
                .collection('users')
                .where('accountId', isEqualTo: cleanAcc)
                .limit(1)
                .get()
                .timeout(const Duration(seconds: 3));
            if (accSnap.docs.isNotEmpty) {
              userDoc = accSnap.docs.first;
            }
          } catch (_) {}
        }
      }

      DocumentSnapshot<Map<String, dynamic>>? lawyerDoc;
      final targetUid = _client.uid.isNotEmpty && !_client.uid.startsWith('guest_')
          ? _client.uid
          : (userDoc?.id ?? directoryData['uid']?.toString());

      if (targetUid != null && targetUid.isNotEmpty) {
        try {
          final lSnap = await FirebaseFirestore.instance
              .collection('lawyers')
              .doc(targetUid)
              .get()
              .timeout(const Duration(seconds: 3));
          if (lSnap.exists) lawyerDoc = lSnap;
        } catch (_) {}
      }

      if (mounted) {
        final uData = userDoc?.exists == true ? userDoc!.data() : null;
        final lData = lawyerDoc?.exists == true ? lawyerDoc!.data() : null;

        if (uData != null || lData != null || directoryData.isNotEmpty) {
          final mergedMap = <String, dynamic>{
            ...directoryData,
            ...?lData,
            ...?uData,
          };
          final fetched = UserModel.fromMap(mergedMap, targetUid ?? _client.uid);

          final rawPhoto = mergedMap['photo']?.toString();
          final resolvedUrl = (fetched.photoUrl != null && fetched.photoUrl!.isNotEmpty && fetched.photoUrl != 'default')
              ? fetched.photoUrl
              : (mergedMap['photoUrl']?.toString() ??
                  mergedMap['user_profile_photo_url']?.toString() ??
                  mergedMap['imageUrl']?.toString() ??
                  mergedMap['profileImage']?.toString() ??
                  (rawPhoto != null && (rawPhoto.startsWith('http') || rawPhoto.startsWith('data:image'))
                      ? rawPhoto
                      : null));

          final resolvedBase64 = (fetched.photoBase64 != null && fetched.photoBase64!.isNotEmpty && fetched.photoBase64 != 'default')
              ? fetched.photoBase64
              : (mergedMap['photoBase64']?.toString() ??
                  mergedMap['user_profile_photo_base64']?.toString() ??
                  mergedMap['user_profile_photo']?.toString() ??
                  (rawPhoto != null && !rawPhoto.startsWith('http') && rawPhoto.length > 50
                      ? rawPhoto
                      : null));

          setState(() {
            _client = _client.copyWith(
              name: fetched.name.isNotEmpty ? fetched.name : _client.name,
              phone: fetched.phone.isNotEmpty ? fetched.phone : _client.phone,
              role: fetched.role.isNotEmpty ? fetched.role : _client.role,
              accountId: fetched.accountId.isNotEmpty ? fetched.accountId : _client.accountId,
              photoUrl: (resolvedUrl != null && resolvedUrl.isNotEmpty && resolvedUrl != 'default')
                  ? resolvedUrl
                  : _client.photoUrl,
              photoBase64: (resolvedBase64 != null && resolvedBase64.isNotEmpty && resolvedBase64 != 'default')
                  ? resolvedBase64
                  : _client.photoBase64,
              createdAt: fetched.createdAt,
            );
          });
        }
      }
    } catch (_) {}
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final client = _client;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final isAdminRole = client.role == 'admin' || client.name.contains('مشرف') || client.name.contains('إدارة');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Color(0x38000000),
            blurRadius: 36,
            offset: Offset(0, -10),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        14,
        22,
        bottomInset + bottomPadding + 18,
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                ),
                Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 38),
              ],
            ),
            const SizedBox(height: 14),
            Center(
              child: Tooltip(
                message: _hasPhoto ? 'اضغط لعرض الصورة بحجم كامل' : '',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hasPhoto
                      ? () => ProfileDetailsModal.openPhotoViewer(
                            context,
                            name: client.name,
                            photoBase64: client.photoBase64,
                            photoUrl: client.photoUrl,
                            subtitle: isAdminRole ? 'مشرف المنصة' : 'عميل مسجل في المنصة',
                          )
                      : null,
                  child: Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isAdminRole
                          ? const LinearGradient(
                              colors: [Color(0xFFD49B1A), Color(0xFF0B2A5B)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isAdminRole ? null : const Color(0xFF0B2A5B),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                          blurRadius: 16,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: ClipOval(
                        child: _buildAvatarContent(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              client.name,
              style: GoogleFonts.cairo(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Center(
              child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    gradient: isAdminRole
                        ? const LinearGradient(
                            colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
                          )
                        : null,
                    color: isAdminRole ? null : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isAdminRole ? const Color(0xFFD49B1A) : const Color(0xFFBFDBFE),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isAdminRole) ...[
                        const Icon(Icons.shield_rounded, size: 15, color: Color(0xFF92400E)),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        isAdminRole ? 'مشرف المنصة • إدارة محاميك' : 'عميل مسجل في المنصة',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: isAdminRole ? const Color(0xFF92400E) : const Color(0xFF2563EB),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  // 1. Chat
                  Expanded(
                    child: _ExecutiveModalActionButton(
                      title: 'محادثة',
                      iconWidget: const Icon(Icons.chat_bubble_rounded,
                          color: Colors.white, size: 17),
                      backgroundColor: const Color(0xFFD49B1A),
                      borderColor: const Color(0xFFB8820B),
                      shadowColor: const Color(0xFFD49B1A),
                      onTap: () {
                        final currentUser = FirebaseAuth.instance.currentUser;
                        if (currentUser == null) {
                          _showFloatingCopyToast(
                              context, 'يرجى تسجيل الدخول لبدء محادثة');
                          return;
                        }
                        if (currentUser.uid == client.uid) {
                          _showFloatingCopyToast(
                              context, 'لا يمكنك بدء محادثة مع نفسك');
                          return;
                        }
                        if (widget.isAlreadyInChat) {
                          Navigator.of(context).pop();
                          return;
                        }
                        final navigator = Navigator.of(context, rootNavigator: true);
                        Navigator.of(context).pop();
                        navigator.push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              clientUid: client.uid,
                              clientName: client.name,
                              clientAccountId: client.accountId,
                              clientPhone: client.phone,
                              clientPhotoUrl: client.photoUrl,
                              clientPhotoBase64: client.photoBase64,
                              currentUserRole: widget.isAdmin ? 'admin' : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  if (!isAdminRole) ...[
                    const SizedBox(width: 8),

                    // 2. Call (Clients/Lawyers only)
                    Expanded(
                      child: _ExecutiveModalActionButton(
                        title: 'اتصال',
                        iconWidget: const Icon(Icons.phone_rounded,
                            color: Color(0xFFD49B1A), size: 17),
                        backgroundColor: const Color(0xFF0B2A5B),
                        borderColor: const Color(0xFF1E2E5C),
                        shadowColor: const Color(0xFF0B2A5B),
                        onTap: () =>
                            ProfileDetailsModal.launchCall(client.phone),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // 3. WhatsApp (Clients/Lawyers only)
                    Expanded(
                      child: _ExecutiveModalActionButton(
                        title: 'واتساب',
                        iconWidget:
                            const WhatsAppIcon(size: 17, color: Colors.white),
                        backgroundColor: const Color(0xFF16A34A),
                        borderColor: const Color(0xFF15803D),
                        shadowColor: const Color(0xFF16A34A),
                        onTap: () =>
                            ProfileDetailsModal.launchWhatsApp(client.phone),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  // ID (ALWAYS VISIBLE & ONLY SENSITIVE ITEM SHOWN WHEN BLOCKED)
                  if (client.accountId.isNotEmpty) ...[
                    _buildDetailRow(
                      context: context,
                      iconWidget: const Icon(Icons.badge_rounded,
                          color: Color(0xFFD49B1A), size: 18),
                      label: 'ID',
                      value: AccountIdUtils.formatForDisplay(client.accountId),
                      color: const Color(0xFFD49B1A),
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: client.accountId));
                        _showFloatingCopyToast(
                            context, 'تم نسخ ID بنجاح');
                      },
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  ],

                  // Phone
                  if (!isAdminRole && client.phone.isNotEmpty) ...[
                    _buildDetailRow(
                      context: context,
                      iconWidget: const Icon(Icons.phone_android_rounded,
                          color: Color(0xFF3B82F6), size: 18),
                      label: 'رقم الموبايل',
                      value: client.phone,
                      isPhone: true,
                      color: const Color(0xFF3B82F6),
                      onCopy: () {
                        Clipboard.setData(ClipboardData(text: client.phone));
                        _showFloatingCopyToast(
                            context, 'تم نسخ رقم الموبايل بنجاح');
                      },
                    ),
                    const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  ],

                  _buildDetailRow(
                    context: context,
                    iconWidget: const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF8B5CF6), size: 18),
                    label: 'تاريخ الانضمام',
                    value: _formatDate(client.createdAt),
                    color: const Color(0xFF8B5CF6),
                  ),
                  const Divider(height: 20, color: Color(0xFFE2E8F0)),
                  _buildDetailRow(
                    context: context,
                    iconWidget: Icon(
                        isAdminRole ? Icons.shield_rounded : Icons.check_circle_outline_rounded,
                        color: isAdminRole ? const Color(0xFFD49B1A) : const Color(0xFF10B981),
                        size: 18),
                    label: 'حالة الحساب',
                    value: isAdminRole ? 'مشرف رسمي معتمد' : 'حساب نشط',
                    color: isAdminRole ? const Color(0xFFD49B1A) : const Color(0xFF10B981),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required BuildContext context,
    required Widget iconWidget,
    required String label,
    required String value,
    required Color color,
    bool isPhone = false,
    VoidCallback? onCopy,
  }) {
    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: iconWidget,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isPhone ? PhoneUtils.toLocalDisplay(value) : value,
              textDirection: (isPhone || label.toUpperCase().contains('ID') || label.contains('معرّف'))
                  ? TextDirection.ltr
                  : null,
              style: GoogleFonts.cairo(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (onCopy != null) ...[
          const SizedBox(width: 8),
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.copy_rounded,
                  size: 14, color: Color(0xFF334155)),
            ),
          ),
        ],
      ],
    );
  }



  bool get _hasPhoto =>
      (_client.photoUrl != null && _client.photoUrl!.trim().isNotEmpty && _client.photoUrl != 'default') ||
      (_client.photoBase64 != null && _client.photoBase64!.trim().isNotEmpty && _client.photoBase64 != 'default');

  Widget _buildAvatarContent() {
    return AppImageUtils.buildAvatarImage(
      photoBase64: _client.photoBase64,
      photoUrl: _client.photoUrl,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      fallback: _buildAvatarFallback(),
    );
  }

  Widget _buildAvatarFallback() {
    final name = _client.name.trim();
    if (name.isNotEmpty) {
      return Container(
        color: const Color(0xFFEFF6FF),
        child: Center(
          child: Text(
            name.characters.first,
            style: GoogleFonts.cairo(
              fontSize: 38,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1D4ED8),
            ),
          ),
        ),
      );
    }
    return Container(
      color: const Color(0xFFEFF6FF),
      child: const Center(
        child: Icon(
          Icons.person_rounded,
          color: Color(0xFF1D4ED8),
          size: 52,
        ),
      ),
    );
  }
}
