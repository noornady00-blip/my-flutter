import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../network/auth_service.dart';
import '../../../network/network_service.dart';
import '../main_navigation_screen.dart';
import '../../../core/utils/phone_utils.dart';
import '../../custom_widgets/sudan_phone_field.dart';

class ClientRegisterScreen extends StatefulWidget {
  const ClientRegisterScreen({super.key});

  @override
  State<ClientRegisterScreen> createState() => _ClientRegisterScreenState();
}

class _ClientRegisterScreenState extends State<ClientRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  final _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final hasNet = await NetworkService().hasInternet();
    if (!hasNet) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            textDirection: TextDirection.rtl,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.',
                  style: GoogleFonts.cairo(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() { _loading = true; _error = null; });
    final normalizedPhone = PhoneUtils.normalize(_phoneController.text.trim());
    final res = await _authService.registerClient(
      name: _nameController.text.trim(),
      phone: normalizedPhone,
      password: _passController.text,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['success'] == true) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        (_) => false,
      );
    } else {
      setState(() => _error = res['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B2A5B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B2A5B),
              Color(0xFF103A7A),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          'إنشاء حساب عميل',
                          style: GoogleFonts.cairo(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 42),
                  ],
                ),
              ),
              // Form Sheet
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, -6),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoBanner(),
                          const SizedBox(height: 22),

                          // 1. Full Name
                          _buildFieldHeader('الاسم الثلاثي', Icons.person_outline_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _nameController,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.cairo(
                              fontSize: 14.5,
                              color: const Color(0xFF0B2A5B),
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'أدخل اسمك الثلاثي بالكامل',
                            ),
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty) return 'الاسم مطلوب';
                              if (RegExp(r'[0-9]').hasMatch(val)) {
                                return 'الاسم يجب ألا يحتوي على أرقام';
                              }
                              final parts = val.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
                              if (parts.length < 3) {
                                return 'يرجى إدخال الاسم الثلاثي كاملاً (3 مقاطع على الأقل)';
                              }
                              for (final part in parts) {
                                if (part.length < 2) {
                                  return 'يرجى إدخال اسم حقيقي بدون حروف مفردة وهمية (مثال: محمد أحمد علي)';
                                }
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 2. Phone Number
                          SudanPhoneFormField(
                            controller: _phoneController,
                            labelText: 'رقم الموبايل',
                            headerIcon: Icons.phone_android_rounded,
                            hintText: 'أدخل رقم الموبايل',
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isEmpty) return 'يرجى إدخال رقم الموبايل';
                              if (!PhoneUtils.isValidSudanPhone(val)) {
                                return 'يجب إدخال رقم سوداني صحيح مكون من 9 أرقام ويبدأ بـ 9 (مثال: 912345678)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 3. Password
                          _buildFieldHeader('كلمة المرور', Icons.lock_outline_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passController,
                            obscureText: _obscure,
                            style: GoogleFonts.cairo(
                              fontSize: 14.5,
                              color: const Color(0xFF0B2A5B),
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'أدخل كلمة المرور',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFF64748B),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.length < 6) ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null,
                          ),
                          const SizedBox(height: 18),

                          // 4. Confirm Password
                          _buildFieldHeader('تأكيد كلمة المرور', Icons.lock_outline_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPassController,
                            obscureText: _obscureConfirm,
                            style: GoogleFonts.cairo(
                              fontSize: 14.5,
                              color: const Color(0xFF0B2A5B),
                              fontWeight: FontWeight.w700,
                            ),
                            decoration: _buildInputDecoration(
                              hintText: 'أعد إدخال كلمة المرور',
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  color: const Color(0xFF64748B),
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              ),
                            ),
                            validator: (v) => v != _passController.text ? 'كلمتا المرور غير متطابقتين' : null,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _errorBox(_error!),
                          ],
                          const SizedBox(height: 28),

                          // Luxury Submit Button matching Image 2
                          InkWell(
                            onTap: _loading ? null : _register,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 56,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF0B2A5B), Color(0xFF071C3D)],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF0B2A5B).withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 18),
                              child: _loading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                      ),
                                    )
                                  : Row(
                                      textDirection: TextDirection.rtl,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Spacer(),
                                        Text(
                                          'إنشاء الحساب',
                                          style: GoogleFonts.cairo(
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFD49B1A),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.arrow_forward_rounded,
                                            color: Colors.white,
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Bottom Login Link matching Image 2
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(width: 28, height: 1.2, color: const Color(0xFFE2E8F0)),
                              const SizedBox(width: 10),
                              Text(
                                'لدي حساب بالفعل؟ ',
                                style: GoogleFonts.cairo(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Text(
                                  'تسجيل الدخول',
                                  style: GoogleFonts.cairo(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFFD49B1A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(width: 28, height: 1.2, color: const Color(0xFFE2E8F0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldHeader(String text, IconData icon) {
    return Row(
      textDirection: TextDirection.rtl,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0B2A5B)),
        const SizedBox(width: 7),
        Text(
          text,
          style: GoogleFonts.cairo(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0B2A5B),
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String hintText,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.cairo(
        color: const Color(0xFF94A3B8),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
      ),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      suffixIcon: suffixIcon,
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
        borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.6),
      ),
      errorStyle: GoogleFonts.cairo(
        color: const Color(0xFFDC2626),
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Icon(Icons.flash_on_rounded, color: Color(0xFFD49B1A), size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'حسابك سيكون جاهزاً فوراً بعد التسجيل',
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF92400E),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBox(String msg) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: AppTheme.bodySmall.copyWith(color: AppTheme.error))),
          ],
        ),
      );
}
