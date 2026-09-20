import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/lawyer.dart';
import '../../../data/models/user_model.dart';
import '../../../network/firestore_service.dart';
import '../../../network/auth_service.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/floating_nav_bar.dart';
import '../../custom_widgets/profile_details_modal.dart';
import '../../custom_widgets/glass_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/services.dart';
import '../../../data/models/password_reset_model.dart';
import '../../../data/models/admin_notification_model.dart';
import '../../../network/notification_service.dart';
import '../auth/login_screen.dart';
import 'admin_support_messages_screen.dart';
import 'admin_pending_lawyers_screen.dart';
import 'admin_password_resets_screen.dart';
import 'admin_recent_lawyers_screen.dart';
import '../../../core/utils/search_utils.dart';
import '../../../core/utils/navigation_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../custom_widgets/sudan_phone_field.dart';
import '../../custom_widgets/app_dialog.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();

  bool _isCheckingAuth = true;
  bool _isAdminVerified = false;
  String _currentAdminEmail = '';
  String _currentAdminPhone = '';

  String get _displayAdminPhone {
    if (_currentAdminPhone.isNotEmpty) return _currentAdminPhone;
    if (_currentAdminEmail.isNotEmpty) {
      final clean = _currentAdminEmail
          .replaceAll('@mahameek.admin.com', '')
          .replaceAll('@mahameek.client.com', '')
          .replaceAll('@mahameek.lawyer.com', '');
      if (clean.isNotEmpty) return clean;
    }
    return '01146979833';
  }

  StreamSubscription? _supportMessagesSub;
  StreamSubscription? _passwordResetsSub;
  StreamSubscription? _pendingLawyersSub;

  final TextEditingController _adminNameCtrl = TextEditingController();
  final TextEditingController _adminPhoneCtrl = TextEditingController();
  final TextEditingController _adminPassCtrl = TextEditingController();
  bool _isCreatingAdmin = false;
  bool _obscureCreateAdminPass = true;

  // 1. تبويب حسابات (Accounts Tab)
  int _accountsTabCategory = 0; // 0: المحامين, 1: المستخدمين
  String _accountsSearchQuery = '';
  String _accountsStatusFilter = 'all'; // 'all', 'active', 'suspended'
  final TextEditingController _accountsSearchCtrl = TextEditingController();

  // 2. تبويب المستخدمين (Directory & Ledger Tab)
  int _directoryTabCategory = 0; // 0: محامين, 1: مستخدمين
  String _directorySearchQuery = '';
  final TextEditingController _directorySearchCtrl = TextEditingController();

  // 3. التمرير في التبويب الرئيسي
  final ScrollController _overviewScrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _accountsSearchCtrl.addListener(() {
      setState(() => _accountsSearchQuery = _accountsSearchCtrl.text.trim().toLowerCase());
    });
    _directorySearchCtrl.addListener(() {
      setState(() => _directorySearchQuery = _directorySearchCtrl.text.trim().toLowerCase());
    });
    _verifyAdminAccess();
  }

  bool _isLoggingOut = false;

  void _startAdminRealtimeListeners() {
    if (_isLoggingOut) return;
    _startSupportMessagesListener();
    _startPasswordResetsListener();
    _startPendingLawyersListener();
  }

  void _startSupportMessagesListener() {
    _supportMessagesSub?.cancel();
    if (_isLoggingOut) return;
    bool isInitialSnapshot = true;
    _supportMessagesSub = FirebaseFirestore.instance
        .collection('support_messages')
        .where('status', isEqualTo: 'unread')
        .snapshots()
        .listen((snap) {
      if (_isLoggingOut || isInitialSnapshot) {
        isInitialSnapshot = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final name = data?['name']?.toString() ?? 'مستخدم المنصة';
          final body = data?['message']?.toString() ?? 'وصلتك رسالة تواصل جديدة';
          NotificationService().showNotificationDirect(
            title: 'رسالة تواصل جديدة من $name',
            body: body,
            payload: 'support_message',
            id: change.doc.id.hashCode,
          );
        }
      }
    }, onError: (e) {
      debugPrint('supportMessagesSub error: $e');
    });
  }

  void _startPasswordResetsListener() {
    _passwordResetsSub?.cancel();
    if (_isLoggingOut) return;
    bool isInitialSnapshot = true;
    _passwordResetsSub = FirebaseFirestore.instance
        .collection('password_resets')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (_isLoggingOut || isInitialSnapshot) {
        isInitialSnapshot = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final phone = data?['phone']?.toString() ?? 'غير محدد';
          NotificationService().showNotificationDirect(
            title: 'طلب استعادة كلمة المرور',
            body: 'طلب جديد لاستعادة كلمة المرور لرقم: $phone',
            payload: 'password_reset',
            id: change.doc.id.hashCode,
          );
        }
      }
    }, onError: (e) {
      debugPrint('passwordResetsSub error: $e');
    });
  }

  void _startPendingLawyersListener() {
    _pendingLawyersSub?.cancel();
    if (_isLoggingOut) return;
    bool isInitialSnapshot = true;
    _pendingLawyersSub = FirebaseFirestore.instance
        .collection('lawyers')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snap) {
      if (_isLoggingOut || isInitialSnapshot) {
        isInitialSnapshot = false;
        return;
      }
      for (final change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data();
          final name = data?['name']?.toString() ?? 'محامٍ جديد';
          final city = data?['city']?.toString() ?? '';
          NotificationService().showNotificationDirect(
            title: 'طلب انضمام محامٍ جديد',
            body: 'طلب انضمام جديد من المحامي: $name${city.isNotEmpty ? " ($city)" : ""}',
            payload: 'lawyer_registration',
            id: change.doc.id.hashCode,
          );
        }
      }
    }, onError: (e) {
      debugPrint('pendingLawyersSub error: $e');
    });
  }

  @override
  void dispose() {
    _overviewScrollCtrl.dispose();
    _supportMessagesSub?.cancel();
    _passwordResetsSub?.cancel();
    _pendingLawyersSub?.cancel();
    _adminNameCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _adminPassCtrl.dispose();
    _accountsSearchCtrl.dispose();
    _directorySearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyAdminAccess() async {
    if (_isLoggingOut) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted && !_isLoggingOut) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen(role: 'admin')),
          (_) => false,
        );
      }
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final role = doc.data()?['role']?.toString();
      final isAdmin = role == 'admin' || (await FirebaseFirestore.instance.collection('admins').doc(user.uid).get()).exists;

      if (!isAdmin) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم رفض الوصول: هذا الحساب ليس لديه صلاحيات المشرف.', style: GoogleFonts.cairo()),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginScreen(role: 'admin')),
            (_) => false,
          );
        }
        return;
      }

      String detectedPhone = '';
      try {
        final adminDoc = await FirebaseFirestore.instance.collection('admins').doc(user.uid).get();
        if (adminDoc.exists && adminDoc.data()?['phone'] != null && adminDoc.data()!['phone'].toString().isNotEmpty) {
          detectedPhone = adminDoc.data()!['phone'].toString();
        } else {
          final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
          if (userDoc.exists && userDoc.data()?['phone'] != null && userDoc.data()!['phone'].toString().isNotEmpty) {
            detectedPhone = userDoc.data()!['phone'].toString();
          }
        }
      } catch (_) {}

      if (detectedPhone.isEmpty && user.email != null) {
        detectedPhone = user.email!
            .replaceAll('@mahameek.admin.com', '')
            .replaceAll('@mahameek.client.com', '')
            .replaceAll('@mahameek.lawyer.com', '');
      }

      if (mounted) {
        setState(() {
          _isAdminVerified = true;
          _isCheckingAuth = false;
          _currentAdminEmail = user.email ?? 'المشرف';
          _currentAdminPhone = detectedPhone;
        });
        NotificationService().enableAllNotifications(adminUid: user.uid);
        _startAdminRealtimeListeners();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen(role: 'admin')),
          (_) => false,
        );
      }
    }
  }


  /// انتقال سلس وخفيف جداً على المعالج والذاكرة (120 FPS / Zero Lag)
  void _pushSmoothRoute(Widget page) {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curve = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.06, 0.0),
              end: Offset.zero,
            ).animate(curve),
            child: FadeTransition(
              opacity: curve,
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
      ),
    );
  }

  /// معالجة النقر على الإشعار: إغلاق سلس، تحديد كمقروء (ليُحذف عند العودة)، وفتح الصفحة المخصصة
  Future<void> _handleAdminNotificationTap(
    AdminNotificationModel n,
    BuildContext modalCtx,
  ) async {
    // 1. إغلاق نافذة الإشعارات بسلاسة
    if (modalCtx.mounted) {
      Navigator.pop(modalCtx);
    }

    // 2. تحديث حالة الإشعار في فايرستور ليصبح مقروءاً (يحذف من القائمة غير المقروءة)
    await NotificationService().markAsRead(n.id);

    // 3. التوجيه المباشر والانتقال فائق الخفة إلى الشاشة المخصصة
    if (n.isPasswordReset) {
      _pushSmoothRoute(const AdminPasswordResetsScreen());
    } else if (n.isLawyerRegistration) {
      _pushSmoothRoute(const AdminPendingLawyersScreen());
    } else if (n.isSupportMessage) {
      _pushSmoothRoute(const AdminSupportMessagesScreen());
    } else {
      if (_currentIndex != 0) {
        setState(() => _currentIndex = 0);
      }
    }
  }

  final List<FloatingNavItemData> _adminNavItems = const [
    FloatingNavItemData(
      icon: Icons.dashboard_outlined,
      activeIcon: Icons.dashboard_rounded,
      label: 'الرئيسية',
    ),
    FloatingNavItemData(
      icon: Icons.manage_accounts_outlined,
      activeIcon: Icons.manage_accounts_rounded,
      label: 'حسابات',
    ),
    FloatingNavItemData(
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      label: 'المستخدمين',
    ),
    FloatingNavItemData(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'الإعدادات',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const Color headerGold = Color(0xFFD49B1A);
    const Color pageBg = Color(0xFFFCFBF9);

    if (_isCheckingAuth || !_isAdminVerified) {
      return Scaffold(
        backgroundColor: pageBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 38,
                height: 38,
                child: CircularProgressIndicator(color: headerGold, strokeWidth: 3),
              ),
              const SizedBox(height: 16),
              Text(
                'جاري التحقق من صلاحيات المشرف...',
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B2A5B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: pageBg,
      extendBody: true,
      drawer: _buildAdminDrawer(),
      appBar: _buildTopAppBar(headerGold),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          // 0. الرئيسية (Overview Dashboard)
          _buildOverviewTab(),

          // 1. حسابات (Accounts Management)
          _buildAccountsTab(),

          // 2. المستخدمين (All Registered Users Directory & Ledger)
          _buildUsersDirectoryTab(),

          // 3. الإعدادات (Settings & Account)
          _buildAdminSettingsTab(),
        ],
      ),
      bottomNavigationBar: FloatingNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: _adminNavItems,
        barBackgroundColor: headerGold,
        activeBgColor: Colors.white,
        activeColor: const Color(0xFF0B2A5B),
        inactiveColor: const Color(0xAA0F1B3E),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TOP APP BAR (Real logo in white pill + Hamburger menu)
  // ─────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildTopAppBar(Color headerGold) {
    return AppBar(
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
            children: [
              const AppLogoBadge(
                height: 30,
                withPillBackground: true,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'يقظ 24/7',
                      style: GoogleFonts.cairo(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Notification Bell with live unread counter
              StreamBuilder<List<AdminNotificationModel>>(
                stream: NotificationService().getAdminNotificationsStream(),
                builder: (context, snap) {
                  final notifs = snap.data ?? [];
                  final unreadCount = notifs.where((n) => !n.isRead).length;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      GlassContainer(
                        borderRadius: 12,
                        blur: 6,
                        backgroundColor: Colors.white.withValues(alpha: 0.28),
                        borderColor: Colors.white.withValues(alpha: 0.55),
                        padding: const EdgeInsets.all(6),
                        child: InkWell(
                          onTap: () => _showAdminNotificationsSheet(notifs),
                          borderRadius: BorderRadius.circular(12),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Color(0xFF0B2A5B),
                            size: 24,
                          ),
                        ),
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          top: -3,
                          left: -3,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                            child: Text(
                              '$unreadCount',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 8),
              GlassContainer(
                borderRadius: 12,
                blur: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.28),
                borderColor: Colors.white.withValues(alpha: 0.55),
                padding: const EdgeInsets.all(6),
                child: InkWell(
                  onTap: () => _scaffoldKey.currentState?.openDrawer(),
                  borderRadius: BorderRadius.circular(12),
                  child: const Icon(
                    Icons.menu_rounded,
                    color: Color(0xFF0B2A5B),
                    size: 25,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 0: OVERVIEW TAB (Matching Image 2 Mockup)
  // ─────────────────────────────────────────────────────────────
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      controller: _overviewScrollCtrl,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Greeting Banner (Welcome Admin + Justice Emblem)
          _buildWelcomeBanner(),
          const SizedBox(height: 20),

          // 2. إحصائيات عامة (General Statistics)
          _buildSectionHeader(title: 'إحصائيات عامة'),
          const SizedBox(height: 12),
          _buildStatsRow(),
          const SizedBox(height: 24),

          // 3. الأقسام الأربعة الرئيسية في لوحة التحكم (نظام أربع خانات رأسية)
          _buildSectionHeader(title: 'أقسام الإدارة والطلبات'),
          const SizedBox(height: 12),
          _buildFourDepartmentCards(),
          const SizedBox(height: 14),
        ],
      ),
    );
  }

  // 3. الأقسام الأربعة الرئيسية في لوحة التحكم (نظام أربع خانات تحت بعض بالطول)
  Widget _buildFourDepartmentCards() {
    return Column(
      children: [
        // 1. طلبات الانضمام
        _buildDepartmentNavCard(
          title: 'طلبات الانضمام',
          subtitle: 'مراجعة واعتماد طلبات وتراخيص المحامين الجدد',
          icon: Icons.gavel_rounded,
          iconColor: const Color(0xFFD97706),
          iconBg: const Color(0xFFFFFBEB),
          bellWidget: StreamBuilder<List<LawyerModel>>(
            stream: _firestoreService.getPendingLawyers(),
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return _buildNotificationBellBadge(
                count: count,
                bellColor: const Color(0xFFD97706),
                containerBg: const Color(0xFFFFFBEB),
              );
            },
          ),
          onTap: () => _pushSmoothRoute(const AdminPendingLawyersScreen()),
        ),

        // 2. طلبات استعادة كلمة المرور
        _buildDepartmentNavCard(
          title: 'طلبات استعادة كلمة المرور',
          subtitle: 'إعادة ضبط وتوليد كلمات المرور وتواصل واتساب',
          icon: Icons.key_rounded,
          iconColor: const Color(0xFFEA580C),
          iconBg: const Color(0xFFFFF7ED),
          bellWidget: StreamBuilder<List<PasswordResetModel>>(
            stream: _firestoreService.getPasswordResetsStream(),
            builder: (context, snap) {
              final count = snap.data?.length ?? 0;
              return _buildNotificationBellBadge(
                count: count,
                bellColor: const Color(0xFFEA580C),
                containerBg: const Color(0xFFFFF7ED),
              );
            },
          ),
          onTap: () => _pushSmoothRoute(const AdminPasswordResetsScreen()),
        ),

        // 3. رسائل التواصل والدعم
        _buildDepartmentNavCard(
          title: 'رسائل التواصل والدعم',
          subtitle: 'متابعة استفسارات وملاحظات العملاء والمحامين',
          icon: Icons.chat_bubble_outline_rounded,
          iconColor: const Color(0xFF2563EB),
          iconBg: const Color(0xFFEFF6FF),
          bellWidget: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('support_messages')
                .where('status', isEqualTo: 'unread')
                .snapshots(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              return _buildNotificationBellBadge(
                count: count,
                bellColor: const Color(0xFF2563EB),
                containerBg: const Color(0xFFEFF6FF),
              );
            },
          ),
          onTap: () => _pushSmoothRoute(const AdminSupportMessagesScreen()),
        ),

        // 4. آخر المحامين المنضمين
        _buildDepartmentNavCard(
          title: 'آخر المحامين المنضمين',
          subtitle: 'سجل المحامين المعتمدين والمفعلين بالمنصة',
          icon: Icons.verified_user_rounded,
          iconColor: const Color(0xFF059669),
          iconBg: const Color(0xFFECFDF5),
          bellWidget: _buildNotificationBellBadge(
            count: 0,
            bellColor: const Color(0xFF059669),
            containerBg: const Color(0xFFECFDF5),
            showBadge: false,
          ),
          onTap: () => _pushSmoothRoute(const AdminRecentLawyersScreen()),
        ),
      ],
    );
  }

  /// ويدجت جرس التنبيهات المخصص بتصميم الصورة 2 مع شارة حمراء دائرية وإظهار +99 عند تجاوز 99
  Widget _buildNotificationBellBadge({
    required int count,
    required Color bellColor,
    required Color containerBg,
    bool showBadge = true,
  }) {
    final bool hasNew = count > 0 && showBadge;
    final String displayCount = count > 99 ? '+99' : '$count';

    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: containerBg,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: bellColor.withValues(alpha: (hasNew || !showBadge) ? 0.28 : 0.15),
          width: 1.2,
        ),
      ),
      child: Center(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // أيقونة الجرس بلون القسم المخصص
            Icon(
              (hasNew || !showBadge) ? Icons.notifications_rounded : Icons.notifications_none_rounded,
              color: (hasNew || !showBadge) ? bellColor : const Color(0xFF94A3B8),
              size: 24,
            ),

            // الشارة الحمراء الدائرية المماثلة تماماً للصورة مع حدود بيضاء
            if (hasNew)
              Positioned(
                top: -6,
                right: -7,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: count > 99 ? 4 : (count > 9 ? 3.5 : 0),
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      displayCount,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDepartmentNavCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required Widget bellWidget,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: iconColor.withValues(alpha: 0.08),
          highlightColor: iconColor.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            child: Row(
              textDirection: TextDirection.rtl,
              children: [
                // 1. أيقونة القسم (Department Icon)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: iconColor.withValues(alpha: 0.18), width: 1.2),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 12),

                // 2. الاسم والوصف (Expanded لمنع أي Overflow نهائياً على كل الشاشات)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B2A5B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),

                // 3. جرس التنبيهات مع الشارة الحمراء (مستبدلاً السهم بنفس موقعه تماماً)
                bellWidget,
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. Greeting Banner
  Widget _buildWelcomeBanner() {
    return GlassContainer(
      borderRadius: 18,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE2E8F0),
      borderWidth: 1.2,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shadows: [
        BoxShadow(
          color: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ],
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2A5B), Color(0xFF1E2E60)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.balance_rounded,
              color: Color(0xFFD49B1A),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'مرحباً بك، المشرف العام',
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'نشط',
                            style: GoogleFonts.cairo(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF059669),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Text(
                  'لوحة القيادة المركزية • متابعة التراخيص والمستخدمين',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 2. Stats Grid (Airy 2x2 Grid)
  Widget _buildStatsRow() {
    return FutureBuilder<Map<String, int>>(
      future: _firestoreService.getStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data ?? {
          'totalLawyers': 0,
          'approvedLawyers': 0,
          'pendingLawyers': 0,
          'totalClients': 0
        };

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'المحامين المعتمدين',
                    sublabel: 'نشط ومفعل بالمنصة',
                    value: stats['approvedLawyers'] ?? 0,
                    icon: Icons.verified_rounded,
                    color: const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'طلبات الانضمام',
                    sublabel: 'بانتظار المراجعة والتدقيق',
                    value: stats['pendingLawyers'] ?? 0,
                    icon: Icons.pending_actions_rounded,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    label: 'إجمالي المحامين',
                    sublabel: 'السجل العام للمحاماة',
                    value: stats['totalLawyers'] ?? 0,
                    icon: Icons.gavel_rounded,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    label: 'إجمالي العملاء',
                    sublabel: 'المسجلون بالمنصة',
                    value: stats['totalClients'] ?? 0,
                    icon: Icons.groups_rounded,
                    color: const Color(0xFF2563EB),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String sublabel,
    required int value,
    required IconData icon,
    required Color color,
  }) {
    return GlassContainer(
      borderRadius: 18,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE2E8F0),
      borderWidth: 1.2,
      padding: const EdgeInsets.all(14),
      shadows: [
        BoxShadow(
          color: const Color(0xFF0B2A5B).withValues(alpha: 0.03),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.2), width: 1.0),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'مباشر',
                      style: GoogleFonts.cairo(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0F172A),
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            sublabel,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF94A3B8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// نافذة عرض الإشعارات والتنبيهات الإدارية الواردة مع إدارة الحذف والتحديد الجماعي
  void _showAdminNotificationsSheet([List<AdminNotificationModel>? initialNotifications]) {
    int activeFilter = 0; // 0: غير المقروءة, 1: الكل
    bool isSelectionMode = false;
    final Set<String> selectedIds = <String>{};
    bool isDeleting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => StreamBuilder<List<AdminNotificationModel>>(
          stream: NotificationService().getAdminNotificationsStream(),
          initialData: initialNotifications,
          builder: (streamCtx, snapshot) {
            final allNotifications = snapshot.data ?? initialNotifications ?? [];
            final unreadNotifications = allNotifications.where((n) => !n.isRead).toList();
            final displayNotifications = activeFilter == 0 ? unreadNotifications : allNotifications;

            // تنظيف أي عناصر لم تعد موجودة من قائمة التحديد
            final validIds = displayNotifications.map((n) => n.id).toSet();
            selectedIds.removeWhere((id) => !validIds.contains(id));

            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 14,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
              ),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.82,
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
                  const SizedBox(height: 14),

                  // شريط العنوان أو شريط التحكم في التحديد
                  if (!isSelectionMode)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      textDirection: TextDirection.rtl,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.notifications_active_rounded, color: Color(0xFFD97706), size: 20),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'إشعارات وتنبيهات الإدارة',
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B2A5B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // أيقونات الإجراءات (تحديد كمقروء + سلة الحذف)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (unreadNotifications.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.done_all_rounded, size: 22, color: Color(0xFF2563EB)),
                                tooltip: 'تحديد الكل كمقروء',
                                onPressed: () async {
                                  await NotificationService().markAllAsRead();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('تم تحديد كافة الإشعارات كمقروءة', style: GoogleFonts.cairo()),
                                        backgroundColor: const Color(0xFF10B981),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                },
                              ),
                            if (displayNotifications.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.delete_outline_rounded, size: 22, color: Color(0xFFEF4444)),
                                tooltip: 'تحديد وحذف الإشعارات',
                                onPressed: () {
                                  setSheetState(() {
                                    isSelectionMode = true;
                                    // تحديد الكل تلقائياً كما طلب المستخدم
                                    selectedIds.clear();
                                    selectedIds.addAll(displayNotifications.map((n) => n.id));
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    )
                  else
                    // شريط وضع التحديد المتعدد
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        textDirection: TextDirection.rtl,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                                tooltip: 'إلغاء وضع التحديد',
                                onPressed: () {
                                  setSheetState(() {
                                    isSelectionMode = false;
                                    selectedIds.clear();
                                  });
                                },
                              ),
                              Text(
                                'محدد (${selectedIds.length}/${displayNotifications.length})',
                                style: GoogleFonts.cairo(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF991B1B),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // زر إلغاء الكل أو تحديد الكل
                              TextButton(
                                onPressed: () {
                                  setSheetState(() {
                                    if (selectedIds.length == displayNotifications.length) {
                                      selectedIds.clear();
                                    } else {
                                      selectedIds.clear();
                                      selectedIds.addAll(displayNotifications.map((n) => n.id));
                                    }
                                  });
                                },
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                                child: Text(
                                  selectedIds.length == displayNotifications.length ? 'إلغاء الكل' : 'تحديد الكل',
                                  style: GoogleFonts.cairo(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              // زر حذف المحدد
                              ElevatedButton.icon(
                                onPressed: selectedIds.isEmpty || isDeleting
                                    ? null
                                    : () async {
                                        final count = selectedIds.length;
                                        final confirmed = await AppDialog.deleteConfirm(
                                          context,
                                          title: 'تأكيد الحذف',
                                          message: 'هل أنت متأكد من حذف $count إشعار نهائياً من السجل؟ لا يمكن التراجع عن هذا الإجراء.',
                                          confirmLabel: 'حذف الآن',
                                          cancelLabel: 'إلغاء',
                                        );

                                        if (confirmed == true) {
                                          setSheetState(() => isDeleting = true);
                                          await NotificationService().deleteMultipleNotifications(selectedIds.toList());
                                          setSheetState(() {
                                            selectedIds.clear();
                                            isSelectionMode = false;
                                            isDeleting = false;
                                          });
                                          if (mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('تم حذف $count إشعار بنجاح', style: GoogleFonts.cairo()),
                                                backgroundColor: const Color(0xFF10B981),
                                                duration: const Duration(seconds: 2),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFEF4444),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                icon: isDeleting
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                                    : const Icon(Icons.delete_rounded, size: 14),
                                label: Text('حذف (${selectedIds.length})', style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),

                  // تبديل التصفية: غير المقروءة / السجل الكامل
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      InkWell(
                        onTap: () => setSheetState(() {
                          activeFilter = 0;
                          if (isSelectionMode) {
                            selectedIds.clear();
                            selectedIds.addAll(unreadNotifications.map((n) => n.id));
                          }
                        }),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: activeFilter == 0 ? const Color(0xFF0B2A5B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'غير المقروءة (${unreadNotifications.length})',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: activeFilter == 0 ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => setSheetState(() {
                          activeFilter = 1;
                          if (isSelectionMode) {
                            selectedIds.clear();
                            selectedIds.addAll(allNotifications.map((n) => n.id));
                          }
                        }),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: activeFilter == 1 ? const Color(0xFF0B2A5B) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'السجل (${allNotifications.length})',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: activeFilter == 1 ? Colors.white : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  if (displayNotifications.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: const BoxDecoration(
                                color: Color(0xFFECFDF5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.done_all_rounded, size: 26, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              activeFilter == 0 ? 'لا توجد تنبيهات جديدة غير مقروءة' : 'لا توجد تنبيهات مسجلة حالياً',
                              style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0B2A5B), fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              activeFilter == 0
                                  ? 'لقد اطلعت على كافة الإشعارات، وتم تحديث القائمة'
                                  : 'السجل فارغ حالياً',
                              style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: displayNotifications.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final n = displayNotifications[i];
                          final isSelected = selectedIds.contains(n.id);
                          final isReset = n.isPasswordReset;
                          final isLawyer = n.isLawyerRegistration;
                          final isSupport = n.isSupportMessage;
                          final formattedTime = DateFormat('yyyy/MM/dd - hh:mm a').format(n.createdAt);

                          final iconData = isReset
                              ? Icons.key_rounded
                              : (isLawyer
                                  ? Icons.gavel_rounded
                                  : (isSupport ? Icons.chat_bubble_outline_rounded : Icons.info_rounded));

                          final iconColor = isReset
                              ? const Color(0xFFEA580C)
                              : (isLawyer
                                  ? const Color(0xFFD97706)
                                  : (isSupport ? const Color(0xFF2563EB) : const Color(0xFF2563EB)));

                          final iconBg = isReset
                              ? const Color(0xFFFFF7ED)
                              : (isLawyer
                                  ? const Color(0xFFFEF3C7)
                                  : (isSupport ? const Color(0xFFEFF6FF) : const Color(0xFFEFF6FF)));

                          return InkWell(
                            onTap: () {
                              if (isSelectionMode) {
                                setSheetState(() {
                                  if (isSelected) {
                                    selectedIds.remove(n.id);
                                  } else {
                                    selectedIds.add(n.id);
                                  }
                                });
                              } else {
                                _handleAdminNotificationTap(n, modalCtx);
                              }
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFFBEB)
                                    : (n.isRead ? const Color(0xFFF8FAFC) : const Color(0xFFFFFDF5)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFD49B1A)
                                      : (n.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFFDE68A)),
                                  width: isSelected ? 1.8 : 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                textDirection: TextDirection.rtl,
                                children: [
                                  if (isSelectionMode)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 10, top: 8),
                                      child: Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                        color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFFCBD5E1),
                                        size: 22,
                                      ),
                                    ),
                                  Container(
                                    width: 38,
                                    height: 38,
                                    decoration: BoxDecoration(
                                      color: iconBg,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      iconData,
                                      color: iconColor,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          textDirection: TextDirection.rtl,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                n.title,
                                                style: GoogleFonts.cairo(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w800,
                                                  color: const Color(0xFF0B2A5B),
                                                ),
                                              ),
                                            ),
                                            if (!isSelectionMode)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFFEFF6FF),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Text(
                                                          'انتقال',
                                                          style: GoogleFonts.cairo(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.w700,
                                                            color: const Color(0xFF2563EB),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 2),
                                                        const Icon(
                                                          Icons.arrow_back_ios_new_rounded,
                                                          size: 10,
                                                          color: Color(0xFF2563EB),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (!n.isRead) ...[
                                                    const SizedBox(width: 6),
                                                    Container(
                                                      width: 8,
                                                      height: 8,
                                                      decoration: const BoxDecoration(
                                                        color: Color(0xFFEF4444),
                                                        shape: BoxShape.circle,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          n.body,
                                          style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF475569), height: 1.35),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          formattedTime,
                                          style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                        ),
                                      ],
                                    ),
                                  ),
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
      ),
    );
  }

  void _showAdminResetPasswordDialog({
    required String phone,
    String? name,
    String? ticketId,
    String? targetUid,
  }) {
    final passCtrl = TextEditingController(text: '123456');
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 16,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Glowing Key Icon Badge
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFDE68A), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD49B1A).withValues(alpha: 0.2),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.key_rounded, color: Color(0xFFD97706), size: 32),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Title
                Text(
                  'تعيين كلمة مرور جديدة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                    color: const Color(0xFF0B2A5B),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),

                // 3. User Target Box
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'سيتم تعيين كلمة المرور فورياً للحساب:',
                        style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B)),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      if (name != null && name.trim().isNotEmpty) ...[
                        Text(
                          name.trim(),
                          style: GoogleFonts.cairo(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2A5B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 5),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0B2A5B).withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0B2A5B).withValues(alpha: 0.1)),
                        ),
                        child: Text(
                          PhoneUtils.formatForDisplay(phone),
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.cairo(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2A5B),
                            letterSpacing: 0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 4. Input Field
                TextField(
                  controller: passCtrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                    labelStyle: GoogleFonts.cairo(color: const Color(0xFF64748B), fontSize: 13),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF0B2A5B)),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.refresh_rounded, color: Color(0xFFD49B1A)),
                      tooltip: 'توليد كلمة سر عشوائية',
                      onPressed: () {
                        final randomPin = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
                        setDlgState(() => passCtrl.text = randomPin);
                      },
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                  ),
                ),
                const SizedBox(height: 20),

                // 5. Actions Row
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(dlgCtx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          backgroundColor: const Color(0xFFF1F5F9),
                          side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: Text('إلغاء', style: GoogleFonts.cairo(fontWeight: FontWeight.w700, fontSize: 13.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                final newPass = passCtrl.text.trim();
                                if (newPass.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف', style: GoogleFonts.cairo()), backgroundColor: const Color(0xFFDC2626)),
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(dlgCtx);
                                setDlgState(() => isSaving = true);
                                final res = await _authService.adminResetUserPassword(
                                  phone: phone,
                                  newPassword: newPass,
                                  ticketId: ticketId,
                                  targetUid: targetUid,
                                );

                                if (!mounted) return;
                                nav.pop();

                                if (res['success'] == true) {
                                  _showPasswordResetSuccessDialog(
                                    phone: phone,
                                    name: name,
                                    newPassword: newPass,
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(content: Text(res['error'] ?? 'فشل تعيين كلمة المرور', style: GoogleFonts.cairo()), backgroundColor: const Color(0xFFDC2626)),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0B2A5B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: isSaving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('حفظ وتعيين', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13.5)),
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

  /// نافذة منبثقة فاخرة تظهر عند نجاح تغيير كلمة السر وتوفر زر واتساب فوري
  void _showPasswordResetSuccessDialog({
    required String phone,
    String? name,
    required String newPassword,
  }) {
    final displayName = name?.trim().isNotEmpty == true ? name!.trim() : 'المستخدم';
    final waPhone = PasswordResetModel.formatWhatsAppNumber(phone);
    final waMessage = 'مرحباً بك $displayName،\n'
        'تمت إعادة تعيين كلمة المرور لحسابك في تطبيق محاميك بنجاح.\n\n'
        'رقم الحساب: $phone\n'
        'كلمة المرور الجديدة: $newPassword\n\n'
        'يمكنك الآن تسجيل الدخول مباشرة بالتطبيق واستخدام حسابك.';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 12,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Icon Badge
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFA7F3D0), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 34),
                ),
              ),
              const SizedBox(height: 14),

              // Title & Subtitle
              Text(
                'تم تعيين كلمة المرور بنجاح',
                style: GoogleFonts.cairo(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF0B2A5B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'تم حفظ كلمة المرور الجديدة في النظام، يمكنك إرسال البيانات لصاحب الحساب فوراً عبر واتساب',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),

              // Credentials Luxury Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    // Phone Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0B2A5B).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.phone_android_rounded, size: 15, color: Color(0xFF0B2A5B)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'رقم الهاتف:',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  PhoneUtils.formatForDisplay(phone),
                                  textDirection: TextDirection.ltr,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF0B2A5B),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: phone));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم نسخ رقم الهاتف: $phone', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                      backgroundColor: const Color(0xFF0B2A5B),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.copy_rounded, size: 15, color: Color(0xFF64748B)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14, color: Color(0xFFE2E8F0)),

                    // Password Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD49B1A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.vpn_key_rounded, size: 15, color: Color(0xFFD97706)),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'كلمة المرور:',
                          style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Flexible(
                                child: Text(
                                  newPassword,
                                  textDirection: TextDirection.ltr,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF059669),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: newPassword));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('تم نسخ كلمة المرور: $newPassword', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                      backgroundColor: const Color(0xFF059669),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Icon(Icons.copy_rounded, size: 15, color: Color(0xFFD97706)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // WhatsApp CTA Button
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  final uri = Uri.parse('https://wa.me/$waPhone?text=${Uri.encodeComponent(waMessage)}');
                  launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                  shadowColor: const Color(0xFF25D366).withValues(alpha: 0.3),
                ),
                icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                label: Text(
                  'إرسال البيانات عبر واتساب',
                  style: GoogleFonts.cairo(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 10),

              // Close / Finish Button
              OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF64748B),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'إغلاق',
                  style: GoogleFonts.cairo(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 1: ACCOUNTS MANAGEMENT (حسابات)
  // Sub-tabs: المحامين | المستخدمين
  // Clicking an account opens action sheet with: Reset Password, WhatsApp, Suspend/Activate, Delete
  // ─────────────────────────────────────────────────────────────
  Widget _buildAccountsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(title: 'إدارة الحسابات وكلمات المرور'),
          const SizedBox(height: 12),

          // Segment Switcher (المحامين | المستخدمين)
          _buildCategorySegment(
            firstLabel: 'المحامين',
            secondLabel: 'المستخدمين',
            firstIcon: Icons.gavel_rounded,
            secondIcon: Icons.people_rounded,
            selectedIndex: _accountsTabCategory,
            onChanged: (idx) => setState(() => _accountsTabCategory = idx),
          ),
          const SizedBox(height: 12),

          // Search Input
          _buildAccountsSearchInput(),
          const SizedBox(height: 10),

          // Status Filter Chips
          _buildStatusFilterRow(),
          const SizedBox(height: 14),

          // Account List Stream
          if (_accountsTabCategory == 0)
            _buildLawyersAccountsList()
          else
            _buildClientsAccountsList(),
        ],
      ),
    );
  }

  Widget _buildCategorySegment({
    required String firstLabel,
    required String secondLabel,
    required IconData firstIcon,
    required IconData secondIcon,
    required int selectedIndex,
    required ValueChanged<int> onChanged,
  }) {
    return GlassContainer(
      borderRadius: 16,
      blur: 0,
      backgroundColor: const Color(0xFFF1F5F9),
      borderColor: const Color(0xFFE2E8F0),
      padding: const EdgeInsets.all(4),
      shadows: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.02),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ],
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => onChanged(0),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selectedIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selectedIndex == 0
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      firstIcon,
                      size: 18,
                      color: selectedIndex == 0 ? const Color(0xFFD49B1A) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      firstLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: selectedIndex == 0 ? const Color(0xFF0B2A5B) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              onTap: () => onChanged(1),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selectedIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: selectedIndex == 1
                      ? [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      secondIcon,
                      size: 18,
                      color: selectedIndex == 1 ? const Color(0xFF3B82F6) : const Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      secondLabel,
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: selectedIndex == 1 ? const Color(0xFF0B2A5B) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountsSearchInput() {
    return GlassContainer(
      borderRadius: 16,
      blur: 0,
      backgroundColor: Colors.white,
      borderColor: const Color(0xFFE2E8F0),
      shadows: [
        BoxShadow(
          color: const Color(0xFF0F172A).withValues(alpha: 0.025),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      child: TextField(
        controller: _accountsSearchCtrl,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: _accountsTabCategory == 0
              ? 'ابحث عن محامي بالاسم، الهاتف أو المدينة...'
              : 'ابحث عن عميل بالاسم أو رقم الهاتف...',
          hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD49B1A)),
          suffixIcon: _accountsSearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => _accountsSearchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildStatusFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      reverse: true,
      child: Row(
        children: [
          _buildFilterChipItem('all', 'الكل'),
          const SizedBox(width: 8),
          _buildFilterChipItem('active', 'النشطة فقط'),
          const SizedBox(width: 8),
          _buildFilterChipItem('suspended', 'الموقوفة فقط', isDanger: true),
        ],
      ),
    );
  }

  Widget _buildFilterChipItem(String key, String label, {bool isDanger = false}) {
    final isSelected = _accountsStatusFilter == key;
    return GlassButton(
      onPressed: () => setState(() => _accountsStatusFilter = key),
      tintColor: isDanger ? const Color(0xFFE11D48) : const Color(0xFF0B2A5B),
      isSelected: isSelected,
      textColor: isSelected
          ? (isDanger ? const Color(0xFFE11D48) : const Color(0xFF0B2A5B))
          : (isDanger ? const Color(0xFFE11D48) : const Color(0xFF475569)),
      label: label,
      borderRadius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    );
  }

  Widget _buildLawyersAccountsList() {
    return StreamBuilder<List<LawyerModel>>(
      stream: _firestoreService.getAllLawyers(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD49B1A)));
        }
        var lawyers = snap.data ?? [];

        if (_accountsSearchQuery.isNotEmpty) {
          lawyers = lawyers.where((l) {
            return AppSearchUtils.matchesAny(_accountsSearchQuery, [
              l.name,
              l.phone,
              l.city,
              l.specialization,
            ]);
          }).toList();
        }

        if (_accountsStatusFilter == 'active') {
          lawyers = lawyers.where((l) => !l.isSuspended).toList();
        } else if (_accountsStatusFilter == 'suspended') {
          lawyers = lawyers.where((l) => l.isSuspended).toList();
        }

        if (lawyers.isEmpty) {
          return _buildEmptyPlaceholder(
            icon: Icons.gavel_rounded,
            title: 'لا توجد حسابات محامين مطابقة للبحث',
            color: const Color(0xFFD49B1A),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lawyers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final l = lawyers[index];
            final bool isSuspended = l.isSuspended;
            final bool isApproved = l.status == 'approved';

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSuspended ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAccountActionModal(context, lawyer: l),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        _buildAvatarWidget(l.photoBase64, l.photoUrl, l.name, 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      l.name,
                                      style: GoogleFonts.cairo(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0B2A5B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSuspended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFDA4AF)),
                                      ),
                                      child: Text(
                                        'موقوف',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFE11D48),
                                        ),
                                      ),
                                    )
                                  else if (!isApproved)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFDE68A)),
                                      ),
                                      child: Text(
                                        'قيد المراجعة',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFD97706),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${l.specialization.isNotEmpty ? l.specialization : "محامي ومستشار"} • ${l.city}',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: l.phone));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تم نسخ رقم الهاتف: ${l.phone}', style: GoogleFonts.cairo()),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_rounded, size: 12, color: Color(0xFFD49B1A)),
                                          const SizedBox(width: 5),
                                          Text(
                                            PhoneUtils.formatForDisplay(l.phone),
                                            textDirection: TextDirection.ltr,
                                            style: GoogleFonts.cairo(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GlassButton(
                          onPressed: () => _showAccountActionModal(context, lawyer: l),
                          backgroundColor: const Color(0xFFFFFBEB),
                          borderColor: const Color(0xFFFDE68A),
                          padding: const EdgeInsets.all(10),
                          borderRadius: 12,
                          child: const Icon(Icons.tune_rounded, size: 19, color: Color(0xFFD97706)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClientsAccountsList() {
    return StreamBuilder<List<UserModel>>(
      stream: _firestoreService.getAllClients(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD49B1A)));
        }
        var clients = snap.data ?? [];

        if (_accountsSearchQuery.isNotEmpty) {
          clients = clients.where((c) {
            return AppSearchUtils.matchesAny(_accountsSearchQuery, [
              c.name,
              c.phone,
            ]);
          }).toList();
        }

        if (_accountsStatusFilter == 'active') {
          clients = clients.where((c) => !c.isSuspended).toList();
        } else if (_accountsStatusFilter == 'suspended') {
          clients = clients.where((c) => c.isSuspended).toList();
        }

        if (clients.isEmpty) {
          return _buildEmptyPlaceholder(
            icon: Icons.people_outline_rounded,
            title: 'لا توجد حسابات عملاء مطابقة للبحث',
            color: const Color(0xFF3B82F6),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clients.length,
          separatorBuilder: (context, index) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final c = clients[index];
            final bool isSuspended = c.isSuspended;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSuspended ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _showAccountActionModal(context, client: c),
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.all(15),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        _buildAvatarWidget(c.photoBase64, c.photoUrl, c.name, 50),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      c.name,
                                      style: GoogleFonts.cairo(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: const Color(0xFF0B2A5B),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isSuspended)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF1F2),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFFDA4AF)),
                                      ),
                                      child: Text(
                                        'موقوف',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFFE11D48),
                                        ),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEFF6FF),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                      ),
                                      child: Text(
                                        'عميل',
                                        style: GoogleFonts.cairo(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          color: const Color(0xFF2563EB),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'مستخدم مسجل في المنصة',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  InkWell(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(text: c.phone));
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('تم نسخ رقم الهاتف: ${c.phone}', style: GoogleFonts.cairo()),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    borderRadius: BorderRadius.circular(8),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF8FAFC),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.phone_rounded, size: 12, color: Color(0xFF2563EB)),
                                          const SizedBox(width: 5),
                                          Text(
                                            PhoneUtils.formatForDisplay(c.phone),
                                            textDirection: TextDirection.ltr,
                                            style: GoogleFonts.cairo(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: const Color(0xFF1E293B),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        GlassButton(
                          onPressed: () => _showAccountActionModal(context, client: c),
                          backgroundColor: const Color(0xFFEFF6FF),
                          borderColor: const Color(0xFFBFDBFE),
                          padding: const EdgeInsets.all(10),
                          borderRadius: 12,
                          child: const Icon(Icons.tune_rounded, size: 19, color: Color(0xFF2563EB)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 2: USERS & LAWYERS DIRECTORY & LEDGER (المستخدمين)
  // Sub-tabs: محامين | مستخدمين
  // Displays accounting & stats of all registered accounts in the app
  // ─────────────────────────────────────────────────────────────
  Widget _buildUsersDirectoryTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(title: 'سجل وإحصائيات المسجلين بالتطبيق'),
          const SizedBox(height: 12),

          // Category Switcher (محامين | مستخدمين)
          _buildCategorySegment(
            firstLabel: 'محامين',
            secondLabel: 'مستخدمين',
            firstIcon: Icons.gavel_rounded,
            secondIcon: Icons.people_rounded,
            selectedIndex: _directoryTabCategory,
            onChanged: (idx) => setState(() => _directoryTabCategory = idx),
          ),
          const SizedBox(height: 14),

          // Live Ledger Metrics Row
          if (_directoryTabCategory == 0)
            _buildLawyersLedgerMetrics()
          else
            _buildClientsLedgerMetrics(),
          const SizedBox(height: 14),

          // Search Input
          _buildDirectorySearchInput(),
          const SizedBox(height: 14),

          // Directory List
          if (_directoryTabCategory == 0)
            _buildLawyersDirectoryList()
          else
            _buildClientsDirectoryList(),
        ],
      ),
    );
  }

  Widget _buildDirectorySearchInput() {
    return GlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(18),
      borderColor: const Color(0xFFE2E8F0),
      backgroundColor: Colors.white.withValues(alpha: 0.9),
      shadowBlur: 10,
      shadowOffset: const Offset(0, 3),
      shadowColor: Colors.black.withValues(alpha: 0.03),
      child: TextField(
        controller: _directorySearchCtrl,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: _directoryTabCategory == 0
              ? 'ابحث في سجل المحامين بالاسم، الهاتف أو المدينة...'
              : 'ابحث في سجل المستخدمين بالاسم أو الهاتف...',
          hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD49B1A)),
          suffixIcon: _directorySearchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => _directorySearchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  Widget _buildLawyersLedgerMetrics() {
    return StreamBuilder<List<LawyerModel>>(
      stream: _firestoreService.getAllLawyers(),
      builder: (context, snap) {
        final lawyers = snap.data ?? [];
        final total = lawyers.length;
        final approved = lawyers.where((l) => l.status == 'approved' && !l.isSuspended).length;
        final pending = lawyers.where((l) => l.status == 'pending').length;
        final suspended = lawyers.where((l) => l.isSuspended).length;

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildMetricMiniCard('إجمالي المحامين', '$total', const Color(0xFF0F172A), Icons.gavel_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _buildMetricMiniCard('نشط ومفعل', '$approved', const Color(0xFF10B981), Icons.verified_rounded)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMetricMiniCard('قيد المراجعة', '$pending', const Color(0xFFF59E0B), Icons.pending_actions_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _buildMetricMiniCard('موقوف مؤقتاً', '$suspended', const Color(0xFFE11D48), Icons.block_rounded)),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildClientsLedgerMetrics() {
    return StreamBuilder<List<UserModel>>(
      stream: _firestoreService.getAllClients(),
      builder: (context, snap) {
        final clients = snap.data ?? [];
        final total = clients.length;
        final active = clients.where((c) => !c.isSuspended).length;
        final suspended = clients.where((c) => c.isSuspended).length;

        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildMetricMiniCard('إجمالي العملاء', '$total', const Color(0xFF0F172A), Icons.people_rounded)),
                const SizedBox(width: 10),
                Expanded(child: _buildMetricMiniCard('حساب نشط', '$active', const Color(0xFF10B981), Icons.check_circle_rounded)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _buildMetricMiniCard('حساب موقف', '$suspended', const Color(0xFFE11D48), Icons.block_rounded)),
                const SizedBox(width: 10),
                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricMiniCard(String label, String value, Color color, IconData icon) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      borderRadius: 18,
      borderWidth: 1.2,
      borderColor: const Color(0xFFE2E8F0),
      backgroundColor: Colors.white,
      shadowBlur: 10,
      shadowOffset: const Offset(0, 3),
      shadowColor: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF0F172A),
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLawyersDirectoryList() {
    return StreamBuilder<List<LawyerModel>>(
      stream: _firestoreService.getAllLawyers(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD49B1A)));
        }
        var lawyers = snap.data ?? [];

        if (_directorySearchQuery.isNotEmpty) {
          lawyers = lawyers.where((l) {
            return AppSearchUtils.matchesAny(_directorySearchQuery, [
              l.name,
              l.phone,
              l.city,
              l.specialization,
            ]);
          }).toList();
        }

        if (lawyers.isEmpty) {
          return _buildEmptyPlaceholder(
            icon: Icons.gavel_rounded,
            title: 'لا يوجد محامون في السجل',
            color: const Color(0xFFD49B1A),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lawyers.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final l = lawyers[index];
            final isPending = l.status == 'pending';

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ProfileDetailsModal.showLawyerModal(
                  context,
                  lawyer: l,
                  isAdmin: true,
                  onApprove: (uid) => _firestoreService.approveLawyer(uid),
                  onReject: (uid) => _firestoreService.rejectLawyer(uid),
                ),
                borderRadius: BorderRadius.circular(18),
                child: GlassContainer(
                  padding: const EdgeInsets.all(15),
                  borderRadius: BorderRadius.circular(18),
                  borderWidth: 1.2,
                  borderColor: l.isSuspended
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFE2E8F0),
                  backgroundColor: Colors.white,
                  shadowBlur: 10,
                  shadowOffset: const Offset(0, 3),
                  shadowColor: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      _buildAvatarWidget(l.photoBase64, l.photoUrl, l.name, 50),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    l.name,
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0B2A5B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (l.isSuspended)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDA4AF)),
                                    ),
                                    child: Text(
                                      'موقوف',
                                      style: GoogleFonts.cairo(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFE11D48),
                                      ),
                                    ),
                                  )
                                else if (isPending)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFFBEB),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDE68A)),
                                    ),
                                    child: Text(
                                      'قيد المراجعة',
                                      style: GoogleFonts.cairo(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Row(
                              children: [
                                const Icon(Icons.work_outline_rounded, size: 13, color: Color(0xFF64748B)),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${l.specialization.isNotEmpty ? l.specialization : "محامي ومستشار"} • ${l.city}',
                                    style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF475569)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF0B2A5B)),
                                      const SizedBox(width: 4),
                                      Text(
                                        PhoneUtils.formatForDisplay(l.phone),
                                        textDirection: TextDirection.ltr,
                                        style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0B2A5B)),
                                      ),
                                    ],
                                  ),
                                ),
                                if (l.whatsapp.isNotEmpty && l.whatsapp != l.phone)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFECFDF5),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFA7F3D0)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.chat_bubble_outline_rounded, size: 11, color: Color(0xFF059669)),
                                        const SizedBox(width: 4),
                                        Text(
                                          PhoneUtils.formatForDisplay(l.whatsapp),
                                          textDirection: TextDirection.ltr,
                                          style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF059669)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildClientsDirectoryList() {
    return StreamBuilder<List<UserModel>>(
      stream: _firestoreService.getAllClients(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Color(0xFFD49B1A)));
        }
        var clients = snap.data ?? [];

        if (_directorySearchQuery.isNotEmpty) {
          clients = clients.where((c) {
            return AppSearchUtils.matchesAny(_directorySearchQuery, [
              c.name,
              c.phone,
            ]);
          }).toList();
        }

        if (clients.isEmpty) {
          return _buildEmptyPlaceholder(
            icon: Icons.people_outline_rounded,
            title: 'لا يوجد عملاء في السجل',
            color: const Color(0xFF3B82F6),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: clients.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final u = clients[index];
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => ProfileDetailsModal.showClientModal(
                  context,
                  client: u,
                  isAdmin: true,
                ),
                borderRadius: BorderRadius.circular(18),
                child: GlassContainer(
                  padding: const EdgeInsets.all(15),
                  borderRadius: BorderRadius.circular(18),
                  borderWidth: 1.2,
                  borderColor: u.isSuspended
                      ? const Color(0xFFFDA4AF)
                      : const Color(0xFFE2E8F0),
                  backgroundColor: Colors.white,
                  shadowBlur: 10,
                  shadowOffset: const Offset(0, 3),
                  shadowColor: const Color(0xFF0B2A5B).withValues(alpha: 0.035),
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      _buildAvatarWidget(u.photoBase64, u.photoUrl, u.name, 48),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    u.name,
                                    style: GoogleFonts.cairo(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF0B2A5B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (u.isSuspended)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1F2),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: const Color(0xFFFDA4AF)),
                                    ),
                                    child: Text(
                                      'موقوف',
                                      style: GoogleFonts.cairo(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFFE11D48),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_rounded, size: 11, color: Color(0xFF0B2A5B)),
                                  const SizedBox(width: 4),
                                  Text(
                                    PhoneUtils.formatForDisplay(u.phone),
                                    textDirection: TextDirection.ltr,
                                    style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFF0B2A5B)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 13,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// فتح محادثة واتساب الرسمية مع الحساب
  Future<void> _launchWhatsAppForAccount({
    required String phone,
    required String name,
    required String role,
  }) async {
    String waPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (waPhone.startsWith('0')) waPhone = '249${waPhone.substring(1)}';
    if (!waPhone.startsWith('249') && waPhone.length <= 10) waPhone = '249$waPhone';

    final roleTitle = role == 'lawyer' ? 'سعادة المحامي' : 'الأستاذ/ة';
    final message = 'السلام عليكم ورحمة الله وبركاته،\n'
        'تحية طيبة $roleTitle $name،\n'
        'نتواصل معكم من إدارة منصة محاميك بخصوص حسابكم المسجل لدينا.\n'
        'نسعد دائماً بخدمتكم وتوفير الدعم اللازم لكم.';

    final uri = Uri.parse('https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح تطبيق واتساب مباشرة، يرجى التأكد من توفر التطبيق على جهازك.', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  /// نافذة الإجراءات الأربعة المنبثقة عند الضغط على أي حساب في تبويب "حسابات"
  void _showAccountActionModal(
    BuildContext context, {
    LawyerModel? lawyer,
    UserModel? client,
  }) {
    final bool isLawyer = lawyer != null;
    final String name = isLawyer ? lawyer.name : (client?.name ?? '');
    final String phone = isLawyer ? lawyer.phone : (client?.phone ?? '');
    final String targetUid = isLawyer ? lawyer.uid : (client?.uid ?? '');
    final bool isSuspended = isLawyer ? lawyer.isSuspended : (client?.isSuspended ?? false);
    final String? photoUrl = isLawyer ? lawyer.photoUrl : client?.photoUrl;
    final String? photoBase64 = isLawyer ? lawyer.photoBase64 : client?.photoBase64;
    final String subtitle = isLawyer
        ? '${lawyer.specialization.isNotEmpty ? lawyer.specialization : "محامي ومستشار قانوني"} • ${lawyer.city}'
        : 'عميل مسجل بالمنصة';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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

            // User Identity Header Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  _buildAvatarWidget(photoBase64, photoUrl, name, 50),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isSuspended)
                          Container(
                            margin: const EdgeInsets.only(bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF1F2),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFFDA4AF)),
                            ),
                            child: Text(
                              'الحساب موقف',
                              style: GoogleFonts.cairo(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFE11D48),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          name,
                          style: GoogleFonts.cairo(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF0B2A5B),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '📞 ${PhoneUtils.formatForDisplay(phone)}',
                          textDirection: TextDirection.ltr,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
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
            const SizedBox(height: 18),

            Text(
              'الإجراءات والعمليات على الحساب',
              style: GoogleFonts.cairo(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 12),

            // 1. إعادة كلمة المرور
            _buildActionModalTile(
              icon: Icons.key_rounded,
              iconColor: const Color(0xFFD49B1A),
              iconBgColor: const Color(0xFFFFFBEB),
              title: 'إعادة تعيين كلمة المرور',
              subtitle: 'تحديد كلمة سر جديدة أو توليد رمز وتحديثها فورياً',
              onTap: () {
                Navigator.pop(modalCtx);
                _showAdminResetPasswordDialog(
                  phone: phone,
                  name: name,
                  targetUid: targetUid,
                );
              },
            ),
            const SizedBox(height: 10),

            // 2. إيقاف وتنشيط الحساب
            _buildActionModalTile(
              icon: isSuspended ? Icons.play_circle_fill_rounded : Icons.pause_circle_filled_rounded,
              iconColor: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
              iconBgColor: isSuspended ? const Color(0xFFECFDF5) : const Color(0xFFFFF1F2),
              title: isSuspended ? 'تنشيط الحساب وإلغاء الإيقاف' : 'إيقاف الحساب وحظر الدخول',
              subtitle: isSuspended
                  ? 'إعادة تفعيل الحساب فوراً وتمكين المستخدم من الدخول'
                  : 'منع المستخدم من الدخول للمنصة وإظهار تنبيه الإيقاف له',
              onTap: () {
                Navigator.pop(modalCtx);
                if (isLawyer) {
                  _toggleLawyerStatus(lawyer);
                } else if (client != null) {
                  _toggleClientStatus(client);
                }
              },
            ),
            const SizedBox(height: 10),

            // 3. التواصل عبر واتساب الرسمي
            _buildActionModalTile(
              icon: Icons.chat_rounded,
              iconColor: const Color(0xFF25D366),
              iconBgColor: const Color(0xFFECFDF5),
              title: 'مراسلة الحساب عبر واتساب',
              subtitle: 'فتح محادثة واتساب رسمية ومباشرة مع صاحب الحساب',
              onTap: () {
                Navigator.pop(modalCtx);
                _launchWhatsAppForAccount(
                  phone: phone,
                  name: name,
                  role: isLawyer ? 'lawyer' : 'client',
                );
              },
            ),
            const SizedBox(height: 10),

            // 4. حذف الحساب
            _buildActionModalTile(
              icon: Icons.delete_forever_rounded,
              iconColor: const Color(0xFFEF4444),
              iconBgColor: const Color(0xFFFEF2F2),
              title: 'حذف الحساب نهائياً',
              subtitle: 'حذف سجلات الحساب وقاعدة البيانات بشكل دائم',
              isDestructive: true,
              onTap: () {
                Navigator.pop(modalCtx);
                if (isLawyer) {
                  _confirmDeleteLawyer(lawyer);
                } else if (client != null) {
                  _confirmDeleteClient(client);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionModalTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDestructive ? const Color(0xFFFECDD3) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
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
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
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
                      color: isDestructive ? const Color(0xFFE11D48) : const Color(0xFF0B2A5B),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 14,
              color: isDestructive ? const Color(0xFFFDA4AF) : const Color(0xFFCBD5E1),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // TAB 3: ADMIN SETTINGS & CREDENTIALS
  // ─────────────────────────────────────────────────────────────
  // ─────────────────────────────────────────────────────────────
  // TAB 3: ADMIN SETTINGS & CREDENTIALS
  // ─────────────────────────────────────────────────────────────
  Widget _buildAdminSettingsTab() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(title: 'إعدادات الإدارة والمشرفين'),
          const SizedBox(height: 14),

          // 1. Active Admin Executive Identity Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Color(0xFF0B2A5B),
                  Color(0xFF162552),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFD49B1A).withValues(alpha: 0.35),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD49B1A).withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFD49B1A), width: 1.8),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD49B1A).withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.shield_rounded, color: Color(0xFFD49B1A), size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'المشرف المعتمد حالياً',
                            style: GoogleFonts.cairo(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              'رئيسي',
                              style: GoogleFonts.cairo(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF34D399),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_android_rounded, size: 14, color: Color(0xFFD49B1A)),
                          const SizedBox(width: 6),
                          Text(
                            _displayAdminPhone,
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFF1F5F9),
                              letterSpacing: 0.6,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Change Active Admin Password Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD49B1A).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFD49B1A), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تغيير كلمة المرور لحساب المشرف',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          Text(
                            'تحديث كلمة سر تسجيل الدخول لحساب المشرف الحالي المعتمد',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _showAdminChangePasswordSheet,
                    icon: const Icon(Icons.key_rounded, size: 18, color: Color(0xFF0B2A5B)),
                    label: Text(
                      'تغيير كلمة المرور للمشرف',
                      style: GoogleFonts.cairo(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFFBEB),
                      side: const BorderSide(color: Color(0xFFD49B1A), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Add New Admin Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF0B2A5B), size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إضافة مشرف جديد للمنصة',
                            style: GoogleFonts.cairo(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          Text(
                            'إنشاء حساب إدارة جديد مع تعيين الصلاحيات المعتمدة',
                            style: GoogleFonts.cairo(
                              fontSize: 11.5,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _adminNameCtrl,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0B2A5B), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'اسم المشرف بالكامل',
                    hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFFD49B1A)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                SudanPhoneFormField(
                  controller: _adminPhoneCtrl,
                  hintText: '9XXXXXXXX',
                  borderRadius: 14,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _adminPassCtrl,
                  obscureText: _obscureCreateAdminPass,
                  textDirection: TextDirection.rtl,
                  style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0B2A5B), fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'كلمة المرور (6 أحرف أو أكثر)',
                    hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFD49B1A)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureCreateAdminPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureCreateAdminPass = !_obscureCreateAdminPass),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isCreatingAdmin
                        ? null
                        : () async {
                            final name = _adminNameCtrl.text.trim();
                            final phone = _adminPhoneCtrl.text.trim();
                            final pass = _adminPassCtrl.text.trim();

                            if (name.isEmpty || phone.isEmpty || pass.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('يرجى ملء جميع الحقول وكلمة المرور', style: GoogleFonts.cairo()),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                              return;
                            }

                            setState(() => _isCreatingAdmin = true);

                            final res = await _authService.createAdminAccount(
                              name: name,
                              phone: phone,
                              password: pass,
                            );

                            if (!mounted) return;
                            setState(() => _isCreatingAdmin = false);

                            if (res['success'] == true) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['message']?.toString() ?? 'تم إنشاء واعتماد حساب المشرف بنجاح!', style: GoogleFonts.cairo()),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                              _adminNameCtrl.clear();
                              _adminPhoneCtrl.clear();
                              _adminPassCtrl.clear();
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(res['error']?.toString() ?? 'تعذر إنشاء حساب المشرف', style: GoogleFonts.cairo()),
                                  backgroundColor: const Color(0xFFDC2626),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.shield_rounded, color: Colors.white, size: 18),
                    label: _isCreatingAdmin
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text('حفظ واعتماد المشرف', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B2A5B),
                      foregroundColor: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Sign Out Button (Dark Navy background + Red text & icon matching logo)
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.20),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _confirmSignOut(),
              icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
              label: Text(
                'تسجيل الخروج من لوحة الإدارة',
                style: GoogleFonts.cairo(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFFEF4444),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B2A5B),
                foregroundColor: const Color(0xFFEF4444),
                minimumSize: const Size(double.infinity, 50),
                side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.35), width: 1.2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminChangePasswordSheet() {
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
            22,
            16,
            22,
            MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD49B1A).withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFD49B1A).withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(Icons.lock_reset_rounded, color: Color(0xFFD49B1A), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'تغيير كلمة المرور للمشرف',
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          Text(
                            'حساب المشرف: $_displayAdminPhone',
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (error != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECDD3)),
                    ),
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            error!,
                            style: GoogleFonts.cairo(
                              color: const Color(0xFFDC2626),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                TextField(
                  controller: oldPassCtrl,
                  obscureText: obscureOld,
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
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscureNew,
                  style: GoogleFonts.cairo(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور الجديدة (6 أحرف أو أكثر)',
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
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPassCtrl,
                  obscureText: obscureConfirm,
                  style: GoogleFonts.cairo(fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'تأكيد كلمة المرور الجديدة',
                    labelStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFD49B1A)),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5)),
                  ),
                ),
                const SizedBox(height: 20),
                GlassButton(
                  onPressed: loading
                      ? null
                      : () async {
                          final oldP = oldPassCtrl.text.trim();
                          final newP = newPassCtrl.text.trim();
                          final confP = confirmPassCtrl.text.trim();

                          if (oldP.isEmpty || newP.isEmpty || confP.isEmpty) {
                            setModalState(() => error = 'يرجى ملء جميع الحقول المطلوبة');
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

                          final res = await _authService.reauthenticateAndChangePassword(
                            currentPassword: oldP,
                            newPassword: newP,
                          );

                          if (!mounted) return;
                          setModalState(() => loading = false);

                          if (res['success'] == true) {
                            if (modalCtx.mounted) Navigator.pop(modalCtx);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'تم تغيير كلمة المرور لحساب المشرف بنجاح!',
                                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          } else {
                            setModalState(() => error = res['error'] ?? 'تعذر تغيير كلمة المرور');
                          }
                        },
                  text: 'حفظ كلمة المرور الجديدة',
                  icon: Icons.check_circle_rounded,
                  textColor: Colors.white,
                  backgroundColor: const Color(0xFF0B2A5B),
                  borderColor: const Color(0xFFD49B1A).withValues(alpha: 0.4),
                  height: 48,
                  isLoading: loading,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS & DIALOGS
  // ─────────────────────────────────────────────────────────────
  Widget _buildAvatarWidget(String? base64, String? url, String name, double size) {
    return GestureDetector(
      onTap: () {
        if ((base64 != null && base64.isNotEmpty) || (url != null && url.isNotEmpty)) {
          ProfileDetailsModal.openPhotoViewer(
            context,
            name: name,
            photoBase64: base64,
            photoUrl: url,
            subtitle: 'صورة الحساب الشخصية',
          );
        }
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFFFBEB),
          border: Border.all(color: const Color(0xFF0B2A5B), width: 1.5),
        ),
        child: ClipOval(
          child: base64 != null && base64.isNotEmpty
              ? Image.memory(
                  base64Decode(base64),
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Center(
                    child: Text(name.isNotEmpty ? name[0] : '؟', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                )
              : (url != null && url.isNotEmpty
                  ? (url.startsWith('http')
                      ? Image.network(url, width: size, height: size, fit: BoxFit.cover)
                      : Image.file(File(url), width: size, height: size, fit: BoxFit.cover))
                  : Center(
                      child: Text(name.isNotEmpty ? name[0] : '؟', style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold)),
                    )),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required String title}) {
    return Text(
      title,
      style: GoogleFonts.cairo(
        fontSize: 16.5,
        fontWeight: FontWeight.w800,
        color: const Color(0xFF0B2A5B),
      ),
    );
  }

  Widget _buildEmptyPlaceholder({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 36, color: color.withValues(alpha: 0.6)),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminDrawer() {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 16, 20, 22),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF090D1A), Color(0xFF131D38)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppLogoBadge(height: 38, withPillBackground: true),
                const SizedBox(height: 12),
                Text(
                  'لوحة تحكم المشرف العام',
                  style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'إدارة كافة عمليات وتراخيص منصة محاميك',
                  style: GoogleFonts.cairo(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _displayAdminPhone,
                        textDirection: TextDirection.ltr,
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildDrawerTile(
                  icon: Icons.dashboard_rounded,
                  title: 'الرئيسية (لوحة المؤشرات)',
                  subtitle: 'إحصائيات المنصة والطلبات المعلقة',
                  isSelected: _currentIndex == 0,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.manage_accounts_rounded,
                  title: 'إدارة الحسابات (حسابات)',
                  subtitle: 'تغيير كلمة السر، إيقاف/تنشيط، وحذف',
                  isSelected: _currentIndex == 1,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 1);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.people_alt_rounded,
                  title: 'سجل المستخدمين (المستخدمين)',
                  subtitle: 'سجل المحامين والعملاء المعتمدين',
                  isSelected: _currentIndex == 2,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 2);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.mail_rounded,
                  title: 'رسائل التواصل والدعم',
                  subtitle: 'استفسارات ومراسلات مستخدمي المنصة',
                  isSelected: false,
                  trailing: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('support_messages')
                        .where('status', isEqualTo: 'unread')
                        .snapshots(),
                    builder: (context, snap) {
                      final count = snap.data?.docs.length ?? 0;
                      if (count == 0) return const SizedBox.shrink();
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$count',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminSupportMessagesScreen()),
                    );
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.settings_rounded,
                  title: 'الإعدادات والمشرفين',
                  subtitle: 'صلاحيات الإدارة والتوثيق الآمن',
                  isSelected: _currentIndex == 3,
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 3);
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.lock_reset_rounded,
                  title: 'تغيير كلمة المرور',
                  subtitle: 'تحديث كلمة سر حساب المشرف الحالي',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    _showAdminChangePasswordSheet();
                  },
                ),
                _buildDrawerTile(
                  icon: Icons.notifications_active_rounded,
                  title: 'تفعيل الإشعارات العائمة',
                  subtitle: 'إظهار التنبيهات كبانر منبثق أعلى الشاشة',
                  isSelected: false,
                  onTap: () {
                    Navigator.pop(context);
                    NotificationService.openNotificationSettings();
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Divider(color: Color(0xFFE2E8F0)),
                ),
                _buildDrawerTile(
                  icon: Icons.logout_rounded,
                  title: 'تسجيل الخروج',
                  subtitle: 'إنهاء جلسة لوحة الإدارة',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmSignOut();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool isSelected = false,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFFD49B1A).withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFD49B1A).withValues(alpha: 0.35)
                    : (isDestructive ? const Color(0xFFFECDD3).withValues(alpha: 0.4) : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? const Color(0xFFFEE2E2)
                        : (isSelected
                            ? const Color(0xFFD49B1A).withValues(alpha: 0.2)
                            : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isDestructive
                        ? const Color(0xFFDC2626)
                        : (isSelected ? const Color(0xFFD97706) : const Color(0xFF475569)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                          color: isDestructive
                              ? const Color(0xFFDC2626)
                              : (isSelected ? const Color(0xFF0B2A5B) : const Color(0xFF334155)),
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: GoogleFonts.cairo(
                            fontSize: 10.5,
                            color: const Color(0xFF94A3B8),
                            height: 1.1,
                          ),
                        ),
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// تبديل حالة المحامي بين التنشيط والإيقاف
  Future<void> _toggleLawyerStatus(LawyerModel l) async {
    final messenger = ScaffoldMessenger.of(context);
    final willSuspend = !l.isSuspended;

    try {
      if (willSuspend) {
        await _firestoreService.suspendLawyer(l.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم إيقاف حساب المحامي: ${l.name}', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      } else {
        await _firestoreService.activateLawyer(l.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم تنشيط حساب المحامي: ${l.name} بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة المحامي: $e', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  /// تأكيد وحذف المحامي نهائياً
  Future<void> _confirmDeleteLawyer(LawyerModel l) async {
    final confirmed = await AppDialog.deleteConfirm(
      context,
      title: 'حذف المحامي نهائياً',
      message: 'هل أنت متأكد من رغبتك في حذف حساب المحامي (${l.name}) نهائياً؟ سيتم مسح بيانات وملف المحامي بالكامل ولا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'تأكيد الحذف',
      cancelLabel: 'إلغاء',
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _firestoreService.deleteLawyer(l.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم حذف حساب المحامي بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('فشل حذف حساب المحامي: $e', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  /// تبديل حالة العميل بين التنشيط والإيقاف
  Future<void> _toggleClientStatus(UserModel u) async {
    final messenger = ScaffoldMessenger.of(context);
    final willSuspend = !u.isSuspended;

    try {
      if (willSuspend) {
        await _firestoreService.suspendClient(u.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم إيقاف حساب العميل: ${u.name}', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      } else {
        await _firestoreService.activateClient(u.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم إعادة تنشيط حساب العميل: ${u.name} بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة العميل: $e', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  /// تأكيد وحذف العميل نهائياً
  void _confirmDeleteClient(UserModel u) {
    showDialog(
      context: context,
      builder: (dlgCtx) => Dialog(
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
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 30),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'تأكيد حذف العميل',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: const Color(0xFF0B2A5B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'هل أنت متأكد من رغبتك في حذف حساب العميل (${u.name}) نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
                style: GoogleFonts.cairo(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(dlgCtx),
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
                      onPressed: () async {
                        Navigator.pop(dlgCtx);
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          await _firestoreService.deleteClient(u.uid);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('تم حذف حساب العميل بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                              backgroundColor: const Color(0xFF10B981),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('فشل حذف حساب العميل: $e', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                              backgroundColor: const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('حذف نهائي', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13)),
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
                'هل أنت متأكد من رغبتك في الخروج من لوحة تحكم المشرف؟',
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
                        // 1. Immediately cancel listeners and disable auth guard
                        _isLoggingOut = true;
                        _supportMessagesSub?.cancel();
                        _supportMessagesSub = null;
                        _passwordResetsSub?.cancel();
                        _passwordResetsSub = null;
                        _pendingLawyersSub?.cancel();
                        _pendingLawyersSub = null;

                        // 2. Pop dialog and navigate away with smooth slide transition
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
}
