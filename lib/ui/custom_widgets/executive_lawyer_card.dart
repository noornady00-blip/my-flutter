// ==============================================================================
// ⚖️ EXECUTIVE LAWYER CARD COMPONENT
// ==============================================================================
// Premium presentation card for lawyer listings with call and WhatsApp actions.
// ==============================================================================

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:firebase_auth/firebase_auth.dart';

import '../../data/models/lawyer.dart';
import '../../core/utils/phone_utils.dart';
import '../../core/utils/account_id_utils.dart';
import '../screens/chat/chat_screen.dart';
import 'profile_details_modal.dart';

/// Ultra-Premium Executive Lawyer Card Widget.
class ExecutiveLawyerCard extends StatelessWidget {
  final LawyerModel lawyer;
  final int index;
  final VoidCallback? onTap;

  const ExecutiveLawyerCard({
    super.key,
    required this.lawyer,
    this.index = 0,
    this.onTap,
  });

  Future<void> _callPhone(String phone) async {
    final cleanPhone = PhoneUtils.tryNormalize(phone) ?? phone;
    final uri = Uri(scheme: 'tel', path: cleanPhone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openWhatsApp(String phone) async {
    final cleanPhone = PhoneUtils.formatWhatsAppNumber(phone);
    final uri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEDE8DF),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: const Color(0xFFD49B1A).withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top section: Avatar + Info
          InkWell(
            onTap: onTap ??
                () => ProfileDetailsModal.showLawyerModal(context,
                    lawyer: lawyer),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildAvatar(context),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  lawyer.name,
                                  style: GoogleFonts.cairo(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B2A5B),
                                    height: 1.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.verified_rounded,
                                color: Color(0xFFD49B1A),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: Color(0xFFD49B1A),
                                    size: 14,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    lawyer.city.isNotEmpty
                                        ? lawyer.city
                                        : 'السودان',
                                    style: GoogleFonts.cairo(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF0B2A5B),
                                    ),
                                  ),
                                ],
                              ),
                              if (lawyer.accountId.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0B2A5B).withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF0B2A5B).withValues(alpha: 0.12),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.badge_outlined,
                                        size: 11,
                                        color: Color(0xFF0B2A5B),
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        AccountIdUtils.format(lawyer.accountId),
                                        textDirection: TextDirection.ltr,
                                        style: GoogleFonts.cairo(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF0B2A5B),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFE2E8F0), width: 1.0),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'الملف',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 10,
                            color: Color(0xFFD49B1A),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          // Triple Action Buttons (Call, WhatsApp, In-App Chat)
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Row(
                children: [
                  Expanded(
                    child: _buildExecutiveActionButton(
                      label: 'محادثة',
                      iconWidget: const Icon(
                        Icons.chat_bubble_rounded,
                        color: Colors.white,
                        size: 17,
                      ),
                      backgroundColor: const Color(0xFFD49B1A),
                      borderColor: const Color(0xFFB8820B),
                      shadowColor: const Color(0xFFD49B1A),
                      onTap: () {
                        final currentUid = FirebaseAuth.instance.currentUser?.uid;
                        if (currentUid == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'يرجى تسجيل الدخول لبدء محادثة مع المحامي',
                                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                                textDirection: TextDirection.rtl,
                              ),
                              backgroundColor: const Color(0xFF0B2A5B),
                            ),
                          );
                          return;
                        }
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              lawyerUid: lawyer.uid,
                              lawyerName: lawyer.name,
                              lawyerAccountId: lawyer.accountId,
                              lawyerPhone: lawyer.phone,
                              lawyerPhotoUrl: lawyer.photoUrl,
                              lawyerPhotoBase64: lawyer.photoBase64,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildExecutiveActionButton(
                      label: 'اتصال',
                      iconWidget: const Icon(
                        Icons.phone_rounded,
                        color: Color(0xFFD49B1A),
                        size: 17,
                      ),
                      backgroundColor: const Color(0xFF0B2A5B),
                      borderColor: const Color(0xFF1E2E5C),
                      shadowColor: const Color(0xFF0B2A5B),
                      onTap: () => _callPhone(lawyer.phone),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildExecutiveActionButton(
                      label: 'واتساب',
                      iconWidget: const WhatsAppIcon(
                          size: 17, color: Colors.white),
                      backgroundColor: const Color(0xFF16A34A),
                      borderColor: const Color(0xFF15803D),
                      shadowColor: const Color(0xFF16A34A),
                      onTap: () => _openWhatsApp(
                        lawyer.whatsapp.isNotEmpty
                            ? lawyer.whatsapp
                            : lawyer.phone,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    )
        .animate(delay: Duration(milliseconds: 60 * (index % 10)))
        .fadeIn(duration: 350.ms)
        .slideY(begin: 0.05, end: 0);
  }

  Widget _buildAvatar(BuildContext context) {
    final bool hasPhoto = (lawyer.photoBase64 != null &&
            lawyer.photoBase64!.isNotEmpty) ||
        (lawyer.photoUrl != null &&
            lawyer.photoUrl!.isNotEmpty &&
            lawyer.photoUrl != 'default');

    return GestureDetector(
      // Normal tap → open lawyer profile
      onTap: () => ProfileDetailsModal.showLawyerModal(context, lawyer: lawyer),
      // Long press → view full-screen photo
      onLongPress: () {
        if (hasPhoto) {
          ProfileDetailsModal.openPhotoViewer(
            context,
            name: lawyer.name,
            photoBase64: lawyer.photoBase64,
            photoUrl: lawyer.photoUrl,
            subtitle: lawyer.city.trim().isNotEmpty ? lawyer.city : 'محامٍ مُعتمد',
          );
        }
      },
      child: Container(
        width: 58,
        height: 58,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0B2A5B),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2A5B).withValues(alpha: 0.30),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          padding: const EdgeInsets.all(1),
          child: ClipOval(
            child: _buildAvatarImageContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImageContent() {
    if (lawyer.photoUrl != null &&
        lawyer.photoUrl!.isNotEmpty &&
        lawyer.photoUrl != 'default') {
      if (lawyer.photoUrl!.startsWith('http')) {
        return Image.network(
          lawyer.photoUrl!,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildBase64OrFallback(),
        );
      } else if (!kIsWeb && !lawyer.photoUrl!.startsWith('data:')) {
        return Image.file(
          File(lawyer.photoUrl!),
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildBase64OrFallback(),
        );
      }
    }
    return _buildBase64OrFallback();
  }

  Widget _buildBase64OrFallback() {
    final rawBase64 = lawyer.photoBase64?.trim() ?? '';
    final rawUrl = lawyer.photoUrl?.trim() ?? '';

    // Check if either photoBase64 or photoUrl contains base64 image data
    String target = '';
    if (rawBase64.isNotEmpty) {
      target = rawBase64;
    } else if (rawUrl.isNotEmpty &&
        (rawUrl.startsWith('data:image') || !rawUrl.startsWith('http'))) {
      target = rawUrl;
    }

    if (target.isNotEmpty) {
      try {
        final clean = target.contains(',')
            ? target.split(',').last.trim().replaceAll(RegExp(r'\s+'), '')
            : target.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(clean);
        return Image.memory(
          bytes,
          width: 54,
          height: 54,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              _buildExecutiveAvatarFallback(),
        );
      } catch (_) {
        return _buildExecutiveAvatarFallback();
      }
    }
    return _buildExecutiveAvatarFallback();
  }

  Widget _buildExecutiveAvatarFallback() {
    final String trimmed = lawyer.name.trim();
    final String initial =
        trimmed.isNotEmpty ? trimmed.characters.first : 'م';

    return Container(
      width: 54,
      height: 54,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E3A8A),
            Color(0xFF0B2A5B),
            Color(0xFF0A1128),
          ],
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.cairo(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: const Color(0xFFFFD54F),
            height: 1.1,
            shadows: [
              Shadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExecutiveActionButton({
    required String label,
    required Widget iconWidget,
    required Color backgroundColor,
    required Color borderColor,
    required Color shadowColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: shadowColor.withValues(alpha: 0.18),
                blurRadius: 8,
                offset: const Offset(0, 2.5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            textDirection: TextDirection.rtl,
            children: [
              iconWidget,
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
