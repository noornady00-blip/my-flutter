import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../network/auth_service.dart';
import '../../network/notification_service.dart';
import '../../core/utils/navigation_utils.dart';
import '../../core/utils/phone_utils.dart';
import 'app_logo_badge.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/auth_gateway_screen.dart';
import 'profile_details_modal.dart';

// ============================================================================
// AppDrawer
// Luxury Navigation Drawer with user session state, avatar preview,
// notification settings trigger, and role-based quick links.
// ============================================================================

class AppDrawer extends StatefulWidget {
  final void Function(int index)? onNavigateTab;
  final VoidCallback? onChangePassword;

  const AppDrawer({
    super.key,
    this.onNavigateTab,
    this.onChangePassword,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  String _userName = 'مستخدم محاميك';
  String _userPhone = 'لا يوجد رقم مسجل';
  String _userRole = 'client';
  String? _photoUrl;
  String? _photoBase64;
  String? _photoPath;
  int _avatarIndex = 0;
  bool _isLoggedIn = false;

  // Cached decoded bytes to avoid re-decoding Base64 on every build
  Uint8List? _cachedAvatarBytes;

  final List<IconData> _avatars = const [
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
    _loadDrawerUserData();
  }

  @override
  void didUpdateWidget(covariant AppDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadDrawerUserData();
  }

  static Uint8List? _safeDecodeBase64(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      String b64 = raw.contains(',') ? raw.split(',').last : raw;
      b64 = b64.trim().replaceAll('\n', '').replaceAll('\r', '').replaceAll(' ', '');
      if (b64.isEmpty) return null;
      return base64Decode(b64);
    } catch (e) {
      debugPrint('AppDrawer safeDecodeBase64 error: $e');
      return null;
    }
  }

  Future<void> _loadDrawerUserData() async {
    final session = await AuthService().getSavedSession();
    final currentUser = FirebaseAuth.instance.currentUser;

    final prefs = await SharedPreferences.getInstance();
    final savedAvatarIdx = prefs.getInt('user_avatar_idx') ?? 0;
    final savedPhotoUrl = prefs.getString('user_profile_photo_url');
    final savedPhoto = prefs.getString('user_profile_photo') ?? prefs.getString('user_profile_photo_base64');
    final savedPhotoPath = prefs.getString('user_profile_photo_path');

    Uint8List? initialBytes;
    if (savedPhoto != null && savedPhoto.isNotEmpty) {
      initialBytes = _safeDecodeBase64(savedPhoto);
    } else if (savedPhotoUrl != null && savedPhotoUrl.startsWith('data:image')) {
      initialBytes = _safeDecodeBase64(savedPhotoUrl);
    }

    if (!mounted) return;

    setState(() {
      _avatarIndex = savedAvatarIdx;
      _photoUrl = savedPhotoUrl;
      _photoBase64 = savedPhoto;
      _photoPath = savedPhotoPath;
      if (initialBytes != null) _cachedAvatarBytes = initialBytes;

      if (session['name'] != null && session['name']!.isNotEmpty) {
        _userName = session['name']!;
        _userPhone = session['phone'] ?? (currentUser?.email ?? '');
        _userRole = session['role'] ?? 'client';
        _isLoggedIn = true;
      } else if (currentUser != null) {
        _userName = currentUser.displayName ?? 'مستخدم محاميك';
        _userPhone = currentUser.email?.replaceAll('@mahameek.client.com', '').replaceAll('@mahameek.lawyer.com', '') ?? '';
        _isLoggedIn = true;
      }
    });

    // Fetch latest user document from Firestore
    final uid = session['uid'] ?? currentUser?.uid;
    if (uid != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
        if (doc.exists && mounted) {
          final cloudName = doc.data()?['name']?.toString();
          final cloudPhone = doc.data()?['phone']?.toString();
          final cloudUrl = doc.data()?['photoUrl']?.toString();
          final cloudBase64 = doc.data()?['photoBase64']?.toString();

          Uint8List? cloudBytes;
          if (cloudBase64 != null && cloudBase64.isNotEmpty) {
            cloudBytes = _safeDecodeBase64(cloudBase64);
          } else if (cloudUrl != null && cloudUrl.startsWith('data:image')) {
            cloudBytes = _safeDecodeBase64(cloudUrl);
          }

          setState(() {
            if (cloudName != null && cloudName.isNotEmpty) _userName = cloudName;
            if (cloudPhone != null && cloudPhone.isNotEmpty) _userPhone = cloudPhone;
            if (cloudUrl != null && cloudUrl.isNotEmpty) _photoUrl = cloudUrl;
            if (cloudBase64 != null && cloudBase64.isNotEmpty) _photoBase64 = cloudBase64;
            if (cloudBytes != null) _cachedAvatarBytes = cloudBytes;
          });
        }
      } catch (_) {}
    }
  }

  Widget _buildAvatar() {
    // 1. Check local file on device (fastest, zero network delay) — not supported on web
    if (!kIsWeb && _photoPath != null && _photoPath!.trim().isNotEmpty) {
      try {
        final file = File(_photoPath!.trim());
        if (file.existsSync()) {
          return Image.file(
            file,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => _buildAvatarFromBytesOrNetwork(),
          );
        }
      } catch (_) {}
    }

    return _buildAvatarFromBytesOrNetwork();
  }

  Widget _buildAvatarFromBytesOrNetwork() {
    // 2. Pre-cached decoded memory bytes
    if (_cachedAvatarBytes != null && _cachedAvatarBytes!.isNotEmpty) {
      return Image.memory(
        _cachedAvatarBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildAvatarFromUrlOrFallback(),
      );
    }

    // 3. Fallback synchronous decode of Base64 strings
    final rawBase64 = (_photoBase64 != null && _photoBase64!.trim().isNotEmpty)
        ? _photoBase64
        : ((_photoUrl != null && _photoUrl!.startsWith('data:image'))
            ? _photoUrl
            : null);

    if (rawBase64 != null) {
      final bytes = _safeDecodeBase64(rawBase64);
      if (bytes != null && bytes.isNotEmpty) {
        _cachedAvatarBytes = bytes;
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildAvatarFromUrlOrFallback(),
        );
      }
    }

    return _buildAvatarFromUrlOrFallback();
  }

  Widget _buildAvatarFromUrlOrFallback() {
    // 4. Remote network URL (HTTP/HTTPS)
    if (_photoUrl != null && _photoUrl!.trim().isNotEmpty && _photoUrl!.trim().startsWith('http')) {
      return Image.network(
        _photoUrl!.trim(),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _fallbackAvatar(),
      );
    }

    // 5. Fallback avatar
    return _fallbackAvatar();
  }

  Widget _fallbackAvatar() {
    final icon = (_avatarIndex >= 0 && _avatarIndex < _avatars.length)
        ? _avatars[_avatarIndex]
        : Icons.person_rounded;
    return Container(
      color: const Color(0xFFFFFBEB),
      child: Center(
        child: Icon(
          icon,
          color: const Color(0xFF0B2A5B),
          size: 30,
        ),
      ),
    );
  }

  void _confirmSignOut() {
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

  void _openChangePassword() {
    Navigator.pop(context);
    if (widget.onChangePassword != null) {
      widget.onChangePassword!();
      return;
    }
    _showDefaultChangePasswordSheet();
  }

  void _showDefaultChangePasswordSheet() {
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
        builder: (modalCtx, setModalState) => Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD49B1A).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFD49B1A), size: 24),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'تغيير كلمة المرور',
                    style: GoogleFonts.cairo(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF0B2A5B)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (error != null)
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(error!, style: GoogleFonts.cairo(color: Colors.red.shade800, fontSize: 13)),
                ),
              TextField(
                controller: oldPassCtrl,
                obscureText: obscureOld,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الحالية',
                  labelStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFD49B1A)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: () => setModalState(() => obscureOld = !obscureOld),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPassCtrl,
                obscureText: obscureNew,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'كلمة المرور الجديدة (6 أحرف على الأقل)',
                  labelStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFD49B1A)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: () => setModalState(() => obscureNew = !obscureNew),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPassCtrl,
                obscureText: obscureConfirm,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                style: GoogleFonts.cairo(fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة المرور الجديدة',
                  labelStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                  prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFD49B1A)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: const Color(0xFF94A3B8),
                      size: 20,
                    ),
                    onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: loading
                    ? null
                    : () async {
                        final oldP = PhoneUtils.convertArabicDigits(oldPassCtrl.text.trim());
                        final newP = PhoneUtils.convertArabicDigits(newPassCtrl.text.trim());
                        final confP = PhoneUtils.convertArabicDigits(confirmPassCtrl.text.trim());

                        if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
                          setModalState(() => error = 'يرجى تعبئة كافة الحقول المطلوبة');
                          return;
                        }
                        if (newP.length < 6) {
                          setModalState(() => error = 'كلمة المرور الجديدة يجب ألا تقل عن 6 أحرف');
                          return;
                        }
                        if (newP != confP) {
                          setModalState(() => error = 'كلمتا المرور غير متطابقتين');
                          return;
                        }

                        setModalState(() {
                          loading = true;
                          error = null;
                        });

                        Map<String, dynamic> res;
                        try {
                          res = await AuthService().reauthenticateAndChangePassword(
                            currentPassword: oldP,
                            newPassword: newP,
                          );
                        } catch (e) {
                          res = {'success': false, 'error': 'حدث خطأ غير متوقع، يرجى المحاولة مجدداً'};
                        }

                        // Always reset loading first, then check mounted
                        setModalState(() {
                          loading = false;
                          if (res['success'] != true) {
                            error = res['error']?.toString() ?? 'تعذر تغيير كلمة المرور';
                          }
                        });

                        if (res['success'] == true) {
                          if (modalCtx.mounted) Navigator.pop(modalCtx);
                          if (!mounted) return;
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم تغيير كلمة المرور بنجاح!', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0B2A5B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text('حفظ كلمة المرور الجديدة', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotificationSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
              textDirection: TextDirection.rtl,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B2A5B).withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_active_rounded, color: Color(0xFF0B2A5B), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'إعدادات وتفعيل الإشعارات',
                        style: GoogleFonts.cairo(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B2A5B),
                        ),
                      ),
                      Text(
                        'التحكم في التنبيهات الفورية والإشعارات المنبثقة',
                        style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(sheetCtx);
                final user = FirebaseAuth.instance.currentUser;
                await NotificationService().enableAllNotifications(adminUid: user?.uid);
                NotificationService().showNotificationDirect(
                  title: 'تم تفعيل وتحديث الإشعارات',
                  body: 'التطبيق مهيأ الآن لاستقبال التنبيهات والطلبات الفورية بنجاح.',
                  payload: 'admin_test',
                  id: DateTime.now().millisecondsSinceEpoch % 100000,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('تم تفعيل كافة قنوات الإشعارات بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                      backgroundColor: const Color(0xFF10B981),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.check_circle_rounded, size: 18),
              label: Text('تفعيل وتحديث الإشعارات الفورية', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13.5)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B2A5B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetCtx);
                NotificationService.openAutoStartSettings();
              },
              icon: const Icon(Icons.bolt_rounded, size: 18, color: Color(0xFFD97706)),
              label: Text('إعداد التشغيل التلقائي والبطارية (شاومي / ريدمي / سامسونج)', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0B2A5B))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(sheetCtx);
                NotificationService.openNotificationSettings();
              },
              icon: const Icon(Icons.settings_suggest_rounded, size: 18, color: Color(0xFF0B2A5B)),
              label: Text('فتح إعدادات قنوات النظام (تنبيهات منبثقة)', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13, color: const Color(0xFF0B2A5B))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: Color(0xFFCBD5E1)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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

                                final res = await AuthService().deleteAccount(
                                  currentPassword: PhoneUtils.convertArabicDigits(passCtrl.text.trim()),
                                );

                                if (!mounted) return;
                                if (res['success'] == true) {
                                  if (ctx.mounted) {
                                    Navigator.of(ctx).pop();
                                  }
                                  if (context.mounted) {
                                    NavigationUtils.smoothSignOut(context);
                                  }
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

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    bool isLogout = false,
    bool isDelete = false,
  }) {
    if (isLogout) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0B2A5B),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFEF4444),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (isDelete) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFCA5A5).withValues(alpha: 0.7),
                  width: 1.2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.delete_forever_rounded,
                      color: Color(0xFFDC2626),
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFFDC2626),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final itemColor = color ?? const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD49B1A).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFFD97706),
                    size: 19,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: itemColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Drawer(
        backgroundColor: Colors.white,
        child: Column(
          children: [
            // ─────────────────────────────────────────────────────────────
            // 1. LUXURY DRAWER HEADER (Logo + Avatar + Name + Phone)
            // ─────────────────────────────────────────────────────────────
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                20,
                MediaQuery.of(context).padding.top + 16,
                20,
                20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF070D1F), Color(0xFF142147)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top: Official Mahameek Badge
                  const AppLogoBadge(
                    height: 36,
                    withPillBackground: true,
                  ),
                  const SizedBox(height: 18),

                  // Client Identity Row: Avatar + (Name & Phone)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Avatar with Dark Ring - LongPress = view photo, Tap = profile
                      GestureDetector(
                        onTap: () {
                          if (widget.onNavigateTab != null && _isLoggedIn) {
                            Navigator.of(context).pop();
                            widget.onNavigateTab!(_userRole == 'lawyer' ? 2 : 3);
                          }
                        },
                        onLongPress: () {
                          if ((_photoBase64 != null && _photoBase64!.isNotEmpty) ||
                              (_photoUrl != null && _photoUrl!.isNotEmpty) ||
                              (_photoPath != null && _photoPath!.isNotEmpty)) {
                            ProfileDetailsModal.openPhotoViewer(
                              context,
                              name: _userName,
                              photoBase64: _photoBase64,
                              photoUrl: _photoUrl ?? _photoPath,
                              subtitle: _userPhone,
                            );
                          }
                        },
                        child: RepaintBoundary(
                          child: Container(
                            width: 58,
                            height: 58,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFF0B2A5B),
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.30),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: _buildAvatar(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),

                      // Name & Phone Number Under Name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    _userName,
                                    style: GoogleFonts.cairo(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      height: 1.25,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isLoggedIn && (_userRole == 'lawyer' || _userRole == 'admin')) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFFD49B1A),
                                    size: 16,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 5),

                            // Phone Number Under Name
                            if (_userPhone.isNotEmpty)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD49B1A).withValues(alpha: 0.20),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.phone_android_rounded,
                                      size: 11,
                                      color: Color(0xFFD49B1A),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _userPhone,
                                    style: GoogleFonts.cairo(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFCBD5E1),
                                      letterSpacing: 0.5,
                                    ),
                                    textDirection: TextDirection.ltr,
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ─────────────────────────────────────────────────────────────
            // 2. DYNAMIC MENU ITEMS
            // ─────────────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 10),
                children: [
                  // 1. CLIENT MENU
                  if (_isLoggedIn && _userRole == 'client') ...[
                    _buildDrawerItem(
                      icon: Icons.home_rounded,
                      title: 'الرئيسية والمدن',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(0);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.chat_bubble_rounded,
                      title: 'المحادثات المباشرة',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(1);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.search_rounded,
                      title: 'البحث',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(2);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.person_rounded,
                      title: 'حسابي',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(3);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.lock_reset_rounded,
                      title: 'تغيير كلمة المرور',
                      onTap: _openChangePassword,
                    ),
                    const Divider(indent: 20, endIndent: 20),
                    _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'تسجيل خروج',
                      isLogout: true,
                      onTap: _confirmSignOut,
                    ),
                    const SizedBox(height: 6),
                    _buildDrawerItem(
                      icon: Icons.delete_forever_rounded,
                      title: 'حذف الحساب نهائياً',
                      isDelete: true,
                      onTap: _confirmDeleteAccount,
                    ),
                  ]
                  // 2. LAWYER MENU
                  else if (_isLoggedIn && _userRole == 'lawyer') ...[
                    _buildDrawerItem(
                      icon: Icons.badge_rounded,
                      title: 'الرئيسية (بياناتي)',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(0);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.chat_bubble_rounded,
                      title: 'المحادثات المباشرة',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(1);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.tune_rounded,
                      title: 'الإعدادات وحسابي',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(2);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.lock_reset_rounded,
                      title: 'تغيير كلمة المرور',
                      onTap: _openChangePassword,
                    ),
                    const Divider(indent: 20, endIndent: 20),
                    _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'تسجيل خروج',
                      isLogout: true,
                      onTap: _confirmSignOut,
                    ),
                    const SizedBox(height: 6),
                    _buildDrawerItem(
                      icon: Icons.delete_forever_rounded,
                      title: 'حذف الحساب المهني نهائياً',
                      isDelete: true,
                      onTap: _confirmDeleteAccount,
                    ),
                  ]
                  // 3. ADMIN MENU
                  else if (_isLoggedIn && _userRole == 'admin') ...[
                    _buildDrawerItem(
                      icon: Icons.dashboard_rounded,
                      title: 'لوحة المؤشرات العامة',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminDashboard()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.notifications_active_rounded,
                      title: 'إعدادات الإشعارات والتنبيهات',
                      onTap: () {
                        Navigator.pop(context);
                        _showNotificationSettingsSheet();
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.lock_reset_rounded,
                      title: 'تغيير كلمة المرور',
                      onTap: _openChangePassword,
                    ),
                    const Divider(indent: 20, endIndent: 20),
                    _buildDrawerItem(
                      icon: Icons.logout_rounded,
                      title: 'تسجيل خروج',
                      isLogout: true,
                      onTap: _confirmSignOut,
                    ),
                  ]
                  // 4. GUEST / NOT LOGGED IN
                  else ...[
                    _buildDrawerItem(
                      icon: Icons.home_rounded,
                      title: 'الرئيسية والمدن',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(0);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.chat_bubble_rounded,
                      title: 'المحادثات المباشرة',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(1);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.search_rounded,
                      title: 'البحث',
                      onTap: () {
                        Navigator.pop(context);
                        widget.onNavigateTab?.call(2);
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.login_rounded,
                      title: 'تسجيل الدخول',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                    ),
                    _buildDrawerItem(
                      icon: Icons.person_add_rounded,
                      title: 'إنشاء حساب جديد',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AuthGatewayScreen()),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
