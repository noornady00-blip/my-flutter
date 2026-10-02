// ==============================================================================
// 🚫 GLOBAL ACCOUNT STATUS BARRIER
// ==============================================================================
// Listens in real-time to the authenticated user's account status in Firestore.
// When an admin suspends the account, a full-screen, non-dismissible barrier
// immediately appears informing the user that the account is suspended and
// allowing them to contact administration directly via WhatsApp.
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
import '../../core/utils/navigation_utils.dart';

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
      await NavigationUtils.smoothSignOut(context);
    } catch (e) {
      debugPrint('[SuspendedAccountView] logout error: $e');
    } finally {
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
                          'إذا كنت تعتقد أن هذا الإجراء تم بالخطأ أو ترغب في استئناف نشاطك، يرجى التواصل مباشرة مع إدارة المنصة عبر واتساب لمراجعة الحساب وتفعيله.',
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

                  // 4. Primary Button: WhatsApp Direct Chat
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _openWhatsApp,
                      icon: const Icon(Icons.chat_bubble_outline_rounded,
                          color: Colors.white, size: 22),
                      label: Text(
                        'تواصل مباشرة عبر واتساب',
                        style: GoogleFonts.cairo(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 3,
                        shadowColor: const Color(0xFF25D366).withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(delay: 350.ms),

                  const SizedBox(height: 14),

                  // 5. Secondary Button: Logout
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
                  ).animate().fadeIn(delay: 450.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
