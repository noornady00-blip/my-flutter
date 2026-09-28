// ==============================================================================
// 💬 ADMIN DIRECT MESSAGES SCREEN
// ==============================================================================
// A standard chat inbox for Platform Administrators — shows only their own
// direct conversations, supports pinning, stopping, searching, and swipe actions,
// exactly matching the Lawyer / Client chat experience.
// ==============================================================================

import 'package:flutter/material.dart';

import '../../../network/auth_service.dart';
import '../../../core/utils/account_id_utils.dart';
import '../chat/chat_list_screen.dart';

class AdminChatManagementScreen extends StatefulWidget {
  const AdminChatManagementScreen({super.key});

  @override
  State<AdminChatManagementScreen> createState() =>
      _AdminChatManagementScreenState();
}

class _AdminChatManagementScreenState
    extends State<AdminChatManagementScreen> {
  final AuthService _authService = AuthService();

  String? _adminUid;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAdminSession();
  }

  Future<void> _loadAdminSession() async {
    final session = await _authService.getSavedSession();
    final user = _authService.currentUser;

    final uid = session['uid'] ?? user?.uid;
    final accountId = session['accountId'] ?? '';

    if (!mounted) return;
    setState(() {
      _adminUid = uid;
      _loaded = true;
    });

    if (uid != null && accountId.isEmpty) {
      AccountIdUtils.ensureUserHasAccountId(uid: uid, role: 'admin');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return ChatListScreen(
      initialUserId: _adminUid,
      initialRole: 'admin',
      isEmbeddedInNav: false,
    );
  }
}
