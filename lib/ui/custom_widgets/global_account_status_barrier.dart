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
import '../screens/onboarding/onboarding_screen.dart';
import '../../network/notification_service.dart';
import '../../network/firestore_service.dart';
import 'account_suspended_dialog.dart';

class GlobalAccountStatusBarrier extends StatefulWidget {
  final Widget child;
  const GlobalAccountStatusBarrier({super.key, required this.child});

  @override
  State<GlobalAccountStatusBarrier> createState() =>
      _GlobalAccountStatusBarrierState();
}

class _GlobalAccountStatusBarrierState
    extends State<GlobalAccountStatusBarrier>
    with WidgetsBindingObserver {
  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _roleDocSub;

  bool _isSuspended = false;
  bool _isLoggingOut = false;
  String _currentUid = '';
  String _userName = '';
  String _userPhone = '';
  String _userRole = 'client';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listenToAuth();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSub?.cancel();
    _cancelDocSubscriptions();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_currentUid.isNotEmpty && !_isLoggingOut) {
        _checkIfAccountDeleted(_currentUid);
      }
    }
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

  Future<void> _checkIfAccountDeleted(String uid) async {
    if (uid.isEmpty || _isLoggingOut) return;
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      final email = currentUser?.email?.toLowerCase() ?? '';
      if (email.endsWith('@mahameek.admin.com') || email.startsWith('admin_')) {
        return; // Admins are never deleted by this barrier
      }

      final prefs = await SharedPreferences.getInstance();
      final role = prefs.getString('role')?.toLowerCase().trim();
      if (role == 'admin' || role == 'subadmin') {
        return; // Admins are never deleted by this barrier
      }

      // Small debounce (350ms) to ensure ongoing auth or batch creation completes
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted || _isLoggingOut) return;

      // 1. Check if Firebase Auth account was deleted
      if (currentUser != null) {
        try {
          await currentUser.reload().timeout(const Duration(seconds: 3));
        } on FirebaseAuthException catch (authErr) {
          if (authErr.code == 'user-not-found' || authErr.code == 'user-disabled') {
            debugPrint('⚠️ [Barrier] Firebase Auth user deleted: ${authErr.code}');
            await _performAccountDeletionSignOut(uid);
            return;
          }
        } catch (_) {}
      }

      // 2. Query Firestore collections
      final db = FirebaseFirestore.instance;
      bool userDocFound = false;
      bool lawyerDocFound = false;
      bool adminDocFound = false;
      bool permissionDenied = false;

      try {
        final uDoc = await db
            .collection('users')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 3));
        if (uDoc.exists) userDocFound = true;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') permissionDenied = true;
      } catch (_) {}

      try {
        final lDoc = await db
            .collection('lawyers')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 3));
        if (lDoc.exists) lawyerDocFound = true;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') permissionDenied = true;
      } catch (_) {}

      try {
        final aDoc = await db
            .collection('admins')
            .doc(uid)
            .get()
            .timeout(const Duration(seconds: 2));
        if (aDoc.exists) adminDocFound = true;
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') permissionDenied = true;
      } catch (_) {}

      if (userDocFound || lawyerDocFound || adminDocFound) {
        return; // Account still exists!
      }

      // If none exist or access was denied due to deleted account -> Sign out
      debugPrint(
          '🚫 [Barrier] Account deleted in Firebase for UID: $uid (permDenied=$permissionDenied)');
      await _performAccountDeletionSignOut(uid);
    } catch (e) {
      debugPrint('[GlobalAccountStatusBarrier] check deletion error: $e');
    }
  }

  Future<void> _performAccountDeletionSignOut(String uid) async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;
    _cancelDocSubscriptions();

    final uidToClean = uid.isNotEmpty ? uid : _currentUid;

    try {
      // 1. Stop chat listeners and unregister device tokens
      NotificationService().stopGlobalUserChatListener();
      if (uidToClean.isNotEmpty) {
        await NotificationService()
            .unregisterUserDevice(uid: uidToClean)
            .timeout(const Duration(seconds: 3));
      }
      await NotificationService().clearAllSystemNotifications();
    } catch (e) {
      debugPrint('[Barrier] notification cleanup notice: $e');
    }

    // 2. Clear in-memory cache
    FirestoreService.inMemoryApprovedLawyers = null;

    // 3. Clear SharedPreferences completely
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      debugPrint('[Barrier] prefs clear notice: $e');
    }

    // 4. Delete local Firebase Auth user & sign out
    try {
      await FirebaseAuth.instance.currentUser?.delete();
    } catch (_) {}
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _isSuspended = false;
        _currentUid = '';
      });
    }

    // 5. Navigate cleanly to OnboardingScreen (removes all previous screens)
    final nav = NotificationService.navigatorKey.currentState;
    if (nav != null) {
      nav.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (_) => false,
      );
    }

    // 6. Show informative Dialog to user
    final ctx = NotificationService.navigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      showAccountDeletedDialog(ctx);
    }

    _isLoggingOut = false;
  }

  Future<void> _subscribeToUserStatus(String uid) async {
    _cancelDocSubscriptions();

    final currentUser = FirebaseAuth.instance.currentUser;
    final email = currentUser?.email?.toLowerCase() ?? '';
    final bool isAdminEmail =
        email.endsWith('@mahameek.admin.com') || email.startsWith('admin_');

    // Read cached session first
    try {
      final prefs = await SharedPreferences.getInstance();
      _userRole = prefs.getString('role')?.toLowerCase().trim() ?? 'client';
      _userName = prefs.getString('name') ?? '';
      _userPhone = prefs.getString('phone') ?? '';
      final cachedStatus = prefs.getString('status')?.toLowerCase().trim();
      if (cachedStatus == 'suspended') {
        if (mounted) setState(() => _isSuspended = true);
      }
    } catch (_) {}

    if (email.contains('@mahameek.lawyer.com')) {
      _userRole = 'lawyer';
    }

    // Admins and subadmins are never monitored for client account suspension
    if (_userRole == 'admin' || _userRole == 'subadmin' || isAdminEmail) {
      if (mounted && _isSuspended) {
        setState(() => _isSuspended = false);
      }
      return;
    }

    final db = FirebaseFirestore.instance;

    if (_userRole == 'lawyer') {
      // 1. For Lawyers: Listen to lawyers/{uid} as PRIMARY
      _roleDocSub =
          db.collection('lawyers').doc(uid).snapshots().listen((rSnap) {
        if (!rSnap.exists) {
          // Lawyer document deleted!
          _checkIfAccountDeleted(uid);
          return;
        }
        final rData = rSnap.data() ?? {};
        final rStatus =
            rData['status']?.toString().toLowerCase().trim() ?? '';
        final rName = rData['name']?.toString() ?? _userName;
        final rPhone = rData['phone']?.toString() ?? _userPhone;

        _userName = rName;
        _userPhone = rPhone;

        final bool suspended = (rStatus == 'suspended');
        _updateSuspendedState(suspended, rStatus);
      }, onError: (err) {
        debugPrint(
            '[GlobalAccountStatusBarrier] lawyer roleDocSub error: $err');
        if (err is FirebaseException &&
            (err.code == 'permission-denied' || err.code == 'not-found')) {
          _checkIfAccountDeleted(uid);
        }
      });

      // Also listen to users/{uid} for mirror suspension updates if present
      _userDocSub =
          db.collection('users').doc(uid).snapshots().listen((snap) {
        if (snap.exists) {
          final data = snap.data() ?? {};
          final status =
              data['status']?.toString().toLowerCase().trim() ?? '';
          if (status == 'suspended') {
            _updateSuspendedState(true, 'suspended');
          }
        }
      }, onError: (_) {});
    } else {
      // 2. For Clients: Listen to users/{uid} as PRIMARY
      _userDocSub =
          db.collection('users').doc(uid).snapshots().listen((snap) {
        if (!snap.exists) {
          // Client document deleted!
          _checkIfAccountDeleted(uid);
          return;
        }
        final data = snap.data() ?? {};
        final role =
            data['role']?.toString().toLowerCase().trim() ?? _userRole;
        final name = data['name']?.toString() ?? _userName;
        final phone = data['phone']?.toString() ?? _userPhone;
        final status =
            data['status']?.toString().toLowerCase().trim() ?? '';

        _userName = name;
        _userPhone = phone;
        _userRole = role;

        // If the user's role is actually lawyer, re-subscribe as lawyer
        if (role == 'lawyer') {
          _subscribeToUserStatus(uid);
          return;
        }

        final bool suspended = (status == 'suspended');
        _updateSuspendedState(suspended, status);
      }, onError: (err) {
        debugPrint(
            '[GlobalAccountStatusBarrier] client userDocSub error: $err');
        if (err is FirebaseException &&
            (err.code == 'permission-denied' || err.code == 'not-found')) {
          _checkIfAccountDeleted(uid);
        }
      });
    }
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
