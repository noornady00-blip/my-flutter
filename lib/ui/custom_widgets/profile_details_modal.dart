// ==============================================================================
// 📋 PROFILE DETAILS MODAL COMPONENT (LAWYER & CLIENT)
// ==============================================================================
// Displays interactive bottom sheet modal with lawyer/client credentials,
// high-resolution lightbox photo viewer, WhatsApp direct action, and call triggers.
// ==============================================================================

import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../data/models/lawyer.dart';
import '../../data/models/user_model.dart';
import '../../core/utils/phone_utils.dart';

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
    final cleanPhone = PhoneUtils.normalizeSudanPhone(phone, withPlus: true);
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
          ),
        ),
      ),
    );
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

  const _LawyerModalSheet({
    required this.lawyer,
    required this.isAdmin,
    this.onApprove,
    this.onReject,
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
    if (_lawyer.city.isEmpty || _lawyer.specialization.isEmpty) {
      _loadFullLawyerData();
    }
  }

  Future<void> _loadFullLawyerData() async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      if (_lawyer.uid.isNotEmpty && !_lawyer.uid.startsWith('guest_')) {
        doc = await FirebaseFirestore.instance
            .collection('lawyers')
            .doc(_lawyer.uid)
            .get();
      }
      if ((doc == null || !doc.exists) && _lawyer.phone.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('lawyers')
            .where('phone', isEqualTo: _lawyer.phone.trim())
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) doc = snap.docs.first;
      }
      if (doc != null && doc.exists && doc.data() != null && mounted) {
        setState(() {
          _lawyer = LawyerModel.fromMap(doc!.data()!, doc.id);
        });
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
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
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

            // Avatar & Lightbox Trigger
            Center(
              child: Tooltip(
                message: 'اضغط لعرض الصورة بحجم كامل',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => ProfileDetailsModal.openPhotoViewer(
                    context,
                    name: lawyer.name,
                    photoBase64: lawyer.photoBase64,
                    photoUrl: lawyer.photoUrl,
                    subtitle: '${lawyer.specialization} - ${lawyer.city}',
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 104,
                        height: 104,
                        padding: const EdgeInsets.all(3.5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0B2A5B),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0B2A5B)
                                  .withValues(alpha: 0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
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
                      Positioned(
                        top: 2,
                        left: 2,
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B2A5B)
                                .withValues(alpha: 0.85),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.fullscreen_rounded,
                            color: Color(0xFFFFD54F),
                            size: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Tap hint
            Center(
              child: InkWell(
                onTap: () => ProfileDetailsModal.openPhotoViewer(
                  context,
                  name: lawyer.name,
                  photoBase64: lawyer.photoBase64,
                  photoUrl: lawyer.photoUrl,
                  subtitle: '${lawyer.specialization} - ${lawyer.city}',
                ),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.zoom_in_rounded,
                          size: 14, color: Color(0xFF94A3B8)),
                      const SizedBox(width: 4),
                      Text(
                        'اضغط على الصورة للتكبير',
                        style: GoogleFonts.cairo(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ],
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

            // Specialization & Location Badges
            if (lawyer.specialization.trim().isNotEmpty ||
                lawyer.city.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (lawyer.specialization.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B)
                                  .withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.work_rounded,
                                size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                lawyer.specialization.trim(),
                                style: GoogleFonts.cairo(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (lawyer.city.trim().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 14, color: Color(0xFFD49B1A)),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                lawyer.city.trim(),
                                style: GoogleFonts.cairo(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0B2A5B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Iconic Action Buttons
            _buildIconic3DActionButtons(
                context, lawyer.phone, lawyer.whatsapp),
            const SizedBox(height: 22),

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
                      Icons.verified_user_rounded,
                      color: isApproved
                          ? const Color(0xFF10B981)
                          : (isPending
                              ? const Color(0xFFF59E0B)
                              : const Color(0xFFEF4444)),
                      size: 18,
                    ),
                    label: 'حالة الحساب',
                    value: isApproved
                        ? 'حساب موثق ومفعل'
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
    if (lawyer.photoUrl != null && lawyer.photoUrl!.isNotEmpty) {
      return Image.network(
        lawyer.photoUrl!,
        width: 96,
        height: 96,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _buildBase64OrFallback(lawyer),
      );
    }
    return _buildBase64OrFallback(lawyer);
  }

  Widget _buildBase64OrFallback(LawyerModel lawyer) {
    if (lawyer.photoBase64 != null && lawyer.photoBase64!.isNotEmpty) {
      try {
        final b64 = lawyer.photoBase64!.contains(',')
            ? lawyer.photoBase64!.split(',').last.trim()
            : lawyer.photoBase64!.trim();
        return Image.memory(
          base64Decode(b64),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildAvatarFallback(lawyer),
        );
      } catch (_) {
        return _buildAvatarFallback(lawyer);
      }
    }
    return _buildAvatarFallback(lawyer);
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
      BuildContext context, String phone, String whatsapp) {
    final targetWhatsapp = whatsapp.isNotEmpty ? whatsapp : phone;

    return Row(
      textDirection: TextDirection.rtl,
      children: [
        Expanded(
          child: _ExecutiveModalActionButton(
            title: 'اتصال مباشر',
            iconWidget: const Icon(Icons.phone_rounded,
                color: Color(0xFFD49B1A), size: 19),
            backgroundColor: const Color(0xFF0B2A5B),
            borderColor: const Color(0xFF1E2E5C),
            shadowColor: const Color(0xFF0B2A5B),
            onTap: () => ProfileDetailsModal.launchCall(phone),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ExecutiveModalActionButton(
            title: 'واتساب',
            iconWidget: const WhatsAppIcon(size: 19, color: Colors.white),
            backgroundColor: const Color(0xFF1E8E5A),
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
        const Spacer(),
        Text(
          isPhone ? PhoneUtils.formatForDisplay(value) : value,
          textDirection: isPhone ? TextDirection.ltr : null,
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B2A5B),
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
        height: 48,
        decoration: BoxDecoration(
          color: widget.backgroundColor,
          borderRadius: BorderRadius.circular(12),
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
            const SizedBox(width: 8),
            Text(
              widget.title,
              style: GoogleFonts.cairo(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.2,
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
    Widget imageWidget;
    if (photoUrl != null && photoUrl!.trim().isNotEmpty) {
      final url = photoUrl!.trim();
      if (url.startsWith('data:image')) {
        try {
          final b64 = url.split(',').last.trim();
          imageWidget = Image.memory(
            base64Decode(b64),
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
                _buildBase64OrPlaceholder(),
          );
        } catch (_) {
          imageWidget = _buildBase64OrPlaceholder();
        }
      } else if (url.startsWith('http')) {
        imageWidget = Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildBase64OrPlaceholder(),
        );
      } else {
        try {
          final f = File(url);
          if (f.existsSync()) {
            imageWidget = Image.file(
              f,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) =>
                  _buildBase64OrPlaceholder(),
            );
          } else {
            imageWidget = _buildBase64OrPlaceholder();
          }
        } catch (_) {
          imageWidget = _buildBase64OrPlaceholder();
        }
      }
    } else {
      imageWidget = _buildBase64OrPlaceholder();
    }

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
    if (photoBase64 != null && photoBase64!.trim().isNotEmpty) {
      try {
        final b64 = photoBase64!.contains(',')
            ? photoBase64!.split(',').last.trim()
            : photoBase64!.trim();
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholder(),
        );
      } catch (_) {
        return _buildPlaceholder();
      }
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
class _ClientModalSheet extends StatelessWidget {
  final UserModel client;
  final bool isAdmin;
  final VoidCallback? onDelete;

  const _ClientModalSheet({
    required this.client,
    required this.isAdmin,
    this.onDelete,
  });

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
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
                            subtitle: 'عميل مسجل في المنصة',
                          )
                      : null,
                  child: Container(
                    width: 100,
                    height: 100,
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF0B2A5B),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B2A5B)
                              .withValues(alpha: 0.25),
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
            if (_hasPhoto) ...[
              const SizedBox(height: 6),
              Center(
                child: InkWell(
                  onTap: () => ProfileDetailsModal.openPhotoViewer(
                    context,
                    name: client.name,
                    photoBase64: client.photoBase64,
                    photoUrl: client.photoUrl,
                    subtitle: 'عميل مسجل في المنصة',
                  ),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.zoom_in_rounded,
                            size: 14, color: Color(0xFF94A3B8)),
                        const SizedBox(width: 4),
                        Text(
                          'اضغط على الصورة للتكبير',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBFDBFE)),
                ),
                child: Text(
                  'عميل مسجل في المنصة',
                  style: GoogleFonts.cairo(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              textDirection: TextDirection.rtl,
              children: [
                Expanded(
                  child: _ExecutiveModalActionButton(
                    title: 'اتصال هاتفي',
                    iconWidget: const Icon(Icons.phone_rounded,
                        color: Color(0xFFD49B1A), size: 19),
                    backgroundColor: const Color(0xFF0B2A5B),
                    borderColor: const Color(0xFF1E2E5C),
                    shadowColor: const Color(0xFF0B2A5B),
                    onTap: () => ProfileDetailsModal.launchCall(client.phone),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ExecutiveModalActionButton(
                    title: 'واتساب',
                    iconWidget:
                        const WhatsAppIcon(size: 19, color: Colors.white),
                    backgroundColor: const Color(0xFF1E8E5A),
                    borderColor: const Color(0xFF15803D),
                    shadowColor: const Color(0xFF16A34A),
                    onTap: () =>
                        ProfileDetailsModal.launchWhatsApp(client.phone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
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
                    iconWidget: const Icon(
                        Icons.check_circle_outline_rounded,
                        color: Color(0xFF10B981),
                        size: 18),
                    label: 'حالة الحساب',
                    value: 'حساب نشط',
                    color: const Color(0xFF10B981),
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
        const Spacer(),
        Text(
          isPhone ? PhoneUtils.formatForDisplay(value) : value,
          textDirection: isPhone ? TextDirection.ltr : null,
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B2A5B),
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
      (client.photoUrl != null && client.photoUrl!.trim().isNotEmpty) ||
      (client.photoBase64 != null && client.photoBase64!.trim().isNotEmpty);

  Widget _buildAvatarContent() {
    if (client.photoUrl != null && client.photoUrl!.trim().isNotEmpty) {
      final url = client.photoUrl!.trim();
      if (url.startsWith('data:image')) {
        try {
          final b64 = url.split(',').last.trim();
          return Image.memory(
            base64Decode(b64),
            width: 96,
            height: 96,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) =>
                _buildBase64OrFallback(),
          );
        } catch (_) {
          return _buildBase64OrFallback();
        }
      } else if (url.startsWith('http')) {
        return Image.network(
          url,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildBase64OrFallback(),
        );
      } else {
        try {
          final file = File(url);
          if (file.existsSync()) {
            return Image.file(
              file,
              width: 96,
              height: 96,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (context, error, stackTrace) =>
                  _buildBase64OrFallback(),
            );
          }
        } catch (_) {}
      }
    }
    return _buildBase64OrFallback();
  }

  Widget _buildBase64OrFallback() {
    if (client.photoBase64 != null && client.photoBase64!.trim().isNotEmpty) {
      try {
        final b64 = client.photoBase64!.contains(',')
            ? client.photoBase64!.split(',').last.trim()
            : client.photoBase64!.trim();
        return Image.memory(
          base64Decode(b64),
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildAvatarFallback(),
        );
      } catch (_) {
        return _buildAvatarFallback();
      }
    }
    return _buildAvatarFallback();
  }

  Widget _buildAvatarFallback() {
    final name = client.name.trim();
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
