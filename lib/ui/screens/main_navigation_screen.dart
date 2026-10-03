import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../network/auth_service.dart';
import '../../network/chat_service.dart';
import '../../core/services/keep_alive_service.dart';
import '../custom_widgets/floating_nav_bar.dart';
import '../custom_widgets/account_suspended_dialog.dart';
import '../custom_widgets/app_drawer.dart';
import 'cities/cities_screen.dart';
import 'lawyers/all_lawyers_screen.dart';
import 'profile/profile_screen.dart';
import 'lawyer/lawyer_home_screen.dart';
import 'lawyer/lawyer_settings_screen.dart';
import 'chat/chat_list_screen.dart';
import 'onboarding/onboarding_screen.dart';
import 'admin/admin_dashboard.dart';

// ============================================================================
// MainNavigationScreen
// Primary shell containing responsive floating bottom navigation bar,
// drawer management, role resolution (Client / Lawyer), and suspension check.
// ============================================================================

class MainNavigationScreen extends StatefulWidget {
  final int initialIndex;
  final String? role; // 'lawyer' | 'client'

  const MainNavigationScreen({
    super.key,
    this.initialIndex = 0,
    this.role,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late int _currentIndex;
  String _role = 'client';

  final List<FloatingNavItemData> _clientNavItems = const [
    FloatingNavItemData(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'الرئيسية',
    ),
    FloatingNavItemData(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'المحادثات',
    ),
    FloatingNavItemData(
      icon: Icons.search_rounded,
      activeIcon: Icons.search_rounded,
      label: 'بحث',
    ),
    FloatingNavItemData(
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
      label: 'حسابي',
    ),
  ];

  final List<FloatingNavItemData> _lawyerNavItems = const [
    FloatingNavItemData(
      icon: Icons.badge_outlined,
      activeIcon: Icons.badge_rounded,
      label: 'الرئيسية',
    ),
    FloatingNavItemData(
      icon: Icons.chat_bubble_outline_rounded,
      activeIcon: Icons.chat_bubble_rounded,
      label: 'المحادثات',
    ),
    FloatingNavItemData(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings_rounded,
      label: 'الإعدادات',
    ),
  ];

  @override
  void initState() {
    super.initState();
    final initialRole = widget.role;
    if (initialRole == 'admin' || initialRole == 'subadmin') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        }
      });
      return;
    }
    _currentIndex = widget.initialIndex;
    if (widget.role != null) {
      _role = widget.role!;
    } else {
      _fetchUserRole();
    }
    _checkSuspensionStatus();
    KeepAliveService().enableKeepAlive(role: _role);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkSuspensionStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final session = await AuthService().getSavedSession();
      final role = session['role'] ?? _role;
      final col = (role == 'lawyer') ? 'lawyers' : ((role == 'admin' || role == 'subadmin') ? 'admins' : 'users');
      final doc = await FirebaseFirestore.instance.collection(col).doc(user.uid).get();
      if (!doc.exists) {
        // Account was deleted in Firebase Console or by Admin!
        // Immediately sign out and do NOT resurrect/auto-heal it!
        await AuthService().signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (route) => false,
          );
        }
        return;
      } else if (doc.data()?['status'] == 'suspended' && mounted) {
        await AuthService().signOut();
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
            (_) => false,
          );
          showAccountSuspendedDialog(context);
        }
      }
    } catch (_) {}
  }

  Future<void> _fetchUserRole() async {
    final session = await AuthService().getSavedSession();
    final role = session['role'];
    if (role != null && role != _role && mounted) {
      if (role == 'admin' || role == 'subadmin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
        return;
      }
      setState(() {
        _role = role;
        if (_role == 'lawyer' && _currentIndex > 2) {
          _currentIndex = 0;
        }
      });
    }
  }

  void _onTabTapped(int index) {
    if (_currentIndex == index) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final isLawyer = _role == 'lawyer';

    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final List<Widget> pages = isLawyer
        ? [
            // Lawyer Tab 0: الرئيسية (بيانات المحامي كما تظهر للعميل مع إمكانية التعديل)
            LawyerHomeScreen(
              onNavigateSettings: () => _onTabTapped(2),
            ),
            // Lawyer Tab 1: المحادثات المباشرة مع العملاء
            ChatListScreen(
              key: ValueKey('chat_list_lawyer_$currentUid'),
              initialUserId: currentUid,
              initialRole: 'lawyer',
              isEmbeddedInNav: true,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNavigateTab: _onTabTapped,
            ),
            // Lawyer Tab 2: الإعدادات
            const LawyerSettingsScreen(),
          ]
        : [
            // Client Tab 0: الرئيسية
            CitiesScreen(
              onNavigateTab: _onTabTapped,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              isEmbeddedInNav: true,
            ),
            // Client Tab 1: المحادثات المباشرة مع المحامين
            ChatListScreen(
              key: ValueKey('chat_list_client_$currentUid'),
              initialUserId: currentUid,
              initialRole: _role,
              isEmbeddedInNav: true,
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
              onNavigateTab: _onTabTapped,
            ),
            // Client Tab 2: بحث
            AllLawyersScreen(
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            // Client Tab 3: حسابي
            ProfileScreen(
              onOpenDrawer: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          ];

    final navItems = isLawyer ? _lawyerNavItems : _clientNavItems;
    final safeIndex = _currentIndex >= pages.length ? 0 : _currentIndex;

    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        onNavigateTab: _onTabTapped,
      ),
      extendBody: true,
      body: IndexedStack(
        index: safeIndex,
        children: pages,
      ),
      bottomNavigationBar: StreamBuilder<int>(
        stream: (currentUid != null && currentUid.isNotEmpty)
            ? ChatService().getUnreadCountStream(currentUid, _role)
            : const Stream.empty(),
        initialData: 0,
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;
          final dynamicNavItems = navItems.map((item) {
            if (item.label == 'المحادثات') {
              return FloatingNavItemData(
                icon: item.icon,
                activeIcon: item.activeIcon,
                label: item.label,
                badgeCount: unreadCount,
              );
            }
            return item;
          }).toList();

          return FloatingNavBar(
            currentIndex: safeIndex,
            onTap: _onTabTapped,
            items: dynamicNavItems,
            barBackgroundColor: const Color(0xFFD49B1A), // Same as Header
            activeBgColor: Colors.white,
            activeColor: const Color(0xFF0B2A5B),
            inactiveColor: const Color(0xAA0F1B3E),
          );
        },
      ),
    );
  }
}
