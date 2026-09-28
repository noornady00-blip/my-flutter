import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../../network/auth_service.dart';
import '../auth/auth_gateway_screen.dart';
import '../main_navigation_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../admin/admin_dashboard.dart';
import '../auth/lawyer_pending_screen.dart';
import '../../custom_widgets/account_suspended_dialog.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _isStarting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache images safely to ensure zero-lag transition
    try {
      precacheImage(const AssetImage('imag/IMG_4158.PNG'), context).catchError((_) {});
      precacheImage(const AssetImage('assets/images/logo_full.png'), context).catchError((_) {});
      precacheImage(const AssetImage('imag/5818738877521400103.jpg'), context).catchError((_) {});
    } catch (_) {}
  }

  Future<void> _handleStart() async {
    if (_isStarting) return;
    setState(() => _isStarting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      final session = await AuthService().getSavedSession();
      final hasLocalUid = session['uid'] != null && session['uid']!.trim().isNotEmpty;
      final bool isLoggedIn = user != null && hasLocalUid;

      if (user != null && !hasLocalUid) {
        // Stray Firebase Auth user without valid local session -> clean it up!
        try {
          await FirebaseAuth.instance.signOut();
        } catch (_) {}
      }

      final String role = session['role'] ?? 'client';
      final String? status = session['status'];
      final String? name = session['name'];

      Widget targetScreen;
      if (isLoggedIn) {
        // Live verification of account suspension status
        try {
          final col = role == 'lawyer' ? 'lawyers' : 'users';
          final doc = await FirebaseFirestore.instance.collection(col).doc(user.uid).get();
          if (doc.exists && doc.data()?['status'] == 'suspended') {
            await AuthService().signOut();
            if (mounted) {
              setState(() => _isStarting = false);
              await showAccountSuspendedDialog(context);
            }
            return;
          }
        } catch (_) {}

        if (role == 'admin') {
          targetScreen = const AdminDashboard();
        } else if (role == 'lawyer') {
          if (status == 'pending') {
            targetScreen = LawyerPendingScreen(lawyerName: name);
          } else {
            targetScreen = const MainNavigationScreen(role: 'lawyer');
          }
        } else {
          targetScreen = const MainNavigationScreen(role: 'client');
        }
      } else {
        targetScreen = const AuthGatewayScreen();
      }

      if (!mounted) return;

      if (isLoggedIn) {
        await Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 320),
            pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else {
        await Navigator.push(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 320),
            pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      }
    } catch (e) {
      debugPrint('Onboarding _handleStart error: $e');
    } finally {
      if (mounted) {
        setState(() => _isStarting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopSection(),
            _buildHeroImage(),
            _buildBottomCard(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
      child: Column(
        children: [
          Image.asset(
            'assets/images/logo_full.png',
            height: 90,
            fit: BoxFit.contain,
          ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: -0.15, end: 0),
          const SizedBox(height: 12),
          Text(
            'ابحث عن محامي في مدينتك',
            style: GoogleFonts.cairo(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyDark,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 300.ms).fadeIn(duration: 400.ms),
          Text(
            'الخيار الصحيح يبدأ بخطوة واحدة',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: AppTheme.grey,
            ),
            textAlign: TextAlign.center,
          ).animate(delay: 400.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildHeroImage() {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Image.asset(
          'imag/IMG_4158.PNG',
          fit: BoxFit.contain,
        ).animate(delay: 400.ms).scale(duration: 450.ms, curve: Curves.easeOut),
      ),
    );
  }

  Widget _buildBottomCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFDFDFD),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // "اختر مدينتك" Title
          Text(
            'اختر مدينتك',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyDark,
            ),
          ).animate(delay: 500.ms).fadeIn(duration: 400.ms),

          const SizedBox(height: 16),

          // Decorative Search Box (Triggers start without lag)
          GestureDetector(
            onTap: _handleStart,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFEEEEEE), width: 1.5),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.search_rounded, color: AppTheme.gold, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'البحث عن المدينة...',
                    style: GoogleFonts.cairo(color: AppTheme.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          ).animate(delay: 550.ms).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 16),

          // CTA Button: "استكشف المحامين"
          ElevatedButton(
            onPressed: _isStarting ? null : _handleStart,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.navyDark,
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
            child: _isStarting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.arrow_back_rounded, color: AppTheme.gold, size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'استكشف المحامين',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
          ).animate(delay: 600.ms).fadeIn(duration: 400.ms).slideY(begin: 0.15, end: 0),

          const SizedBox(height: 24),

          // Features Row
          _buildFeatureRow().animate(delay: 650.ms).fadeIn(duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildFeatureRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _featureItem(Icons.verified_user_rounded, 'موثوقون', 'محامون معتمدون'),
        _featureItem(Icons.star_rounded, 'تقييمات حقيقية', 'من عملاء سابقين'),
        _featureItem(Icons.lock_rounded, 'آمن وسريع', 'خصوصيتك تهمنا'),
      ],
    );
  }

  Widget _featureItem(IconData icon, String title, String sub) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: AppTheme.gold, size: 24),
          const SizedBox(height: 6),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.navyDark,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            sub,
            style: GoogleFonts.cairo(
              fontSize: 9,
              color: AppTheme.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
