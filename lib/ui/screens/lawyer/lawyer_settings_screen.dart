import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../network/auth_service.dart';
import '../../../network/firestore_service.dart';
import '../../../network/storage_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/profile_details_modal.dart';
import '../../custom_widgets/square_image_cropper.dart';
import '../onboarding/onboarding_screen.dart';
import '../profile/contact_admin_screen.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/app_error_translator.dart';

class LawyerSettingsScreen extends StatefulWidget {
  const LawyerSettingsScreen({super.key});

  @override
  State<LawyerSettingsScreen> createState() => _LawyerSettingsScreenState();
}

class _LawyerSettingsScreenState extends State<LawyerSettingsScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _picker = ImagePicker();

  String? _uid;
  String _name = 'الأستاذ المحامي';
  String _phone = '';
  String? _photoUrl;
  String? _photoBase64;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final session = await _authService.getSavedSession();
    final user = _authService.currentUser;
    final uid = session['uid'] ?? user?.uid;
    final prefs = await SharedPreferences.getInstance();
    final localPhotoUrl = prefs.getString('user_profile_photo_url');
    final localPhoto = prefs.getString('user_profile_photo');

    if (mounted) {
      setState(() {
        _uid = uid;
        _name = session['name'] ?? 'الأستاذ المحامي';
        _phone = session['phone'] ?? '';
        _photoUrl = localPhotoUrl;
        _photoBase64 = localPhoto;
      });
    }

    if (uid != null) {
      try {
        final lawyer = await _firestoreService.getLawyer(uid);
        if (lawyer != null && mounted) {
          setState(() {
            _photoUrl = lawyer.photoUrl;
            _photoBase64 = lawyer.photoBase64;
            if (lawyer.name.isNotEmpty) _name = lawyer.name;
            if (lawyer.phone.isNotEmpty) _phone = lawyer.phone;
          });
          if (lawyer.photoUrl != null) {
            await prefs.setString('user_profile_photo_url', lawyer.photoUrl!);
          }
          if (lawyer.photoBase64 != null) {
            await prefs.setString('user_profile_photo', lawyer.photoBase64!);
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_uid == null) return;

    final source = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4.5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'تغيير الصورة الشخصية للمحامي',
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'هذه الصورة ستظهر لكافة العملاء والمراجعين عند البحث عنك في المنصة.',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded, color: Color(0xFF0B2A5B)),
                    label: Text('المعرض', style: GoogleFonts.cairo(color: const Color(0xFF0B2A5B), fontWeight: FontWeight.w800)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx, ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded, color: Colors.white),
                    label: Text('الكاميرا', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2A5B),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
            if ((_photoUrl != null && _photoUrl!.isNotEmpty) || (_photoBase64 != null && _photoBase64!.isNotEmpty)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(ctx, 'delete'),
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 20),
                  label: Text(
                    'حذف الصورة واستخدام المونوغرام الذهبي',
                    style: GoogleFonts.cairo(
                      color: const Color(0xFFEF4444),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
        ),
      ),
    );

    if (source == null || !mounted) return;

    if (source == 'delete') {
      try {
        setState(() => _uploadingPhoto = true);
        if (_photoUrl != null) {
          await StorageService().deleteOldPhoto(_photoUrl);
        }
        await _firestoreService.updateLawyerProfile(
          uid: _uid!,
          photoUrl: '',
          photoBase64: '',
        );
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('user_profile_photo');
        await prefs.remove('user_profile_photo_url');
        if (mounted) {
          setState(() {
            _photoUrl = null;
            _photoBase64 = null;
            _uploadingPhoto = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                textDirection: TextDirection.rtl,
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'تم حذف الصورة واستعادة المونوغرام الذهبي الفاخر بنجاح!',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF0B2A5B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } catch (e) {
        if (mounted) setState(() => _uploadingPhoto = false);
      }
      return;
    }

    if (source is! ImageSource) return;

    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
      if (file == null || !mounted) return;

      final croppedResult = await SquareImageCropper.cropImage(
        context,
        imageSource: file,
        title: 'تعديل الصورة الشخصية للمحامي',
      );

      if (croppedResult == null || !mounted) return;

      setState(() => _uploadingPhoto = true);

      // Upload safely to Firebase Storage
      final downloadUrl = await StorageService().uploadProfilePhoto(
        uid: _uid!,
        imageFile: croppedResult.file,
        oldPhotoUrl: _photoUrl,
      );

      // Update in Firestore and local cache
      final success = await _firestoreService.updateLawyerProfile(
        uid: _uid!,
        photoUrl: downloadUrl,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_photo_url', downloadUrl);

      final String base64Photo = croppedResult.base64;
      try {
        final Map<String, dynamic> updateData = {'photoUrl': downloadUrl};
        if (base64Photo.length < 50000) {
          updateData['photoBase64'] = base64Photo;
        }
        await FirebaseFirestore.instance.collection('users').doc(_uid!).set(updateData, SetOptions(merge: true));
        await FirebaseFirestore.instance.collection('lawyers').doc(_uid!).set(updateData, SetOptions(merge: true));
        await prefs.setString('user_profile_photo_base64', base64Photo);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _photoUrl = downloadUrl;
          _photoBase64 = base64Photo;
          _uploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    success
                        ? 'تم حفظ وتحديث صورتك الشخصية بنجاح!'
                        : 'تعذر الحفظ، يرجى التحقق من اتصالك بالإنترنت.',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: success ? const Color(0xFF10B981) : AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppErrorTranslator.translate(
                e,
                defaultMessage: 'تعذر رفع الصورة، يرجى المحاولة بصورة أصغر أو التحقق من اتصالك.',
              ),
              style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
            ),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'تغيير كلمة المرور',
                      style: GoogleFonts.cairo(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // 1. Current Password Field
                    TextFormField(
                      controller: currentPassController,
                      obscureText: obscureCurrent,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الحالية',
                        labelStyle: GoogleFonts.cairo(fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_clock_rounded, color: Color(0xFFD49B1A)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'يرجى إدخال كلمة المرور الحالية';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // 2. New Password Field
                    TextFormField(
                      controller: newPassController,
                      obscureText: obscureNew,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'كلمة المرور الجديدة',
                        labelStyle: GoogleFonts.cairo(fontSize: 13),
                        prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFD49B1A)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () => setModalState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.length < 6) return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),
                    // 3. Confirm New Password Field
                    TextFormField(
                      controller: confirmPassController,
                      obscureText: obscureConfirm,
                      textDirection: TextDirection.rtl,
                      style: GoogleFonts.cairo(fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'تأكيد كلمة المرور الجديدة',
                        labelStyle: GoogleFonts.cairo(fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFD49B1A)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF94A3B8),
                            size: 20,
                          ),
                          onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5),
                        ),
                      ),
                      validator: (v) {
                        if (v != newPassController.text) return 'كلمتا المرور غير متطابقتين';
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: saving
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => saving = true);

                                Map<String, dynamic> res;
                                try {
                                  res = await _authService.reauthenticateAndChangePassword(
                                    currentPassword: PhoneUtils.normalizeDigits(currentPassController.text.trim()),
                                    newPassword: PhoneUtils.normalizeDigits(newPassController.text.trim()),
                                  );
                                } catch (e) {
                                  res = {'success': false, 'error': 'حدث خطأ غير متوقع، يرجى المحاولة مجدداً'};
                                }

                                // Always reset saving regardless of mount state
                                setModalState(() => saving = false);

                                if (res['success'] == true) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'تم تغيير كلمة المرور بنجاح',
                                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                                        ),
                                        backgroundColor: const Color(0xFF10B981),
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                } else {
                                  // Show error inside the bottom sheet
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          res['error']?.toString() ?? 'تعذر تغيير كلمة المرور',
                                          style: GoogleFonts.cairo(),
                                        ),
                                        backgroundColor: AppTheme.error,
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                    );
                                  }
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2A5B),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: saving
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                'حفظ كلمة المرور الجديدة',
                                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_rounded, color: Color(0xFFD49B1A), size: 22),
                const SizedBox(width: 8),
                Text(
                  'الشروط والأحكام وميثاق الخصوصية',
                  style: GoogleFonts.cairo(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مرحباً بك في منصة محاميك. بصفتك محامياً معتمداً في المنصة، يتعين الالتزام بآداب وأخلاقيات مهنة المحاماة المعمول بها في جمهورية السودان وسياسة حماية البيانات:\n\n'
                      '1. صحة وموثوقية البيانات:\nيلتزم المحامي بتقديم بيانات صحيحة ومحدثة بخصوص ترخيصه ومقر عمله وأرقام التواصل المباشرة والواتساب لضمان موثوقية المنصة أمام المراجعين.\n\n'
                      '2. جمع البيانات والوسائط:\nيتم تخزين بيانات ملفك المهني وصورتك الشخصية الاختيارية عبر خوادم Google Cloud Firebase المشفرة، وتُستخدم فقط لتمكين العملاء من التواصل معك.\n\n'
                      '3. حماية السرية المهنية:\nكافة المحادثات والاستشارات بينك وبين العملاء تتم عبر قنوات الاتصال المباشرة المشفرة (الهاتف / الواتساب) ولا يتم تسجيلها أو الاطلاع عليها من قِبل المنصة.\n\n'
                      '4. عدم مشاركة البيانات مع أطراف ثالثة:\nمنصة محاميك لا تقوم ببيع أو تأجير بيانات المستخدمين أو استخدامها لأي أغراض إعلانية غير مصرح بها.\n\n'
                      '5. حق الحذف الكامل (Apple & Google Compliance):\nيحق لك في أي وقت حذف حسابك المهني وكافة بياناتك وصورتك نهائياً وبنقرة واحدة عبر زر (حذف الحساب المهني) في أسفل هذه الشاشة.',
                      style: GoogleFonts.cairo(fontSize: 12.5, height: 1.65, color: const Color(0xFF475569)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD49B1A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('فهمت وموافق', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: const Color(0xFF0B2A5B))),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog() async {
    final passCtrl = TextEditingController();
    bool isDeleting = false;
    bool obscurePass = true;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.white,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Warning Icon Badge
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.delete_forever_rounded, color: Color(0xFFDC2626), size: 30),
                  ),
                ),
                const SizedBox(height: 14),

                // Dialog Title
                Text(
                  'حذف الحساب المهني نهائياً',
                  style: GoogleFonts.cairo(
                    color: const Color(0xFF0B2A5B),
                    fontWeight: FontWeight.w800,
                    fontSize: 17.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),

                // Warning Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'تحذير: سيتم حذف حسابك المهني وكافة بياناتك وصورتك وملفك نهائياً من منصة محاميك، ولن يتمكن أي عميل من الوصول إليك. لا يمكن التراجع عن هذا الإجراء.',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF991B1B),
                            fontSize: 12,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Password Confirmation Field
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0B2A5B), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'أدخل كلمة المرور لتأكيد الحذف',
                    hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 19,
                      ),
                      onPressed: () => setDlgState(() => obscurePass = !obscurePass),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
                      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
                    ),
                  ),
                ),

                if (error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error!,
                            style: GoogleFonts.cairo(color: const Color(0xFFDC2626), fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isDeleting ? null : () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'إلغاء',
                          style: GoogleFonts.cairo(color: const Color(0xFF64748B), fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: isDeleting
                            ? null
                            : () async {
                                if (passCtrl.text.isEmpty) {
                                  setDlgState(() => error = 'يرجى إدخال كلمة المرور لتأكيد الحذف');
                                  return;
                                }

                                setDlgState(() {
                                  isDeleting = true;
                                  error = null;
                                });

                                final nav = Navigator.of(context);
                                final dlgNav = Navigator.of(ctx);
                                final res = await _authService.deleteAccount(currentPassword: passCtrl.text);

                                if (!mounted) return;
                                if (res['success'] == true) {
                                  dlgNav.pop();
                                  nav.pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                                    (_) => false,
                                  );
                                } else {
                                  setDlgState(() {
                                    isDeleting = false;
                                    error = res['error'] ?? 'تعذر حذف الحساب، تأكد من صحة كلمة المرور';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 1,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isDeleting
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete_outline_rounded, size: 18),
                                  const SizedBox(width: 6),
                                  Text('تأكيد الحذف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14)),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFECDD3), width: 1.5),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFE11D48), size: 30),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'تسجيل الخروج',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 17.5,
                  color: const Color(0xFF0B2A5B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'هل أنت متأكد من رغبتك في تسجيل الخروج من حساب المحامي؟',
                style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF64748B),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('تأكيد الخروج', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      NavigationUtils.smoothSignOut(context);
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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (Navigator.canPop(context)) ...[
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 38,
                      height: 38,
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
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                const AppLogoBadge(height: 25, withPillBackground: true),
              ],
            ),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.manage_accounts_rounded, color: Color(0xFF0B2A5B), size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'إعدادات الحساب والصورة',
                        style: GoogleFonts.cairo(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B2A5B),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 95),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Dedicated Lawyer Photo Management Studio
            _buildPhotoStudioCard(),
            const SizedBox(height: 20),

            // 2. Section Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 18,
                  decoration: BoxDecoration(
                    color: headerGold,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'أمان الحساب والتواصل',
                  style: GoogleFonts.cairo(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 3. Settings Items List
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSettingRow(
                    icon: Icons.lock_outline_rounded,
                    iconColor: const Color(0xFFD97706),
                    title: 'تغيير كلمة المرور',
                    subtitle: 'تحديث كلمة المرور لحماية حسابك المهني',
                    onTap: _changePassword,
                  ),
                  const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xFFF1F5F9)),
                  _buildSettingRow(
                    icon: Icons.support_agent_rounded,
                    iconColor: const Color(0xFF0B2A5B),
                    title: 'معلومات الاتصال بالإدارة',
                    subtitle: 'تواصل مباشرة مع إدارة المنصة للمساعدة والدعم',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ContactAdminScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xFFF1F5F9)),
                  _buildSettingRow(
                    icon: Icons.shield_outlined,
                    iconColor: const Color(0xFF10B981),
                    title: 'الشروط والأحكام وميثاق الاستخدام',
                    subtitle: 'ميثاق الممارسة والخصوصية للمحامين المعتمدين',
                    onTap: _showTermsModal,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. Logout Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                label: Text(
                  'تسجيل الخروج',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFFEF4444),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B2A5B),
                  elevation: 2,
                  shadowColor: const Color(0xFF0B2A5B).withValues(alpha: 0.35),
                  side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 5. Permanent Account Deletion (Apple Guideline 5.1.1(v))
            InkWell(
              onTap: _showDeleteAccountDialog,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2).withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFCA5A5).withValues(alpha: 0.7), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.delete_forever_rounded,
                        color: Color(0xFFDC2626),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'حذف الحساب المهني والبيانات نهائياً',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Dedicated Lawyer Photo Management Studio
  // ─────────────────────────────────────────────────────────────
  Widget _buildPhotoStudioCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      child: Column(
        children: [
          // Photo with Dark Navy Dual-Ring & LongPress Viewer
          Center(
            child: Stack(
              children: [
                GestureDetector(
                  onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                  onLongPress: () {
                    if ((_photoUrl != null && _photoUrl!.isNotEmpty) ||
                        (_photoBase64 != null && _photoBase64!.isNotEmpty)) {
                      ProfileDetailsModal.openPhotoViewer(
                        context,
                        name: _name,
                        photoBase64: _photoBase64,
                        photoUrl: _photoUrl,
                        subtitle: _phone,
                      );
                    }
                  },
                  child: Container(
                    width: 98,
                    height: 98,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFF0B2A5B), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: _uploadingPhoto
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0B2A5B)))
                          : _buildAvatar(),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _uploadingPhoto ? null : _pickAndUploadPhoto,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B2A5B),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2.2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Lawyer Name with Verified Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  _name,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0B2A5B),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.verified_rounded, color: Color(0xFFD49B1A), size: 18),
            ],
          ),

          // Formatted Phone Capsule Pill (Image 2 & 3 fix)
          if (_phone.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFFD49B1A)),
                  const SizedBox(width: 6),
                  Text(
                    PhoneUtils.formatForDisplay(_phone),
                    textDirection: TextDirection.ltr,
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),

          // Primary Change Photo Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _uploadingPhoto ? null : _pickAndUploadPhoto,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B2A5B),
                foregroundColor: Colors.white,
                elevation: 2,
                shadowColor: const Color(0xFF0B2A5B).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_uploadingPhoto) ...[
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'جاري رفع وحفظ الصورة...',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ] else ...[
                    const Icon(Icons.add_a_photo_rounded, color: Color(0xFFD49B1A), size: 19),
                    const SizedBox(width: 8),
                    Text(
                      'تغيير وتحديث الصورة الشخصية',
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Helper Hint
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الصورة التي ترفعها هنا تظهر فوراً لكافة المراجعين عند البحث عنك في كل شاشات التطبيق.',
                    textAlign: TextAlign.start,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      if (_photoUrl!.startsWith('data:image')) {
        try {
          final bytes = base64Decode(_photoUrl!.split(',').last);
          return Image.memory(bytes, fit: BoxFit.cover);
        } catch (_) {}
      }
      return Image.network(
        _photoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildBase64OrPlaceholder(_photoBase64),
      );
    }
    return _buildBase64OrPlaceholder(_photoBase64);
  }

  Widget _buildBase64OrPlaceholder(String? photoBase64) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {}
    }
    return Container(
      color: const Color(0xFF0B2A5B),
      child: const Center(
        child: Icon(Icons.person_rounded, color: Colors.white, size: 50),
      ),
    );
  }
}
