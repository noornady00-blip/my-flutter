// ==============================================================================
// 🚫 GLOBAL ACCOUNT STATUS BARRIER
// ==============================================================================
// Listens in real-time to the authenticated user's account status in Firestore.
// When an admin suspends the account, a full-screen, non-dismissible banner
// immediately appears informing the user that the account is suspended and
// allowing them to send a message to administration or contact via WhatsApp.
// When the admin reactivates the account, the barrier instantly dismisses and
// returns the app to normal state seamlessly.
// ==============================================================================

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/phone_utils.dart';
import '../../network/auth_service.dart';
import '../../network/notification_service.dart';
import '../screens/onboarding/onboarding_screen.dart';

class GlobalAccountStatusBarrier extends StatefulWidget {
  final Widget child;
  const GlobalAccountStatusBarrier({super.key, required this.child});

  @override
  State<GlobalAccountStatusBarrier> createState() =>
      _GlobalAccountStatusBarrierState();
}

class _GlobalAccountStatusBarrierState
    extends State<GlobalAccountStatusBarrier> {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleDocSub;

  bool _isSuspended = false;
  String _currentUid = '';
  String _userName = '';
  String _userPhone = '';
  String _userRole = 'client';

  @override
  void initState() {
    super.initState();
    _listenToAuth();
  }

  void _listenToAuth() {
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        _cancelDocSubscriptions();
        if (mounted && _isSuspended) {
          setState(() {
            _isSuspended = false;
            _currentUid = '';
          });
        }
      } else {
        if (_currentUid != user.uid) {
          _currentUid = user.uid;
          _subscribeToUserStatus(user.uid);
        }
      }
    });
  }

  void _cancelDocSubscriptions() {
    _userDocSub?.cancel();
    _userDocSub = null;
    _roleDocSub?.cancel();
    _roleDocSub = null;
  }

  Future<void> _subscribeToUserStatus(String uid) async {
    _cancelDocSubscriptions();

    // Read cached session first
    try {
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('role') ?? 'client';
      _userName = prefs.getString('name') ?? '';
      _userPhone = prefs.getString('phone') ?? '';
      final cachedStatus = prefs.getString('status')?.toLowerCase().trim();
      if (cachedStatus == 'suspended') {
        if (mounted) setState(() => _isSuspended = true);
      }
    } catch (_) {}

    final db = FirebaseFirestore.instance;

    // 1. Listen to users/{uid} in real time
    _userDocSub = db.collection('users').doc(uid).snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final role = data['role']?.toString().toLowerCase().trim() ?? _userRole;
      final name = data['name']?.toString() ?? _userName;
      final phone = data['phone']?.toString() ?? _userPhone;
      final status = data['status']?.toString().toLowerCase().trim() ?? '';

      _userName = name;
      _userPhone = phone;
      _userRole = role;

      final bool suspended = (status == 'suspended');
      _updateSuspendedState(suspended, status);

      // If user is a lawyer or admin, also listen to the dedicated collection
      if (_roleDocSub == null && (role == 'lawyer' || role == 'admin' || role == 'subadmin')) {
        final collectionName = (role == 'lawyer') ? 'lawyers' : 'admins';
        _roleDocSub = db.collection(collectionName).doc(uid).snapshots().listen((rSnap) {
          if (!rSnap.exists) return;
          final rData = rSnap.data() ?? {};
          final rStatus = rData['status']?.toString().toLowerCase().trim() ?? '';
          if (rStatus == 'suspended') {
            _updateSuspendedState(true, 'suspended');
          } else if (rStatus == 'active' || rStatus == 'approved') {
            // If primary status is also not suspended, mark active
            if (status != 'suspended') {
              _updateSuspendedState(false, rStatus);
            }
          }
        });
      }
    }, onError: (err) {
      debugPrint('[GlobalAccountStatusBarrier] userDocSub error: $err');
    });
  }

  void _updateSuspendedState(bool suspended, String rawStatus) {
    if (!mounted) return;
    if (_isSuspended != suspended) {
      setState(() {
        _isSuspended = suspended;
      });
      // Synchronize SharedPreferences
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('status', suspended ? 'suspended' : rawStatus);
      }).catchError((_) {});
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cancelDocSubscriptions();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_isSuspended)
          Positioned.fill(
            child: SuspendedAccountFullScreenView(
              userUid: _currentUid,
              userName: _userName,
              userPhone: _userPhone,
              userRole: _userRole,
            ),
          ),
      ],
    );
  }
}

/// Full screen overlay view displayed when an account is suspended.
class SuspendedAccountFullScreenView extends StatefulWidget {
  final String userUid;
  final String userName;
  final String userPhone;
  final String userRole;

  const SuspendedAccountFullScreenView({
    super.key,
    required this.userUid,
    required this.userName,
    required this.userPhone,
    required this.userRole,
  });

  @override
  State<SuspendedAccountFullScreenView> createState() =>
      _SuspendedAccountFullScreenViewState();
}

class _SuspendedAccountFullScreenViewState
    extends State<SuspendedAccountFullScreenView> {
  bool _isLoggingOut = false;

  Future<void> _handleLogout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await AuthService().logout();
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
          (route) => false,
        );
      }
    } catch (_) {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Future<void> _openWhatsApp() async {
    const adminPhone = AppConstants.secondaryAdminPhoneClean;
    final msg = Uri.encodeComponent(
      'السلام عليكم إدارة منصة محاميك، أود الاستفسار بخصوص إيقاف حسابي (الاسم: ${widget.userName.isNotEmpty ? widget.userName : "المستخدم"} - الهاتف: ${widget.userPhone}) وطلب مراجعته وإعادة تفعيله.',
    );
    final url = Uri.parse('https://wa.me/$adminPhone?text=$msg');
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _openMessageModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SupportMessageComposerSheet(
        userUid: widget.userUid,
        userName: widget.userName,
        userPhone: widget.userPhone,
        userRole: widget.userRole,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // 1. Glowing Suspended Badge Icon
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFDA4AF), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE11D48).withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.lock_person_rounded,
                        color: Color(0xFFE11D48),
                        size: 52,
                      ),
                    ),
                  ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),

                  const SizedBox(height: 24),

                  // 2. Title
                  Text(
                    'الحساب متوقف مؤقتاً',
                    style: GoogleFonts.cairo(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF0B2A5B),
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 12),

                  // 3. Informational Container Box
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 12,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'نحيطكم علماً بأنه قد تم إيقاف تنشيط هذا الحساب من قِبل إدارة منصة محاميك.',
                          style: GoogleFonts.cairo(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E293B),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'إذا كنت تعتقد أن هذا الإجراء تم بالخطأ أو ترغب في استئناف نشاطك، يرجى إرسال رسالة مباشرة لإدارة المنصة لمراجعة الحساب وتفعيله فوراً.',
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF64748B),
                            height: 1.6,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.08, end: 0),

                  const SizedBox(height: 28),

                  // 4. Primary Button: Send Message to Admin
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openMessageModal,
                      icon: const Icon(Icons.send_rounded, size: 20),
                      label: Text(
                        'إرسال رسالة للإدارة',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B2A5B),
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: const Color(0xFF0B2A5B).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 12),

                  // 5. Secondary Button: WhatsApp Direct Chat
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF25D366), size: 20),
                      label: Text(
                        'تواصل مباشرة عبر واتساب',
                        style: GoogleFonts.cairo(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF15803D),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF0FDF4),
                        side: const BorderSide(color: Color(0xFF86EFAC), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 450.ms),

                  const SizedBox(height: 16),

                  // 6. Tertiary Button: Logout
                  TextButton.icon(
                    onPressed: _isLoggingOut ? null : _handleLogout,
                    icon: _isLoggingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF94A3B8)),
                    label: Text(
                      'تسجيل الخروج',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ).animate().fadeIn(delay: 550.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Message composer modal bottom sheet
class _SupportMessageComposerSheet extends StatefulWidget {
  final String userUid;
  final String userName;
  final String userPhone;
  final String userRole;

  const _SupportMessageComposerSheet({
    required this.userUid,
    required this.userName,
    required this.userPhone,
    required this.userRole,
  });

  @override
  State<_SupportMessageComposerSheet> createState() =>
      _SupportMessageComposerSheetState();
}

class _SupportMessageComposerSheetState
    extends State<_SupportMessageComposerSheet> {
  final _msgCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _isSending = false;
  bool _sentSuccess = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.userName;
    _phoneCtrl.text = PhoneUtils.toLocalDisplay(widget.userPhone);
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _phoneCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitMessage() async {
    final msg = _msgCtrl.text.trim();
    if (msg.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('يرجى كتابة رسالتك للإدارة', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    try {
      final name = _nameCtrl.text.trim().isNotEmpty
          ? _nameCtrl.text.trim()
          : (widget.userName.isNotEmpty ? widget.userName : 'مستخدم التطبيق');
      final phone = _phoneCtrl.text.trim().isNotEmpty
          ? PhoneUtils.normalize(_phoneCtrl.text.trim())
          : widget.userPhone;

      await FirebaseFirestore.instance.collection('support_messages').add({
        'name': name,
        'phone': phone,
        'message': msg,
        'type': 'account_suspension_appeal',
        'status': 'unread',
        'role': widget.userRole,
        'senderUid': widget.userUid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send alert to admins
      try {
        await NotificationService().dispatchAdminAlert(
          type: 'support_message',
          title: 'طلب تنشيط حساب موقوف',
          body: 'المرسل: $name ($phone)\n$msg',
          data: {
            'phone': phone,
            'name': name,
            'senderUid': widget.userUid,
            'role': widget.userRole,
          },
        );
      } catch (_) {}

      if (mounted) {
        setState(() {
          _isSending = false;
          _sentSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل إرسال الرسالة: $e', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(22, 20, 22, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle pill
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.mail_outline_rounded,
                        color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'رسالة إلى إدارة منصة محاميك',
                    style: GoogleFonts.cairo(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (_sentSuccess) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF6EE7B7)),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: Color(0xFF10B981), size: 48),
                      const SizedBox(height: 10),
                      Text(
                        'تم استلام رسالتك بنجاح!',
                        style: GoogleFonts.cairo(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'تم إرسال رسالتك مباشرة إلى المشرفين، وسيتم مراجعة الحساب والتواصل معك في أقرب وقت.',
                        style: GoogleFonts.cairo(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF047857),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'إغلاق',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Message textfield
                Text(
                  'تفاصيل الرسالة أو الاستفسار:',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 4,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF1E293B)),
                  decoration: InputDecoration(
                    hintText: 'اكتب رسالتك للإدارة هنا توضح فيها سبب طلب إعادة التفعيل...',
                    hintStyle: GoogleFonts.cairo(
                      fontSize: 13,
                      color: const Color(0xFF94A3B8),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
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
                      borderSide: const BorderSide(color: Color(0xFF0B2A5B), width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Submit Button
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _submitMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2A5B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.send_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'إرسال الرسالة الآن',
                                style: GoogleFonts.cairo(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
