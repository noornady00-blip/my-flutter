import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../network/auth_service.dart';
import '../../../network/storage_service.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/awake_badge.dart';
import '../../custom_widgets/profile_details_modal.dart';
import '../../custom_widgets/square_image_cropper.dart';
import '../auth/auth_gateway_screen.dart';
import 'contact_admin_screen.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/app_error_translator.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../../network/chat_service.dart';

class ProfileScreen extends StatefulWidget {
  final bool isStandalone;
  final VoidCallback? onOpenDrawer;
  const ProfileScreen({super.key, this.isStandalone = false, this.onOpenDrawer});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final ImagePicker _picker = ImagePicker();

  String _userName = 'عميل منصة محاميك';
  String _userPhone = 'لا يوجد رقم مسجل';
  String _userRole = 'client';
  String? _userUid;
  String? _accountId;
  bool _isLoggedIn = false;
  int _avatarIndex = 0;
  String? _photoUrl;
  String? _photoBase64;
  String? _photoPath;
  DateTime? _createdAt;

  final List<IconData> _avatars = [
    Icons.person_rounded,
    Icons.account_circle_rounded,
    Icons.face_rounded,
    Icons.person_pin_rounded,
    Icons.military_tech_rounded,
    Icons.shield_rounded,
    Icons.gavel_rounded,
    Icons.business_center_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final session = await _authService.getSavedSession();
    final currentUser = FirebaseAuth.instance.currentUser;

    final prefs = await SharedPreferences.getInstance();
    final savedAvatar = prefs.getInt('user_avatar_idx') ?? 0;
    final savedPhotoUrl = prefs.getString('user_profile_photo_url');
    final savedPhoto = prefs.getString('user_profile_photo');
    final savedPhotoPath = prefs.getString('user_profile_photo_path');
    final savedAccountId = prefs.getString('user_account_id');

    setState(() {
      _avatarIndex = savedAvatar;
      _photoUrl = savedPhotoUrl;
      _photoBase64 = savedPhoto;
      _photoPath = savedPhotoPath;

      if (session['name'] != null && session['name']!.isNotEmpty) {
        _userUid = session['uid'];
        _userName = session['name']!;
        _userPhone = session['phone'] ?? (currentUser?.email ?? 'غير محدد');
        _userRole = session['role'] ?? 'client';
        _accountId = session['accountId'] ?? savedAccountId;
        _isLoggedIn = true;
      } else if (currentUser != null) {
        _userUid = currentUser.uid;
        _userName = currentUser.displayName ?? 'عميل محاميك';
        _userPhone = currentUser.email?.replaceAll('@mahameek.client.com', '').replaceAll('@mahameek.lawyer.com', '') ?? 'غير محدد';
        _accountId = savedAccountId;
        _isLoggedIn = true;
      } else {
        _userName = 'عميل محاميك';
        _userPhone = 'سجل دخولك للاستفادة من كافة الخدمات';
        _accountId = null;
        _isLoggedIn = false;
      }
    });

    if (_userUid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(_userUid).get();
        String? cloudAccountId = doc.data()?['accountId'] as String?;
        if (doc.exists) {
          final cloudUrl = doc.data()?['photoUrl'] as String?;
          final cloudPhoto = doc.data()?['photoBase64'] as String?;
          final rawCreated = doc.data()?['createdAt'];
          DateTime? parsedDate;
          if (rawCreated is Timestamp) {
            parsedDate = rawCreated.toDate();
          } else if (rawCreated is String) {
            parsedDate = DateTime.tryParse(rawCreated);
          }
          if (mounted) {
            setState(() {
              if (cloudUrl != null) _photoUrl = cloudUrl;
              if (cloudPhoto != null) _photoBase64 = cloudPhoto;
              if (parsedDate != null) _createdAt = parsedDate;
            });
            if (cloudUrl != null) await prefs.setString('user_profile_photo_url', cloudUrl);
          }
        }

        if (cloudAccountId == null || cloudAccountId.isEmpty) {
          final lawyerDoc = await FirebaseFirestore.instance.collection('lawyers').doc(_userUid).get();
          cloudAccountId = lawyerDoc.data()?['accountId'] as String?;
        }

        if (cloudAccountId == null || cloudAccountId.isEmpty) {
          cloudAccountId = await AccountIdUtils.ensureUserHasAccountId(
            uid: _userUid!,
            role: _userRole,
          );
        }

        if (mounted && cloudAccountId.isNotEmpty) {
          setState(() {
            _accountId = cloudAccountId;
          });
          await prefs.setString('user_account_id', cloudAccountId);
        }
      } catch (_) {}
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '2026/01/15';
    return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
  }

  // Pick Image from Gallery or Camera & upload to Firebase Storage
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile == null || !mounted) return;

      final croppedResult = await SquareImageCropper.cropImage(
        context,
        imageSource: pickedFile,
        title: 'تعديل الصورة الشخصية',
      );

      if (croppedResult == null || !mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              const SizedBox(width: 12),
              Text('جاري حفظ وتأمين صورتك الشخصية...', style: GoogleFonts.cairo()),
            ],
          ),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF0B2A5B),
        ),
      );

      String cleanUid = (_userUid != null && _userUid!.trim().isNotEmpty)
          ? _userUid!.trim()
          : (FirebaseAuth.instance.currentUser?.uid ?? '');
      if (cleanUid.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        cleanUid = prefs.getString('user_uid') ?? 'unknown';
      }

      final downloadUrl = await StorageService().uploadProfilePhoto(
        uid: cleanUid,
        imageFile: croppedResult.file,
        oldPhotoUrl: _photoUrl,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_profile_photo_url', downloadUrl);
      await prefs.setString('user_profile_photo_path', croppedResult.file.path);

      final String base64Str = croppedResult.base64;
      await prefs.setString('user_profile_photo_base64', base64Str);

      if (cleanUid.isNotEmpty && cleanUid != 'unknown') {
        final Map<String, dynamic> updateData = {
          'photoUrl': downloadUrl,
          'photoBase64': base64Str,
          'user_profile_photo_base64': base64Str,
          'user_profile_photo_url': downloadUrl,
          'photo': downloadUrl,
          'imageUrl': downloadUrl,
          'profileImage': downloadUrl,
        };

        try {
          final batch = FirebaseFirestore.instance.batch();
          batch.set(
            FirebaseFirestore.instance.collection('users').doc(cleanUid),
            updateData,
            SetOptions(merge: true),
          );
          // If the user is a lawyer, also update the lawyers collection
          if (_userRole == 'lawyer' || _userRole == 'approved_lawyer') {
            batch.set(
              FirebaseFirestore.instance.collection('lawyers').doc(cleanUid),
              updateData,
              SetOptions(merge: true),
            );
          }

          // Also synchronize photo into phone_directory for immediate lookup by phone
          if (_userPhone.isNotEmpty) {
            try {
              final normPhone = PhoneUtils.normalize(_userPhone);
              final dirData = {
                'photoUrl': downloadUrl,
                'photoBase64': base64Str,
                'photo': downloadUrl,
                'user_profile_photo_url': downloadUrl,
              };
              batch.set(FirebaseFirestore.instance.collection('phone_directory').doc(normPhone), dirData, SetOptions(merge: true));
            } catch (_) {}
          }

          await batch.commit();

          // Sync photo to all active chats where this user participates
          unawaited(ChatService().syncUserProfileToAllChats(
            uid: cleanUid,
            role: _userRole,
            photoUrl: downloadUrl,
            photoBase64: base64Str,
            name: _userName,
            phone: _userPhone,
            accountId: _accountId,
          ));
        } catch (dbErr) {
          debugPrint('Firestore update notice: $dbErr');
        }
      }

      if (!mounted) return;
      setState(() {
        _photoUrl = downloadUrl;
        _photoPath = croppedResult.file.path;
        _photoBase64 = base64Str;
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
                  'تم تحديث صورتك الشخصية بنجاح!',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              textDirection: TextDirection.rtl,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppErrorTranslator.translate(
                      e,
                      defaultMessage: 'تعذر رفع الصورة الشخصية، يرجى المحاولة بصورة أصغر أو التحقق من اتصالك.',
                    ),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            ),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  // Photo / Avatar Selector Sheet
  Future<void> _showPhotoOptions() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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
                  'الصورة الشخصية',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'اختر من المعرض أو التقط صورة بالكاميرا',
                  style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                _buildPickerOption(
                  icon: Icons.photo_library_rounded,
                  title: 'اختيار من معرض الصور',
                  color: const Color(0xFF3B82F6),
                  onTap: () => Navigator.of(ctx).pop('gallery'),
                ),
                const SizedBox(height: 10),

                _buildPickerOption(
                  icon: Icons.camera_alt_rounded,
                  title: 'التقاط صورة جديدة بالكاميرا',
                  color: const Color(0xFF10B981),
                  onTap: () => Navigator.of(ctx).pop('camera'),
                ),
                const SizedBox(height: 10),

                _buildPickerOption(
                  icon: Icons.face_rounded,
                  title: 'اختيار رمز تعبيري بديل',
                  color: const Color(0xFFF59E0B),
                  onTap: () => Navigator.of(ctx).pop('avatar'),
                ),

                if (_photoUrl != null || _photoBase64 != null) ...[
                  const SizedBox(height: 10),
                  _buildPickerOption(
                    icon: Icons.delete_outline_rounded,
                    title: 'إزالة الصورة الحالية',
                    color: const Color(0xFFEF4444),
                    onTap: () => Navigator.of(ctx).pop('remove'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || result == null) return;

    if (result == 'gallery') {
      await _pickImage(ImageSource.gallery);
    } else if (result == 'camera') {
      await _pickImage(ImageSource.camera);
    } else if (result == 'avatar') {
      _showAvatarPicker();
    } else if (result == 'remove') {
      if (_photoUrl != null) {
        await StorageService().deleteOldPhoto(_photoUrl);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_profile_photo');
      await prefs.remove('user_profile_photo_url');
      await prefs.remove('user_profile_photo_path');
      if (_userUid != null) {
        await FirebaseFirestore.instance.collection('users').doc(_userUid).set({
          'photoUrl': FieldValue.delete(),
          'photoBase64': FieldValue.delete(),
          'user_profile_photo_base64': FieldValue.delete(),
          'user_profile_photo_url': FieldValue.delete(),
        }, SetOptions(merge: true));

        unawaited(ChatService().syncUserProfileToAllChats(
          uid: _userUid!,
          role: _userRole,
          photoUrl: '',
          photoBase64: '',
        ));
      }
      setState(() {
        _photoUrl = null;
        _photoBase64 = null;
        _photoPath = null;
      });
    }
  }

  Widget _buildPickerOption({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B2A5B),
                ),
              ),
            ),
            const Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  void _showAvatarPicker() {
    showModalBottomSheet(
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
              'اختر رمز صورتك الشخصية',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'اختر الرمز الذي يعبر عن حسابك في المنصة',
              style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(_avatars.length, (index) {
                final isSelected = _avatarIndex == index && _photoBase64 == null;
                return InkWell(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('user_avatar_idx', index);
                    await prefs.remove('user_profile_photo');
                    await prefs.remove('user_profile_photo_path');
                    if (!mounted) return;
                    setState(() {
                      _avatarIndex = index;
                      _photoBase64 = null;
                      _photoPath = null;
                    });
                    if (!ctx.mounted) return;
                    Navigator.of(ctx).pop();
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFFFFBEB) : const Color(0xFFF8FAFC),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: Icon(
                      _avatars[index],
                      color: isSelected ? const Color(0xFFF59E0B) : const Color(0xFF0B2A5B),
                      size: 32,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final oldPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool loading = false;
    String? error;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
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
                  'تغيير كلمة المرور',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أدخل كلمة المرور الجديدة للحفاظ على أمان حسابك',
                  style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                _buildInputField(
                  controller: oldPassCtrl,
                  hint: 'كلمة المرور الحالية',
                  icon: Icons.lock_outline_rounded,
                  obscure: obscureOld,
                  onToggleObscure: () => setModalState(() => obscureOld = !obscureOld),
                ),
                const SizedBox(height: 12),

                _buildInputField(
                  controller: newPassCtrl,
                  hint: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
                  icon: Icons.key_rounded,
                  obscure: obscureNew,
                  onToggleObscure: () => setModalState(() => obscureNew = !obscureNew),
                ),
                const SizedBox(height: 12),

                _buildInputField(
                  controller: confirmPassCtrl,
                  hint: 'تأكيد كلمة المرور الجديدة',
                  icon: Icons.lock_rounded,
                  obscure: obscureConfirm,
                  onToggleObscure: () => setModalState(() => obscureConfirm = !obscureConfirm),
                ),
                const SizedBox(height: 12),

                if (error != null) ...[
                  Text(error!, style: GoogleFonts.cairo(color: AppTheme.error, fontSize: 13)),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final curP = PhoneUtils.convertArabicDigits(oldPassCtrl.text.trim());
                          final newP = PhoneUtils.convertArabicDigits(newPassCtrl.text.trim());
                          final confP = PhoneUtils.convertArabicDigits(confirmPassCtrl.text.trim());

                          if (curP.isEmpty) {
                            setModalState(() => error = 'يرجى إدخال كلمة المرور الحالية');
                            return;
                          }
                          if (newP.length < 6) {
                            setModalState(() => error = 'كلمة المرور يجب أن تكون 6 أحرف على الأقل');
                            return;
                          }
                          if (newP != confP) {
                            setModalState(() => error = 'كلمة المرور غير متطابقة');
                            return;
                          }

                          setModalState(() {
                            loading = true;
                            error = null;
                          });

                          Map<String, dynamic> res;
                          try {
                            res = await _authService.reauthenticateAndChangePassword(
                              currentPassword: curP,
                              newPassword: newP,
                            );
                          } catch (e) {
                            res = {'success': false, 'error': 'حدث خطأ غير متوقع، يرجى المحاولة مجدداً'};
                          }

                          // Always reset loading regardless of mount state
                          setModalState(() {
                            loading = false;
                            if (res['success'] != true) {
                              error = res['error']?.toString() ??
                                  'حدث خطأ، يرجى التأكد من كلمة المرور الحالية';
                            }
                          });

                          if (res['success'] == true) {
                            if (ctx.mounted) Navigator.of(ctx).pop();
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم تغيير كلمة المرور بنجاح!',
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text('حفظ كلمة المرور الجديدة', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTermsDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF8B5CF6), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'الشروط والأحكام والخصوصية',
                    style: GoogleFonts.cairo(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                '• سرية وخصوصية البيانات:\nمنصة محاميك تلتزم بأعلى معايير حماية البيانات وتشفير الاتصالات وحفظ الخصوصية وفق المعايير العالمية لمتجري Google Play وApple App Store.\n\n'
                '• جمع البيانات والوسائط:\nنقوم بجمع الاسم ورقم الهاتف والمدينة وصورة الملف الشخصي الاختيارية فقط لتمكينك من حجز وتلقي الاستشارات القانونية. تُخزن البيانات على سحابة Google Firebase المشفرة ولا يتم بيعها أو مشاركتها مع أي طرف ثالث إعلاني إطلاقاً.\n\n'
                '• التواصل المباشر:\nالتواصل بينك وبين المحامي يتم عبر قنوات الاتصال المباشرة المشفرة (الهاتف / الواتساب) بموافقتك الكاملة.\n\n'
                '• حق الحذف النهائي للبيانات:\nتضمن المنصة حقك القانوني في حذف حسابك وكافة سجلاتك وصورك نهائياً وفورياً من خلال زر (حذف الحساب نهائياً) المتاح لك في شاشة ملفك الشخصي.',
                style: GoogleFonts.cairo(
                  fontSize: 13,
                  color: const Color(0xFF475569),
                  height: 1.65,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B2A5B),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text('حسناً، فهمت', style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutAppDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
            const SizedBox(height: 20),
            const AppLogoBadge(height: 45, withPillBackground: true),
            const SizedBox(height: 14),
            Text(
              'تطبيق محاميك - المنصة القانونية الأولى',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'الإصدار 1.0.0 (2026)',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'منصة متطورة تربط المواطنين والمؤسسات بأكفأ المحامين وموثقي العقود في كافة ولايات ومدن السودان.',
              style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B), height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _confirmLogout() {
    showDialog(
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
                'هل أنت متأكد من رغبتك في تسجيل الخروج من حسابك؟',
                style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
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
                      onPressed: () {
                        Navigator.pop(ctx);
                        NavigationUtils.smoothSignOut(context);
                      },
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
                const AppLogoBadge.header(),
                const SizedBox(width: 8),
                const Awake247Badge(),
              ],
            ),
            if (widget.isStandalone)
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
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.28),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.55),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF0B2A5B),
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'الملف الشخصي',
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Profile Header Card
              _buildProfileHeaderCard(),
              const SizedBox(height: 22),


              // 2. Account & Security Section
              _buildSectionTitle('الحساب والأمان', const Color(0xFFF59E0B)),
              const SizedBox(height: 12),

              _buildActionCard(
                icon: Icons.lock_reset_rounded,
                title: 'تغيير كلمة المرور',
                subtitle: 'تحديث وتأمين رمز المرور الخاص بحسابك',
                iconColor: const Color(0xFFF59E0B),
                onTap: _showChangePasswordDialog,
              ),
              const SizedBox(height: 22),

              // 3. Support & Assistance Section
              _buildSectionTitle('الدعم والتواصل المباشر', const Color(0xFF3B82F6)),
              const SizedBox(height: 12),

              _buildActionCard(
                icon: Icons.support_agent_rounded,
                title: 'معلومات الاتصال بالإدارة',
                subtitle: 'قنوات الدعم الفني، الواتساب، ونموذج المراسلة الفورية',
                iconColor: const Color(0xFF3B82F6),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ContactAdminScreen()),
                  );
                },
              ),
              const SizedBox(height: 22),

              // 4. Legal & App Info Section
              _buildSectionTitle('المعلومات والخصوصية', const Color(0xFF8B5CF6)),
              const SizedBox(height: 12),

              _buildActionCard(
                icon: Icons.verified_user_outlined,
                title: 'شروط الاستخدام وسياسة الخصوصية',
                subtitle: 'ميثاق حماية البيانات وسرية الاستشارات القانونية',
                iconColor: const Color(0xFF8B5CF6),
                onTap: _showTermsDialog,
              ),
              const SizedBox(height: 10),

              _buildActionCard(
                icon: Icons.info_outline_rounded,
                title: 'عن منصة محاميك',
                subtitle: 'معلومات التطبيق، الإصدار، ورسالة المنصة',
                iconColor: const Color(0xFF0B2A5B),
                onTap: _showAboutAppDialog,
              ),
              const SizedBox(height: 26),

              // 5. Logout / Login Button
              if (_isLoggedIn) ...[
                _buildLogoutButton(),
                const SizedBox(height: 6),
                _buildDeleteAccountButton(),
              ] else
                _buildLoginPromptButton(),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFallbackAvatar() {
    return Center(
      child: Icon(
        _avatars[_avatarIndex],
        color: const Color(0xFF0B2A5B),
        size: 50,
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. PROFILE HEADER CARD (Executive VIP Designer Card)
  // ─────────────────────────────────────────────────────────────
  Widget _buildProfileHeaderCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: const Color(0xFFEDE8DF),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFFD49B1A).withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // Top Accent Ribbon
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 4.5,
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF0B2A5B), Color(0xFFD49B1A), Color(0xFF0B2A5B)],
                  ),
                ),
              ),
            ),

            // Card Body Content
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Top Micro Badges Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    textDirection: TextDirection.rtl,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B2A5B).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF0B2A5B).withValues(alpha: 0.10)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: [
                            const Icon(Icons.badge_rounded, color: Color(0xFFD49B1A), size: 14),
                            const SizedBox(width: 5),
                            Text(
                              'بطاقة عضوية رقمية',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0B2A5B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'حساب نشط ومحمي',
                              style: GoogleFonts.cairo(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF059669),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 1. Concentric Glowing Avatar with Executive Camera Badge
                  Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.center,
                      children: [
                        // Soft Outer Glow
                        Container(
                          width: 112,
                          height: 112,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD49B1A).withValues(alpha: 0.20),
                                blurRadius: 18,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        // Double Ring Container
                        GestureDetector(
                          onTap: _showPhotoOptions,
                          onLongPress: () {
                            if ((_photoUrl != null && _photoUrl!.isNotEmpty) ||
                                (_photoBase64 != null && _photoBase64!.isNotEmpty) ||
                                (_photoPath != null && File(_photoPath!).existsSync())) {
                              ProfileDetailsModal.openPhotoViewer(
                                context,
                                name: _userName,
                                photoBase64: _photoBase64,
                                photoUrl: _photoUrl ?? _photoPath,
                                subtitle: _userPhone,
                              );
                            }
                          },
                          child: Container(
                            width: 104,
                            height: 104,
                            padding: const EdgeInsets.all(3.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFF0B2A5B),
                                width: 2.8,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: (!kIsWeb && _photoPath != null && File(_photoPath!).existsSync())
                                  ? Image.file(
                                      File(_photoPath!),
                                      width: 104,
                                      height: 104,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) => _buildFallbackAvatar(),
                                    )
                                  : AppImageUtils.buildAvatarImage(
                                      photoBase64: _photoBase64,
                                      photoUrl: _photoUrl,
                                      width: 104,
                                      height: 104,
                                      fallback: _buildFallbackAvatar(),
                                    ),
                            ),
                          ),
                        ),
                        // Obsidian & Gold Camera Badge
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: GestureDetector(
                            onTap: _showPhotoOptions,
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0B2A5B),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.22),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Color(0xFFD49B1A),
                                size: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 2. Client Name
                  Text(
                    _userName,
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B2A5B),
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_userRole == 'lawyer') ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD49B1A).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD49B1A).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'محامي معتمد بالمنصة',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFB45309),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFFD49B1A),
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 4. Executive Phone Capsule with Copy
                  if (_isLoggedIn)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD49B1A).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.phone_android_rounded,
                                color: Color(0xFFD49B1A),
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isLoggedIn ? PhoneUtils.toLocalDisplay(_userPhone) : _userPhone,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0B2A5B),
                                letterSpacing: 0.5,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _userPhone));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text('تم نسخ رقم الهاتف بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color(0xFF0B2A5B),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: Color(0xFF0B2A5B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Text(
                      _userPhone,
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                      textAlign: TextAlign.center,
                    ),

                  // 4.5. 12-Digit Account ID Capsule with Copy
                  if (_isLoggedIn && _accountId != null && _accountId!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFFD49B1A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.badge_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${AccountIdUtils.formatForDisplay(_accountId!)}',
                              style: GoogleFonts.cairo(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF92400E),
                                letterSpacing: 0.5,
                              ),
                              textDirection: TextDirection.ltr,
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _accountId!));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      textDirection: TextDirection.rtl,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                        const SizedBox(width: 8),
                                        Text('تم نسخ ID الموحد (12 رقم) بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: const Color(0xFF0B2A5B),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD49B1A).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(
                                  Icons.copy_rounded,
                                  size: 14,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // 5. 3-Column Executive Metrics Strip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFEDF2F7), width: 1.0),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        // Column 1: Membership status
                        Expanded(
                          child: _buildMetricCol(
                            icon: Icons.shield_rounded,
                            iconColor: const Color(0xFF10B981),
                            title: 'حالة العضوية',
                            value: _userRole == 'lawyer' ? 'محامي - موثق العقود' : 'حساب نشط',
                            valueColor: const Color(0xFF059669),
                          ),
                        ),
                        Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                        // Column 2: Date
                        Expanded(
                          child: _buildMetricCol(
                            icon: Icons.calendar_month_rounded,
                            iconColor: const Color(0xFFD49B1A),
                            title: 'تاريخ الانضمام',
                            value: _formatDate(_createdAt),
                            valueColor: const Color(0xFF0B2A5B),
                          ),
                        ),
                        Container(width: 1, height: 32, color: const Color(0xFFE2E8F0)),
                        // Column 3: Territory / Coverage
                        Expanded(
                          child: _buildMetricCol(
                            icon: Icons.location_city_rounded,
                            iconColor: const Color(0xFF3B82F6),
                            title: 'نطاق الخدمة',
                            value: 'مدن السودان',
                            valueColor: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0);
  }

  Widget _buildMetricCol({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.cairo(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.cairo(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B2A5B),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          width: 32,
          height: 3,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
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
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFCBD5E1),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return InkWell(
      onTap: _confirmLogout,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2A5B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2A5B).withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
            const SizedBox(width: 8),
            Text(
              'تسجيل الخروج من الحساب',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeleteAccountButton() {
    return InkWell(
      onTap: _confirmDeleteAccount,
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
              'حذف الحساب والبيانات نهائياً',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
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
                  'حذف الحساب نهائياً',
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
                          'تحذير: سيتم حذف حسابك وكافة بياناتك وصورتك الشخصية نهائياً من منصة محاميك، ولا يمكن التراجع عن هذا الإجراء.',
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
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
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
                                final res = await _authService.deleteAccount(
                                  currentPassword: PhoneUtils.convertArabicDigits(passCtrl.text.trim()),
                                );

                                if (!mounted) return;
                                if (res['success'] == true) {
                                  dlgNav.pop();
                                  nav.pushAndRemoveUntil(
                                    MaterialPageRoute(builder: (_) => const AuthGatewayScreen()),
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
    ),
  );
  }

  Widget _buildLoginPromptButton() {
    return ElevatedButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AuthGatewayScreen()),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0B2A5B),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        'تسجيل الدخول / إنشاء حساب جديد',
        style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      style: GoogleFonts.cairo(color: const Color(0xFF0B2A5B), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFD49B1A), size: 20),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: const Color(0xFF94A3B8),
                  size: 20,
                ),
                onPressed: onToggleObscure,
              )
            : null,
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
          borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5),
        ),
      ),
    );
  }
}
