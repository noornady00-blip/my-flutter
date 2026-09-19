// ==============================================================================
// 🚫 ACCOUNT SUSPENDED DIALOG COMPONENT
// ==============================================================================
// Displays an alert modal when suspended accounts attempt access.
// ==============================================================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_constants.dart';

/// Shows an alert dialog notifying user that account has been suspended.
Future<void> showAccountSuspendedDialog(
  BuildContext context, {
  String? customMessage,
  VoidCallback? onDismiss,
}) async {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return PopScope(
        canPop: false,
        child: Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 12,
          backgroundColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Warning Shield Icon
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFFDA4AF), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color:
                            const Color(0xFFE11D48).withValues(alpha: 0.15),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.block_rounded,
                      color: Color(0xFFE11D48),
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // 2. Title
                Text(
                  'الحساب موقوف حالياً',
                  style: GoogleFonts.cairo(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B2A5B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // 3. Explanation Message
                Text(
                  customMessage ??
                      'نحيطكم علماً بأنه قد تم إيقاف هذا الحساب من قبل إدارة المنصة. يرجى التواصل مع إدارة تطبيق محاميك للاستفسار أو طلب إعادة التنشيط.',
                  style: GoogleFonts.cairo(
                    fontSize: 13.5,
                    height: 1.55,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF475569),
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 22),

                // 4. Contact via WhatsApp Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      const adminPhone = AppConstants.secondaryAdminPhoneClean;
                      final text = Uri.encodeComponent(
                        'مرحباً إدارة تطبيق محاميك، أود الاستفسار بخصوص إيقاف حسابي وطلب إعادة تنشيطه.',
                      );
                      final url =
                          Uri.parse('https://wa.me/$adminPhone?text=$text');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url,
                            mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.chat_bubble_outline_rounded,
                        color: Colors.white, size: 20),
                    label: Text(
                      'تواصل مع الإدارة عبر واتساب',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // 5. Dismiss / OK Button
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onDismiss?.call();
                    },
                    child: Text(
                      'حسناً، فهمت',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
