import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../network/auth_service.dart';
import '../../../network/network_service.dart';
import '../../../data/models/lawyer.dart';
import '../../../core/utils/phone_utils.dart';
import '../../custom_widgets/sudan_phone_field.dart';
import '../../custom_widgets/square_image_cropper.dart';

class LawyerRegisterScreen extends StatefulWidget {
  const LawyerRegisterScreen({super.key});

  @override
  State<LawyerRegisterScreen> createState() => _LawyerRegisterScreenState();
}

class _LawyerRegisterScreenState extends State<LawyerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedCity;
  String? _photoBase64;
  String? _photoPath;
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;
  bool _submitted = false;
  final _authService = AuthService();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _passController.dispose();
    _confirmPassController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'الصورة الشخصية للمحامي',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'اختر صورتك المهنية لعرضها للعملاء في التطبيق',
              style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library_rounded, color: Color(0xFF3B82F6)),
              ),
              title: Text('اختيار من المعرض', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(ctx).pop('gallery'),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt_rounded, color: Color(0xFF10B981)),
              ),
              title: Text('التقاط صورة بالكاميرا', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              onTap: () => Navigator.of(ctx).pop('camera'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) return;

    try {
      final ImageSource source = result == 'camera' ? ImageSource.camera : ImageSource.gallery;
      final XFile? file = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );
      if (file == null || !mounted) return;

      final croppedResult = await SquareImageCropper.cropImage(
        context,
        imageSource: file,
        title: 'تعديل صورة المحامي',
      );

      if (croppedResult != null && mounted) {
        setState(() {
          _photoBase64 = croppedResult.base64;
          _photoPath = croppedResult.file.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر اختيار الصورة: $e', style: GoogleFonts.cairo()),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCity == null) {
      setState(() => _error = 'يرجى اختيار المدينة');
      return;
    }

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
    final rawWhatsapp = _whatsappController.text.trim();
    final normalizedWhatsapp = rawWhatsapp.isNotEmpty
        ? PhoneUtils.normalize(rawWhatsapp)
        : normalizedPhone;

    final res = await _authService.registerLawyer(
      name: _nameController.text.trim(),
      phone: normalizedPhone,
      whatsapp: normalizedWhatsapp,
      city: _selectedCity!,
      specialization: '',
      password: PhoneUtils.convertArabicDigits(_passController.text.trim()),
      photoBase64: _photoBase64,
    );
    if (!mounted) return;
    setState(() => _loading = false);
    if (res['success'] == true) {
      setState(() => _submitted = true);
    } else {
      setState(() => _error = res['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildSuccessScreen();

    return Scaffold(
      backgroundColor: const Color(0xFF0B2A5B),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF0B2A5B),
              Color(0xFF16254F),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
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
                          'تسجيل كمحامي',
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
                          const SizedBox(height: 20),

                          // Photo Upload Center
                          _buildPhotoUploader(),
                          const SizedBox(height: 24),

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
                                  return 'يرجى إدخال اسم حقيقي بدون حروف مفردة وهمية';
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
                              if (!PhoneUtils.isValid(val)) {
                                return 'يجب إدخال رقم سوداني صحيح مكون من 9 أرقام ويبدأ بـ 9 (مثال: 912345678)';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 3. WhatsApp Number
                          SudanPhoneFormField(
                            controller: _whatsappController,
                            labelText: 'رقم الواتساب المعتمد للاستشارات',
                            headerIcon: Icons.chat_bubble_outline_rounded,
                            isRequired: false,
                            hintText: '9XXXXXXXX (أو نفس رقم الهاتف)',
                            validator: (v) {
                              final val = v?.trim() ?? '';
                              if (val.isNotEmpty && !PhoneUtils.isValid(val)) {
                                return 'يجب إدخال رقم سوداني صحيح مكون من 9 أرقام ويبدأ بـ 9';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 4. City
                          _buildFieldHeader('المدينة والمقر القانوني', Icons.location_city_rounded),
                          const SizedBox(height: 8),
                          _buildPickerSelector(
                            label: _selectedCity ?? 'اختر مدينتك',
                            isSelected: _selectedCity != null,
                            icon: Icons.location_on_outlined,
                            onTap: _openCityPickerModal,
                          ),
                          const SizedBox(height: 18),

                          // 6. Password
                          _buildFieldHeader('كلمة المرور', Icons.lock_outline_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passController,
                            obscureText: _obscure,
                            keyboardType: TextInputType.visiblePassword,
                            autocorrect: false,
                            enableSuggestions: false,
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
                            validator: (v) {
                              final pass = PhoneUtils.convertArabicDigits(v?.trim() ?? '');
                              return pass.length < 6 ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل' : null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // 7. Confirm Password
                          _buildFieldHeader('تأكيد كلمة المرور', Icons.lock_outline_rounded),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _confirmPassController,
                            obscureText: _obscureConfirm,
                            keyboardType: TextInputType.visiblePassword,
                            autocorrect: false,
                            enableSuggestions: false,
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
                            validator: (v) {
                              final pass = PhoneUtils.convertArabicDigits(_passController.text.trim());
                              final confirm = PhoneUtils.convertArabicDigits(v?.trim() ?? '');
                              return confirm != pass ? 'كلمتا المرور غير متطابقتين' : null;
                            },
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
                                          'إرسال طلب الانضمام',
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
                ).animate(delay: 300.ms).fadeIn(duration: 500.ms).slideY(begin: 0.1, end: 0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoUploader() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0B2A5B), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _photoBase64 != null
                        ? Image.memory(
                            base64Decode(_photoBase64!),
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          )
                        : (!kIsWeb && _photoPath != null && File(_photoPath!).existsSync()
                            ? Image.file(
                                File(_photoPath!),
                                width: 90,
                                height: 90,
                                fit: BoxFit.cover,
                              )
                            : const Center(
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF0B2A5B),
                                  size: 48,
                                ),
                              )),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2A5B),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Color(0xFFFBBF24),
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _photoBase64 != null ? 'تم تحديد صورتك الشخصية ✅' : 'إضافة صورتك المهنية (اختياري)',
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _photoBase64 != null ? const Color(0xFF10B981) : const Color(0xFF0B2A5B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.navyGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color: AppTheme.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.gold.withValues(alpha: 0.4), width: 2),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppTheme.gold, size: 56),
                  ).animate().scale(begin: const Offset(0.5, 0.5), end: const Offset(1.0, 1.0),
                      duration: 600.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 32),
                  Text('تم إرسال طلبك بنجاح!',
                      style: AppTheme.headingMedium.copyWith(color: Colors.white),
                      textAlign: TextAlign.center)
                      .animate(delay: 400.ms).fadeIn(duration: 500.ms),
                  const SizedBox(height: 16),
                  Text('سيقوم المشرف العام بمراجعة طلبك وصورتك والموافقة عليه في أقرب وقت. ستتمكن من الدخول بعد الموافقة.',
                      style: AppTheme.bodyMedium.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center)
                      .animate(delay: 600.ms).fadeIn(duration: 500.ms),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      minimumSize: const Size(200, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('العودة للرئيسية',
                        style: AppTheme.buttonText.copyWith(color: AppTheme.navyDark)),
                  ).animate(delay: 800.ms).fadeIn(duration: 500.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline_rounded, color: Color(0xFF0B2A5B), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'سيُراجع المشرف طلبك ويوافق عليه قبل تفعيل حسابك',
              textDirection: TextDirection.rtl,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
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

  Widget _buildPickerSelector({
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFF94A3B8),
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF0B2A5B) : const Color(0xFF94A3B8),
                ),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFF64748B),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _openCityPickerModal() {
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final filteredCities = SudanCities.names.where((c) => c.contains(query.trim())).toList();

          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.75,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD49B1A).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.location_city_rounded, color: Color(0xFFD49B1A), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'اختر مدينتك الرئيسية',
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          Text(
                            'المدينة التي تمارس فيها عملك القانوني وتظهر فيها للعملاء',
                            style: GoogleFonts.cairo(fontSize: 11.5, color: const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  textDirection: TextDirection.rtl,
                  onChanged: (val) => setModalState(() => query = val),
                  style: GoogleFonts.cairo(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'ابحث عن اسم المدينة...',
                    hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                    prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD49B1A), size: 20),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: filteredCities.isEmpty
                      ? Center(
                          child: Text(
                            'لم يتم العثور على مدينة بهذا الاسم',
                            style: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: filteredCities.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                          itemBuilder: (_, index) {
                            final city = filteredCities[index];
                            final isSelected = _selectedCity == city;
                            return InkWell(
                              onTap: () {
                                setState(() => _selectedCity = city);
                                Navigator.pop(ctx);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFFFFBEB) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 19,
                                      color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        city,
                                        style: GoogleFonts.cairo(
                                          fontSize: 14,
                                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                          color: isSelected ? const Color(0xFF0B2A5B) : const Color(0xFF334155),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFFD49B1A), size: 20),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
