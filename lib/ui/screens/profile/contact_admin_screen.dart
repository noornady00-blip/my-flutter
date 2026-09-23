import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../../network/notification_service.dart';
import '../../../network/auth_service.dart';
import '../../../core/utils/phone_utils.dart';
import '../../custom_widgets/sudan_phone_field.dart';

class ContactAdminScreen extends StatefulWidget {
  const ContactAdminScreen({super.key});

  @override
  State<ContactAdminScreen> createState() => _ContactAdminScreenState();
}

class _ContactAdminScreenState extends State<ContactAdminScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _isSending = false;
  bool _sentSuccess = false;

  @override
  void initState() {
    super.initState();
    _prefillUserInfo();
  }

  Future<void> _prefillUserInfo() async {
    try {
      final session = await AuthService().getSavedSession();
      if (session['name'] != null && session['name']!.isNotEmpty) {
        if (_nameCtrl.text.isEmpty) {
          _nameCtrl.text = session['name']!;
        }
      }
      if (session['phone'] != null && session['phone']!.isNotEmpty) {
        if (_phoneCtrl.text.isEmpty) {
          _phoneCtrl.text = PhoneUtils.extractLocalSudanDigits(session['phone']!);
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _launchEmail() async {
    const email = 'yourlawyer.ass@gmail.com';
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'استفسار من منصة محاميك',
        'body': 'السلام عليكم ورحمة الله وبركاته،\n\nأود الاستفسار بخصوص:\n',
      },
    );

    try {
      final launched = await launchUrl(
        emailUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        final simpleUri = Uri.parse('mailto:$email');
        final launchedSimple = await launchUrl(
          simpleUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launchedSimple) {
          _copyEmailToClipboard(email);
        }
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      _copyEmailToClipboard(email);
    }
  }

  void _copyEmailToClipboard(String email) {
    Clipboard.setData(ClipboardData(text: email));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم نسخ البريد الإلكتروني ($email) إلى الحافظة لفتحه في تطبيق البريد.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: const Color(0xFF0B2A5B),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'حسناً',
            textColor: const Color(0xFFF59E0B),
            onPressed: () {},
          ),
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    if (!_formKey.currentState!.validate()) return;

    // Anti-spam protection: 1 message per 60 seconds
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSent = prefs.getInt('last_support_msg_time') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsedSeconds = (now - lastSent) ~/ 1000;
      if (elapsedSeconds < 60) {
        final remaining = 60 - elapsedSeconds;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'يرجى الانتظار $remaining ثانية قبل إرسال رسالة أخرى منعاً للرسائل المتكررة',
                style: GoogleFonts.cairo(),
              ),
              backgroundColor: const Color(0xFFF59E0B),
            ),
          );
        }
        return;
      }
    } catch (_) {}

    setState(() {
      _isSending = true;
    });

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      String? photoUrl;
      String? photoBase64;
      String? role;

      if (currentUser != null) {
        try {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
          if (userDoc.exists) {
            final data = userDoc.data() ?? {};
            photoUrl = data['photoUrl']?.toString();
            photoBase64 = data['photoBase64']?.toString();
            role = data['role']?.toString() ?? 'client';
          } else {
            final lawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(currentUser.uid).get();
            if (lawyerDoc.exists) {
              final data = lawyerDoc.data() ?? {};
              photoUrl = data['photoUrl']?.toString();
              photoBase64 = data['photoBase64']?.toString();
              role = 'lawyer';
            }
          }
        } catch (_) {}
      }

      final senderName = _nameCtrl.text.trim();
      final senderPhone = PhoneUtils.normalizeSudanPhone(_phoneCtrl.text.trim());
      final msgBody = _msgCtrl.text.trim();

      await FirebaseFirestore.instance.collection('support_messages').add({
        'name': senderName,
        'phone': senderPhone,
        'message': msgBody,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'unread',
        'senderUid': currentUser?.uid,
        'senderRole': role,
        'photoUrl': photoUrl,
        'photoBase64': photoBase64,
      });

      // إرسال إشعار فوري إلى جهاز الأدمن
      try {
        await NotificationService().dispatchAdminAlert(
          type: 'support_message',
          title: 'رسالة دعم فني جديدة',
          body: 'المرسل: $senderName ($senderPhone)\n$msgBody',
          data: {
            'phone': senderPhone,
            'name': senderName,
          },
        );
      } catch (_) {}

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('last_support_msg_time', DateTime.now().millisecondsSinceEpoch);
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sentSuccess = true;
      });

      _nameCtrl.clear();
      _phoneCtrl.clear();
      _msgCtrl.clear();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _sentSuccess = false; // Never show false success!
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر إرسال الرسالة، يرجى التحقق من اتصالك بالإنترنت والمحاولة مجدداً.',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
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
        centerTitle: false,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo Badge
            const AppLogoBadge(
              height: 30,
              withPillBackground: true,
            ),

            // Back Button
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 40,
                height: 40,
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
                    size: 19,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Notice Banner
              _buildNoticeBanner(),
              const SizedBox(height: 20),

              // Contact Channels Section
              _buildSectionTitle('قنوات الاتصال المباشرة'),
              const SizedBox(height: 12),
              _buildChannelTile(
                icon: Icons.phone_in_talk_rounded,
                title: 'الخط الساخن للإدارة',
                subtitle: '+249 91 220 9596',
                isLtr: true,
                badgeText: 'متاح الآن',
                badgeColor: const Color(0xFF10B981),
                onTap: () => launchUrl(Uri.parse('tel:+249912209596')),
              ),
              const SizedBox(height: 10),
              _buildChannelTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'خدمة العملاء عبر واتساب',
                subtitle: '+249 91 220 9596',
                isLtr: true,
                badgeText: 'متاح الآن',
                badgeColor: const Color(0xFF25D366),
                onTap: () => launchUrl(
                  Uri.parse('https://wa.me/249912209596'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(height: 10),
              _buildChannelTile(
                icon: Icons.email_outlined,
                title: 'إيميل المشرف والتواصل',
                subtitle: 'yourlawyer.ass@gmail.com',
                isLtr: true,
                badgeText: 'متاح الآن',
                badgeColor: const Color(0xFF10B981),
                onTap: _launchEmail,
              ),
              const SizedBox(height: 10),
              _buildChannelTile(
                icon: Icons.location_city_rounded,
                title: 'المقر والإدارة العامة',
                subtitle: 'السودان - الخرطوم',
                isLtr: false,
                badgeText: 'الرئيسي',
                badgeColor: const Color(0xFFF59E0B),
              ),
              const SizedBox(height: 24),

              // Direct Message Form
              _buildMessageForm(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoticeBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFFDE68A),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFFBEB),
              border: Border.all(color: const Color(0xFFF59E0B), width: 1.5),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: Color(0xFFF59E0B),
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'فريق الإدارة في خدمتك دائماً',
            style: GoogleFonts.cairo(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B2A5B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جاري تحديث وتجهيز قنوات الاتصال المباشرة، وسنقوم بتفعيل أرقام الهواتف والواتساب المباشرة قريباً جداً. يمكنك إرسال رسالتك بالأسفل وسيتواصل معك المشرف فوراً.',
            style: GoogleFonts.cairo(
              fontSize: 13,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildSectionTitle(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B2A5B),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 36,
          height: 3,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    bool isLtr = false,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.025),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      textDirection: isLtr ? TextDirection.ltr : null,
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: isLtr ? FontWeight.w700 : FontWeight.w500,
                        color: const Color(0xFF64748B),
                        letterSpacing: isLtr ? 0.3 : 0,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                ),
                child: Text(
                  badgeText,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.send_rounded, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 8),
                Text(
                  'إرسال رسالة مباشرة للمشرف',
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_sentSuccess) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF10B981)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'تم إرسال رسالتك بنجاح! سيتواصل معك فريق الإدارة قريباً.',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 350.ms),
              const SizedBox(height: 16),
            ],

            _buildInput(
              controller: _nameCtrl,
              hint: 'الاسم بالكامل',
              icon: Icons.person_outline_rounded,
              validator: (v) => v == null || v.isEmpty ? 'يرجى كتابة الاسم' : null,
            ),
            const SizedBox(height: 12),
            SudanPhoneFormField(
              controller: _phoneCtrl,
              hintText: '9XXXXXXXX',
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'يرجى كتابة رقم الهاتف';
                if (v.trim().length < PhoneUtils.sudanPhoneLength) {
                  return 'يجب إدخال 9 أرقام (مثال: 912345678)';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),

            _buildInput(
              controller: _msgCtrl,
              hint: 'اكتب استفسارك أو رسالتك للإدارة هنا...',
              icon: Icons.chat_outlined,
              maxLines: 3,
              validator: (v) => v == null || v.isEmpty ? 'يرجى كتابة الرسالة' : null,
            ),
            const SizedBox(height: 18),

            ElevatedButton(
              onPressed: _isSending ? null : _sendMessage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B2A5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: _isSending
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.send_rounded, color: Color(0xFFFBBF24), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'إرسال الرسالة الآن',
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      textDirection: TextDirection.rtl,
      style: GoogleFonts.cairo(color: const Color(0xFF0B2A5B), fontSize: 14),
      validator: validator,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFF59E0B), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.error, width: 1.5),
        ),
      ),
    );
  }
}
