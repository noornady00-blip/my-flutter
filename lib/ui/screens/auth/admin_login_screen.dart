import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../network/auth_service.dart';
import '../../../network/network_service.dart';
import '../../custom_widgets/sudan_phone_field.dart';
import '../admin/admin_dashboard.dart';

/// 🏛️ شاشة بوابة المشرفين والإدارة (Admin Portal)
/// مسار مخصص ومنفصل (/admin-portal) محمي بحارس الدور، لا يظهر في الواجهة العامة.
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _enforceAdminPortalIsolation();
  }

  /// حماية فورية: إذا كان المستخدم مسجلاً بدور غير إداري، يتم إنهاء الجلسة فوراً
  Future<void> _enforceAdminPortalIsolation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role');
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && role != null && role != 'admin' && role != 'subadmin') {
        await _authService.signOut();
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    if (NetworkService().currentStatus == NetworkStatus.noConnection) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'لا يوجد اتصال بالإنترنت. يرجى تفعيل الواي فاي أو البيانات والمحاولة مجدداً.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final res = await _authService.signInWithRole(
      phone: _phoneController.text.trim(),
      password: _passController.text,
      expectedPortal: 'admin',
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboard()),
        (_) => false,
      );
    } else {
      setState(() => _error = res['error']?.toString() ?? 'فشل تسجيل الدخول كمسؤول.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF071228),
      body: Column(
        children: [
          // Top Header (Shield & Admin Identity)
          SizedBox(
            height: 280,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Background dark gradient
                Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0B2A5B),
                        Color(0xFF071228),
                      ],
                    ),
                  ),
                ),

                // Back Button (Returns to public screen)
                Positioned(
                  top: 10,
                  right: 16,
                  child: SafeArea(
                    bottom: false,
                    child: GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(context, '/');
                        }
                      },
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.22),
                            width: 1.2,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),

                // Header Content
                SafeArea(
                  bottom: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Golden Shield Icon
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD49B1A).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFD49B1A),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFD49B1A).withValues(alpha: 0.25),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.admin_panel_settings_rounded,
                              color: Color(0xFFD49B1A),
                              size: 36,
                            ),
                          ).animate().scale(
                                begin: const Offset(0.85, 0.85),
                                end: const Offset(1.0, 1.0),
                                duration: 400.ms,
                                curve: Curves.easeOutBack,
                              ),

                          const SizedBox(height: 14),

                          Text(
                            'بوابة الإدارة والرقابة',
                            style: GoogleFonts.cairo(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'منطقة مخصصة للمشرفين وإدارة منصة محاميك فقط',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              color: const Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom White Form Card
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badge info
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        margin: const EdgeInsets.only(bottom: 22),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.security_rounded, color: Color(0xFFD49B1A), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'تسجيل الدخول هنا يمنح صلاحيات إدارية فقط للحسابات المعتمدة.',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF92400E),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Phone Field
                      SudanPhoneFormField(
                        controller: _phoneController,
                        labelText: 'رقم موبايل المشرف',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال رقم موبايل المشرف';
                          }
                          try {
                            PhoneUtils.normalize(v.trim());
                            return null;
                          } catch (e) {
                            return 'صيغة رقم الهاتف غير صالحة';
                          }
                        },
                      ),

                      const SizedBox(height: 18),

                      // Password Field
                      Text(
                        'كلمة المرور الإدارية',
                        style: GoogleFonts.cairo(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B2A5B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passController,
                        obscureText: _obscure,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _loginAdmin(),
                        decoration: InputDecoration(
                          hintText: '••••••••',
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 20),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF64748B),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0B2A5B), width: 1.8)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'يرجى إدخال كلمة المرور';
                          if (v.trim().length < 6) return 'كلمة المرور يجب ألا تقل عن 6 أحرف';
                          return null;
                        },
                      ),

                      // Error Banner
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFFECDD3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: Color(0xFFE11D48), size: 19),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: GoogleFonts.cairo(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFBE123C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _loading ? null : _loginAdmin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B2A5B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 2,
                          ),
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.verified_user_rounded, color: Color(0xFFD49B1A), size: 20),
                                    const SizedBox(width: 8),
                                    Text(
                                      'دخول المشرف',
                                      style: GoogleFonts.cairo(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
