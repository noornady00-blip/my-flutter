import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import 'login_screen.dart';
import 'client_register_screen.dart';
import 'lawyer_register_screen.dart';
import '../cities/cities_screen.dart';

/// Auth Gateway Screen — the entry point after Onboarding.
class AuthGatewayScreen extends StatelessWidget {
  const AuthGatewayScreen({super.key});

  void _showRegisterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _RegisterOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B2A5B),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: const Color(0xFF0B2A5B),
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 1. Glass Back Button
                  GestureDetector(
                    onTap: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const CitiesScreen()),
                        );
                      }
                    },
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.28),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.20),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),

                  // 2. Oval Glass Badge with Mahameek Logo
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo_full.png',
                      height: 34,
                      fit: BoxFit.contain,
                    ),
                  ),

                  // 3. Balance Spacer
                  const SizedBox(width: 42),
                ],
              ),
            ),
          ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'imag/5818738877521400103.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.0, -0.15),
                  errorBuilder: (context, error, stack) => Image.asset(
                    'assets/images/suit_bg.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, -0.15),
                  ),
                ),
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: [0.0, 0.45, 0.78, 1.0],
                      colors: [
                        Color(0x330B2A5B),
                        Color(0x880B2A5B),
                        Color(0xEE071C3D),
                        Color(0xFF071C3D),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            Container(height: 2, color: AppTheme.gold, margin: const EdgeInsets.only(bottom: 16)),
                            Text(
                              'اعثر على\nمحاميك\nفي دقائق',
                              style: GoogleFonts.cairo(fontSize: 48, fontWeight: FontWeight.w800, color: AppTheme.gold, height: 1.1),
                              textAlign: TextAlign.center,
                            ).animate(delay: 200.ms).fadeIn(duration: 600.ms).slideY(begin: 0.1, end: 0),
                            Container(height: 2, color: AppTheme.gold, margin: const EdgeInsets.only(top: 16, bottom: 12)),
                          ],
                        ),
                      ),
                      Text(
                        'محاميك منصة تربطك بمحامين موثوقين بسرعة وسهولة',
                        style: GoogleFonts.cairo(fontSize: 12.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.90)),
                        textAlign: TextAlign.center,
                      ).animate(delay: 300.ms).fadeIn(duration: 600.ms),
                      const SizedBox(height: 46),
                      _PrimaryButton(
                        label: 'تسجيل الدخول',
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
                      ).animate(delay: 400.ms).fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 14),
                      _SecondaryButton(
                        label: 'إنشاء حساب',
                        onTap: () => _showRegisterOptions(context),
                      ).animate(delay: 500.ms).fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Register Options Bottom Sheet matching Image 3 ────────────────────────────
class _RegisterOptionsSheet extends StatefulWidget {
  const _RegisterOptionsSheet();

  @override
  State<_RegisterOptionsSheet> createState() => _RegisterOptionsSheetState();
}

class _RegisterOptionsSheetState extends State<_RegisterOptionsSheet> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 32, offset: Offset(0, -8))],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 46, height: 4.5,
              decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'كيف تريد الانضمام؟',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0B2A5B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'اختر نوع حسابك لبدء رحلتك معنا',
            style: GoogleFonts.cairo(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),

          // 1. Client Card (أبحث عن محامي)
          _SelectionCard(
            title: 'أبحث عن محامي',
            subtitle: 'عميل',
            icon: Icons.person_search_rounded,
            iconColor: const Color(0xFFD49B1A),
            iconBgColor: const Color(0xFFFFF6E0),
            borderColor: const Color(0xFFFDE68A),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientRegisterScreen()));
            },
          ).animate(delay: 100.ms).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 14),

          // 2. Lawyer Card (أنا محامي)
          _SelectionCard(
            title: 'أنا محامي',
            subtitle: 'محامي',
            icon: Icons.gavel_rounded,
            iconColor: const Color(0xFF0B2A5B),
            iconBgColor: const Color(0xFFEEF4FF),
            borderColor: const Color(0xFFE2E8F0),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LawyerRegisterScreen()));
            },
          ).animate(delay: 200.ms).fadeIn(duration: 300.ms).slideY(begin: 0.08, end: 0),

          const SizedBox(height: 24),

          // 3. Bottom Button: لدي حساب بالفعل؟ تسجيل الدخول
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RichText(
                    text: TextSpan(children: [
                      TextSpan(
                        text: 'لدي حساب بالفعل؟ ',
                        style: GoogleFonts.cairo(
                          color: const Color(0xFFD49B1A),
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      TextSpan(
                        text: 'تسجيل الدخول',
                        style: GoogleFonts.cairo(
                          color: const Color(0xFF64748B),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.login_rounded,
                    size: 18,
                    color: Color(0xFFD49B1A),
                  ),
                ],
              ),
            ),
          ).animate(delay: 300.ms).fadeIn(duration: 300.ms),
        ],
      ),
    );
  }
}

// ── Clean Selection Card matching Image 3 ─────────────────────────────────
class _SelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _SelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Right: Circular Avatar Icon
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(width: 16),

            // Middle: Title & Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),

            // Left: Arrow
            const Icon(
              Icons.chevron_left_rounded,
              color: Color(0xFF94A3B8),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Button Widgets ───────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppTheme.gold.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800, color: const Color(0xFF0B2A5B))),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: AppTheme.gold.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.gold, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(label, style: GoogleFonts.cairo(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.gold)),
      ),
    );
  }
}
