import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../network/auth_service.dart';
import '../../../network/network_service.dart';
import '../main_navigation_screen.dart';
import 'lawyer_pending_screen.dart';
import 'lawyer_register_screen.dart';
import '../../custom_widgets/account_suspended_dialog.dart';
import '../../custom_widgets/sudan_phone_field.dart';
import '../../../core/utils/phone_utils.dart';
import '../../custom_widgets/app_dialog.dart';


class LoginScreen extends StatefulWidget {
  final String? role;
  const LoginScreen({super.key, this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passController = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;
  late String _selectedRole;
  final _authService = AuthService();
  Timer? _logoLongPressTimer;

  @override
  void initState() {
    super.initState();
    // Public login screen strictly supports 'client' and 'lawyer'
    _selectedRole = (widget.role == 'lawyer') ? 'lawyer' : 'client';
  }

  void _onLogoPointerDown(PointerDownEvent _) {
    _logoLongPressTimer?.cancel();
    _logoLongPressTimer = Timer(const Duration(seconds: 3), () {
      HapticFeedback.heavyImpact();
      if (mounted) {
        Navigator.pushNamed(context, '/admin-portal');
      }
    });
  }

  void _onLogoPointerUpOrCancel(PointerEvent _) {
    _logoLongPressTimer?.cancel();
    _logoLongPressTimer = null;
  }

  @override
  void dispose() {
    _logoLongPressTimer?.cancel();
    _identifierController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Widget _buildRoleTab({
    required String roleKey,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == roleKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (_selectedRole != roleKey) {
            setState(() {
              _selectedRole = roleKey;
              _error = null;
            });
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0B2A5B) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFF64748B),
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Instant internet status check
    final currentStatus = NetworkService().currentStatus;
    if (currentStatus == NetworkStatus.noConnection) {
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
      phone: _identifierController.text.trim(),
      password: _passController.text,
      expectedPortal: _selectedRole, // 'client' or 'lawyer'
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (res['success'] == true) {
      if (res['role'] == 'lawyer') {
        if (res['status'] == 'pending') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => LawyerPendingScreen(lawyerName: res['name'] as String?),
            ),
            (_) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen(role: 'lawyer')),
            (_) => false,
          );
        }
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen(role: 'client')),
          (_) => false,
        );
      }
    } else {
      final isRejected = res['isRejected'] == true ||
          (res['error']?.toString().contains('رفض') ?? false);
      if (isRejected) {
        _showAccountRejectedDialog(
          res['error']?.toString() ??
              'تم رفض طلب انضمامك إلى منصة محاميك. يمكنك مراجعة وتعديل بياناتك والمحاولة مرة أخرى بإنشاء حساب جديد.',
        );
        setState(() => _error = res['error']);
        return;
      }

      final isSuspended = res['isSuspended'] == true ||
          (res['error']?.toString().contains('إيقاف') ?? false);
      if (isSuspended) {
        showAccountSuspendedDialog(
          context,
          customMessage: res['error'],
        );
        setState(() => _error = res['error']);
        return;
      }

      // For network errors, show status-aware message; global banner handles the visual
      final isNetErr = res['isNetworkError'] == true ||
          (res['error']?.toString().contains('إنترنت') ?? false) ||
          (res['error']?.toString().contains('الشبكة') ?? false);
      if (isNetErr) {
        final currentStatus = NetworkService().currentStatus;
        final errMsg = currentStatus == NetworkStatus.noConnection
            ? 'لا يوجد اتصال بالإنترنت. يرجى تفعيل الواي فاي أو البيانات والمحاولة مجدداً.'
            : 'الشبكة الحالية لا توفر وصولاً للإنترنت. يرجى التحقق من الاتصال والمحاولة مجدداً.';
        setState(() => _error = errMsg);
      } else {
        setState(() => _error = res['error']);
      }
    }
  }

  void _showAccountRejectedDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE11D48), width: 2),
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  color: Color(0xFFE11D48),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'تم رفض طلب الانضمام',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF991B1B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: const Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LawyerRegisterScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD49B1A),
                  foregroundColor: const Color(0xFF0B2A5B),
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                label: Text(
                  'إنشاء حساب جديد والمحاولة مجدداً',
                  style: GoogleFonts.cairo(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetCtrl = TextEditingController(text: _identifierController.text.trim());
    bool isSubmitting = false;
    String? modalError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title & Icon
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEB),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD49B1A), width: 1.5),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFD49B1A), size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'استعادة كلمة المرور',
                            style: GoogleFonts.cairo(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          Text(
                            'الدعم الفني المباشر واستعادة الحساب',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Guidance Notice Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'يرجى إدخال رقم هاتفك المسجل لإرسال طلب استعادة كلمة المرور إلى إدارة التطبيق، وسيتم مراجعة الطلب وتعيين كلمة المرور وإشعارك.',
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            height: 1.5,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Phone Number Input
                SudanPhoneFormField(
                  controller: resetCtrl,
                  isRequired: true,
                ),

                // In-Modal Error Card
                if (modalError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            modalError!,
                            textDirection: TextDirection.rtl,
                            style: GoogleFonts.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF991B1B),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 20),

                // In-App Request to Administration Button
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          setModalState(() => modalError = null);
                          final phone = resetCtrl.text.trim();
                          final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
                          if (digits.length < 9 || digits.length > 15) {
                            setModalState(() {
                              modalError = 'رقم الهاتف غير صحيح، يرجى التأكد من كتابة الرقم بشكل صحيح (9 أرقام).';
                            });
                            return;
                          }

                          final nav = Navigator.of(modalCtx);

                          final hasNet = await NetworkService().hasInternet();
                          if (!hasNet) {
                            if (!mounted) return;
                            setModalState(() {
                              modalError = 'الشبكة المتصل بها لا يتوفر بها إنترنت. يرجى التأكد من اتصالك بالإنترنت والمحاولة مجدداً.';
                            });
                            return;
                          }

                          setModalState(() {
                            isSubmitting = true;
                            modalError = null;
                          });

                          final res = await _authService.submitPasswordResetTicket(
                            phone: phone,
                            source: 'in_app',
                          );

                          if (!mounted) return;

                          if (res['success'] == true) {
                            nav.pop();
                            await AppDialog.success(
                              context,
                              title: 'تم تسجيل طلبك بنجاح',
                              message: 'تم إرسال طلب استعادة كلمة المرور لرقم الهاتف:\n$phone\nبنجاح إلى إدارة التطبيق.\n\nسيقوم المشرف بمراجعة الطلب وتعيين كلمة المرور وإشعارك لتتمكن من تسجيل الدخول مباشرة.',
                              buttonLabel: 'حسناً',
                            );
                          } else {
                            setModalState(() {
                              isSubmitting = false;
                              modalError = res['error'] ?? 'الرقم غير مسجل في المنصة، يرجى التأكد من كتابة الرقم بشكل صحيح.';
                            });
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.send_rounded, color: Color(0xFFD49B1A), size: 20),
                            const SizedBox(width: 10),
                            Text(
                              'إرسال طلب استعادة كلمة المرور',
                              style: GoogleFonts.cairo(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B2A5B),
      body: Column(
        children: [
          // Top Header with Suit Background Image + Logo + Back Button
          SizedBox(
            height: 260,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Suit background image — exact man in suit with polka-dot tie
                Image.asset(
                  'imag/5818738877521400103.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0.0, -0.15),
                  errorBuilder: (context, error, stackTrace) => Image.asset(
                    'assets/images/suit_bg.jpg',
                    fit: BoxFit.cover,
                    alignment: const Alignment(0.0, -0.15),
                  ),
                ),

                // 2. Gentle cinematic vignette — keeping suit, white collar & polka-dot tie visibly clear
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.20),
                        const Color(0xFF0A1428).withValues(alpha: 0.50),
                      ],
                    ),
                  ),
                ),

                // 3. Back Button (Glass Luxury)
                Positioned(
                  top: 10,
                  right: 16,
                  child: SafeArea(
                    bottom: false,
                    child: GestureDetector(
                      onTap: () {
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
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
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
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
                  ),
                ),

                // 4. Header Content (Logo + Titles)
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo (Hidden 3-second long-press gateway to /admin-portal)
                        Listener(
                          onPointerDown: _onLogoPointerDown,
                          onPointerUp: _onLogoPointerUpOrCancel,
                          onPointerCancel: _onLogoPointerUpOrCancel,
                          behavior: HitTestBehavior.opaque,
                          child: Image.asset(
                            'assets/images/logo_full.png',
                            height: 55,
                            fit: BoxFit.contain,
                          ),
                        ).animate().fadeIn(duration: 500.ms).scale(
                              begin: const Offset(0.88, 0.88),
                              end: const Offset(1.0, 1.0),
                              curve: Curves.easeOutBack,
                            ),

                        const SizedBox(height: 16),

                        // Title with text shadow for crisp readability over image
                        Text(
                          'مرحباً بك مجدداً',
                          style: GoogleFonts.cairo(
                            fontSize: 25,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Color(0xAA000000),
                                blurRadius: 10,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ).animate(delay: 150.ms).fadeIn(duration: 500.ms),

                        const SizedBox(height: 4),

                        // Subtitle with text shadow
                        Text(
                          'سجل الدخول للوصول إلى حسابك',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.90),
                            fontWeight: FontWeight.w600,
                            shadows: const [
                              Shadow(
                                color: Color(0x99000000),
                                blurRadius: 8,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ).animate(delay: 260.ms).fadeIn(duration: 500.ms),
                      ],
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
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B2A5B).withValues(alpha: 0.10),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 2-Option Role Selector Tabs (عميل / محامي)
                      Container(
                        margin: const EdgeInsets.only(bottom: 22),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            _buildRoleTab(
                              roleKey: 'client',
                              title: 'عميل',
                              icon: Icons.person_rounded,
                            ),
                            _buildRoleTab(
                              roleKey: 'lawyer',
                              title: 'محامي',
                              icon: Icons.gavel_rounded,
                            ),
                          ],
                        ),
                      ),

                      // Client / Lawyer Sudan Phone Field (With fixed +249 flag)
                      SudanPhoneFormField(
                        controller: _identifierController,
                        labelText: _selectedRole == 'lawyer'
                            ? 'رقم موبايل المحامي'
                            : 'رقم موبايل العميل',
                        headerIcon: Icons.phone_android_rounded,
                        hintText: '9XXXXXXXX',
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'يرجى إدخال رقم الموبايل';
                          }
                          try {
                            PhoneUtils.normalize(v.trim());
                            return null;
                          } catch (e) {
                            return 'يجب أن يتكون رقم الموبايل من 9 أرقام (مثال: 912345678)';
                          }
                        },
                      ),

                      const SizedBox(height: 18),

                      // Label 2
                      Text(
                        'كلمة المرور',
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0B2A5B),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Input 2
                      TextFormField(
                        controller: _passController,
                        obscureText: _obscure,
                        textDirection: TextDirection.rtl,
                        style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0B2A5B), fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'أدخل كلمة المرور',
                          hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF94A3B8),
                            size: 22,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
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
                            borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFEF4444)),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < 3) {
                            return 'يرجى إدخال كلمة المرور';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 10),

                      // Forgot password link
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: _showForgotPasswordDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              'نسيت كلمة المرور؟',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                color: const Color(0xFFD49B1A),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Error banner
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
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
                              Expanded(
                                child: Text(
                                  _error!,
                                  style: AppTheme.bodySmall.copyWith(color: AppTheme.error),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),

                      // Login button
                      ElevatedButton(
                        onPressed: _loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2A5B),
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          elevation: 2,
                          shadowColor: const Color(0xFF0B2A5B).withValues(alpha: 0.30),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'تسجيل الدخول',
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                      ),

                      const SizedBox(height: 28),

                      // Register link
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: 'ليس لديك حساب؟ ',
                                  style: GoogleFonts.cairo(
                                    color: const Color(0xFF64748B),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: 'إنشاء حساب جديد',
                                  style: GoogleFonts.cairo(
                                    color: const Color(0xFFD49B1A),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0),
          ),
        ],
      ),
    );
  }
}
