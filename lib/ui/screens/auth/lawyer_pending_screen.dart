import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../main_navigation_screen.dart';
import '../../../core/utils/navigation_utils.dart';
import 'lawyer_register_screen.dart';

class LawyerPendingScreen extends StatefulWidget {
  final String? lawyerName;
  const LawyerPendingScreen({super.key, this.lawyerName});

  @override
  State<LawyerPendingScreen> createState() => _LawyerPendingScreenState();
}

class _LawyerPendingScreenState extends State<LawyerPendingScreen> {
  bool _isChecking = false;
  String _currentStatus = 'pending';
  String? _rejectionReason;
  StreamSubscription<DocumentSnapshot>? _statusSubscription;

  @override
  void initState() {
    super.initState();
    _startRealtimeStatusListener();
  }

  @override
  void dispose() {
    _statusSubscription?.cancel();
    super.dispose();
  }

  void _startRealtimeStatusListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _statusSubscription = FirebaseFirestore.instance
        .collection('lawyers')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
      if (!mounted) return;
      if (doc.exists && doc.data() != null) {
        final st = doc.data()?['status']?.toString() ?? 'pending';
        final reason = doc.data()?['rejectionReason']?.toString();
        setState(() {
          _currentStatus = st;
          _rejectionReason = reason;
        });

        if (st == 'approved') {
          _statusSubscription?.cancel();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'مبروك! تم اعتماد حسابك بنجاح من قبل الإدارة.',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
              ),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen(role: 'lawyer')),
            (_) => false,
          );
        }
      }
    }, onError: (e) {
      debugPrint('[LawyerPendingScreen] status listener error: $e');
    });
  }

  Future<void> _checkApprovalStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _logout();
      return;
    }

    setState(() => _isChecking = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('lawyers').doc(user.uid).get();
      final status = doc.data()?['status']?.toString() ?? 'pending';
      final reason = doc.data()?['rejectionReason']?.toString();

      if (!mounted) return;
      setState(() {
        _isChecking = false;
        _currentStatus = status;
        _rejectionReason = reason;
      });

      if (status == 'approved') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('مبروك! تم اعتماد حسابك بنجاح من قبل الإدارة.', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen(role: 'lawyer')),
          (_) => false,
        );
      } else if (status == 'rejected') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'نأسف، تم رفض طلب الانضمام. يمكنك إنشاء حساب جديد وتصحيح البيانات.',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('طلبك لا يزال قيد المراجعة والتدقيق بواسطة فريق الإدارة.', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFF59E0B),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isChecking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر فحص الحالة، يرجى التأكد من اتصال الإنترنت', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  void _navigateToReRegister() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LawyerRegisterScreen()),
      (_) => false,
    );
  }

  Future<void> _contactSupportViaWhatsapp() async {
    final text = _currentStatus == 'rejected'
        ? "مرحباً إدارة محاميك، أود الاستفسار عن سبب رفض طلب انضمامي كمحامي وإمكانية التقديم مجدداً."
        : "مرحباً إدارة محاميك، أود الاستفسار عن حالة طلب انضمامي كمحامي.";
    final uri = Uri.parse('https://wa.me/249912209596?text=${Uri.encodeComponent(text)}');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح تطبيق واتساب مباشرة', style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.navyDark,
          ),
        );
      }
    }
  }

  void _logout() {
    NavigationUtils.smoothSignOut(context);
  }

  @override
  Widget build(BuildContext context) {
    final isRejected = _currentStatus == 'rejected';

    return Scaffold(
      backgroundColor: const Color(0xFF0B2A5B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            children: [
              // Logo Top
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  AppLogoBadge(height: 38, withPillBackground: false),
                ],
              ),
              const Spacer(),

              // Status Card (Pending or Rejected)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Icon
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: isRejected ? const Color(0xFFFFF1F2) : const Color(0xFFFFFBEB),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isRejected ? const Color(0xFFE11D48) : const Color(0xFFF59E0B),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        isRejected ? Icons.cancel_outlined : Icons.hourglass_top_rounded,
                        color: isRejected ? const Color(0xFFE11D48) : const Color(0xFFF59E0B),
                        size: 38,
                      ),
                    ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 18),

                    // Title
                    Text(
                      isRejected ? 'تم رفض طلب الانضمام' : 'طلبك قيد المراجعة والتدقيق',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: isRejected ? const Color(0xFF991B1B) : const Color(0xFF0B2A5B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),

                    // Subtitle / Details
                    Text(
                      isRejected
                          ? (_rejectionReason ??
                              'نأسف، تم رفض طلب انضمامك إلى منصة محاميك من قبل فريق الإدارة. يمكنك مراجعة وتصحيح بياناتك والمحاولة مرة أخرى بإنشاء حساب جديد.')
                          : 'مرحباً بك زميلنا المحامي. نقوم بمراجعة بيانات القيد وتراخيص المزاولة لضمان أعلى معايير الجودة والموثوقية لعملائنا في منصة محاميك.',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        color: isRejected ? const Color(0xFF7F1D1D) : const Color(0xFF64748B),
                        height: 1.55,
                        fontWeight: isRejected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isRejected ? const Color(0xFFFEE2E2) : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isRejected ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
                        ),
                      ),
                      child: Text(
                        isRejected ? 'الحالة: تم الرفض (Rejected)' : 'الحالة: قيد الانتظار (Pending)',
                        style: GoogleFonts.cairo(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isRejected ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (isRejected) ...[
                      // Re-register button (Primary)
                      ElevatedButton.icon(
                        onPressed: _navigateToReRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD49B1A),
                          foregroundColor: const Color(0xFF0B2A5B),
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 2,
                        ),
                        icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                        label: Text(
                          'إنشاء حساب جديد والمحاولة مجدداً',
                          style: GoogleFonts.cairo(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ] else ...[
                      // Refresh Button
                      ElevatedButton(
                        onPressed: _isChecking ? null : _checkApprovalStatus,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2A5B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 50),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isChecking
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.refresh_rounded, color: AppTheme.gold, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'فحص وتحديث الحالة الآن',
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: 10),
                    ],

                    // Contact Admin via WhatsApp
                    OutlinedButton(
                      onPressed: _contactSupportViaWhatsapp,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: Color(0xFF25D366), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366), size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'مراسلة الإدارة عبر واتساب',
                            style: GoogleFonts.cairo(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF15803D),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 450.ms).slideY(begin: 0.08, end: 0),

              const Spacer(),

              // Sign Out link
              TextButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 18),
                label: Text(
                  'تسجيل الخروج والعودة للرئيسية',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
