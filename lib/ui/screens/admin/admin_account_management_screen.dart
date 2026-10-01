import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/search_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/image_utils.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../../data/models/lawyer.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/password_reset_model.dart';
import '../../../network/firestore_service.dart';
import '../../../network/auth_service.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/app_dialog.dart';
import '../../custom_widgets/profile_details_modal.dart';
import '../../custom_widgets/account_role_badge.dart';

// ============================================================================
// AdminAccountManagementScreen
// Comprehensive account ledger for managing users & lawyers, suspension toggles,
// password resets, and account deletion.
// ============================================================================

class AdminAccountManagementScreen extends StatefulWidget {
  final String? initialFilter; // 'all' | 'lawyers' | 'clients' | 'suspended'

  const AdminAccountManagementScreen({super.key, this.initialFilter});

  @override
  State<AdminAccountManagementScreen> createState() => _AdminAccountManagementScreenState();
}

class _AdminAccountManagementScreenState extends State<AdminAccountManagementScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchCtrl = TextEditingController();

  String _searchQuery = '';
  late String _activeFilter; // 'all', 'lawyers', 'clients', 'suspended'
  String _currentAdminPhone = '';

  bool get _isCurrentAdminSuperAdmin => PhoneUtils.isSuperAdminPhone(_currentAdminPhone);

  @override
  void initState() {
    super.initState();
    _firestoreService.ensurePrimaryAdminsSeeded();
    _activeFilter = widget.initialFilter ?? 'all';
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.trim().toLowerCase());
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user?.email != null) {
      _currentAdminPhone = user!.email!
          .replaceAll('@mahameek.admin.com', '')
          .replaceAll('@mahameek.client.com', '')
          .replaceAll('@mahameek.lawyer.com', '');
    }
    _authService.getSavedSession().then((session) {
      if (mounted && (session['phone'] ?? '').isNotEmpty) {
        setState(() {
          _currentAdminPhone = session['phone']!;
        });
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
            const AppLogoBadge.header(),
            Row(
              children: [
                Text(
                  'إدارة الحسابات وكلمات المرور',
                  style: GoogleFonts.cairo(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
                const SizedBox(width: 8),
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
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<List<LawyerModel>>(
          stream: _firestoreService.getAllLawyers(),
          builder: (context, lawyersSnap) {
            return StreamBuilder<List<UserModel>>(
              stream: _firestoreService.getAllClients(),
              builder: (context, clientsSnap) {
                return StreamBuilder<List<UserModel>>(
                  stream: _firestoreService.getAllAdmins(),
                  builder: (context, adminsSnap) {
                    if (lawyersSnap.connectionState == ConnectionState.waiting &&
                        clientsSnap.connectionState == ConnectionState.waiting &&
                        adminsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: headerGold),
                      );
                    }

                    final lawyers = lawyersSnap.data ?? [];
                    final clients = clientsSnap.data ?? [];
                    final admins = adminsSnap.data ?? [];

                    return CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        // 1. Search Bar & Filter Header
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildSearchInput(),
                                const SizedBox(height: 12),
                                _buildFilterChips(lawyers: lawyers, clients: clients, admins: admins),
                                const SizedBox(height: 10),
                                _buildAddAdminButton(),
                                const SizedBox(height: 10),
                                _buildStatsOverview(lawyers: lawyers, clients: clients, admins: admins),
                                const SizedBox(height: 14),
                              ],
                            ),
                          ),
                        ),

                        // 2. Account List
                        _buildAccountsList(lawyers: lawyers, clients: clients, admins: admins),

                        const SliverToBoxAdapter(
                          child: SizedBox(height: 40),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ADD ADMIN BUTTON
  // ─────────────────────────────────────────────────────────────
  Widget _buildAddAdminButton() {
    if (!_isCurrentAdminSuperAdmin) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0B2A5B), Color(0xFF1E3A8A)],
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddAdminDialog(),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add_moderator_rounded, color: Color(0xFFD49B1A), size: 18),
                const SizedBox(width: 8),
                Text(
                  'إضافة مشرف جديد للنظام',
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // SEARCH BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchInput() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchCtrl,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(
          hintText: 'ابحث بالاسم، رقم الهاتف، أو المعرّف (12 رقم)...',
          hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFD49B1A)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                  onPressed: () => _searchCtrl.clear(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FILTER CHIPS
  // ─────────────────────────────────────────────────────────────
  Widget _buildFilterChips({
    required List<LawyerModel> lawyers,
    required List<UserModel> clients,
    required List<UserModel> admins,
  }) {
    final suspendedLawyers = lawyers.where((l) => l.isSuspended).length;
    final suspendedClients = clients.where((c) => c.isSuspended).length;
    final suspendedAdmins = _isCurrentAdminSuperAdmin ? admins.where((a) => a.isSuspended).length : 0;
    final totalSuspended = suspendedLawyers + suspendedClients + suspendedAdmins;
    final totalAll = lawyers.length + clients.length + (_isCurrentAdminSuperAdmin ? admins.length : 0);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      reverse: true,
      child: Row(
        children: [
          _buildChip('all', 'الكل ($totalAll)'),
          if (_isCurrentAdminSuperAdmin) ...[
            const SizedBox(width: 8),
            _buildChip('admins', 'المشرفون (${admins.length})'),
          ],
          const SizedBox(width: 8),
          _buildChip('lawyers', 'المحامون (${lawyers.length})'),
          const SizedBox(width: 8),
          _buildChip('clients', 'العملاء (${clients.length})'),
          const SizedBox(width: 8),
          _buildChip('suspended', 'الموقوفون ($totalSuspended)', isDanger: true),
        ],
      ),
    );
  }

  Widget _buildChip(String key, String label, {bool isDanger = false}) {
    final isSelected = _activeFilter == key;
    return InkWell(
      onTap: () => setState(() => _activeFilter = key),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDanger ? const Color(0xFFE11D48) : const Color(0xFF0B2A5B))
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? Colors.transparent
                : (isDanger ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0)),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: (isDanger ? const Color(0xFFE11D48) : const Color(0xFF0B2A5B))
                        .withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? Colors.white
                : (isDanger ? const Color(0xFFE11D48) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // STATS OVERVIEW CARDS
  // ─────────────────────────────────────────────────────────────
  Widget _buildStatsOverview({
    required List<LawyerModel> lawyers,
    required List<UserModel> clients,
    required List<UserModel> admins,
  }) {
    final activeLawyers = lawyers.where((l) => l.isApproved).length;
    final activeClients = clients.where((c) => c.isActive).length;
    final activeAdmins = _isCurrentAdminSuperAdmin ? admins.where((a) => !a.isSuspended).length : 0;
    final suspendedLawyers = lawyers.where((l) => l.isSuspended).length;
    final suspendedClients = clients.where((c) => c.isSuspended).length;
    final suspendedAdmins = _isCurrentAdminSuperAdmin ? admins.where((a) => a.isSuspended).length : 0;
    final totalAdmins = _isCurrentAdminSuperAdmin ? admins.length : 0;

    return Row(
      children: [
        Expanded(
          child: _buildMiniStat(
            title: 'حسابات نشطة',
            count: activeLawyers + activeClients + activeAdmins,
            color: const Color(0xFF059669),
            bg: const Color(0xFFECFDF5),
            icon: Icons.check_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat(
            title: 'حسابات موقوفة',
            count: suspendedLawyers + suspendedClients + suspendedAdmins,
            color: const Color(0xFFE11D48),
            bg: const Color(0xFFFFF1F2),
            icon: Icons.pause_circle_outline_rounded,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildMiniStat(
            title: 'إجمالي المسجلين',
            count: lawyers.length + clients.length + totalAdmins,
            color: const Color(0xFF0B2A5B),
            bg: const Color(0xFFF1F5F9),
            icon: Icons.groups_rounded,
          ),
        ),
      ],
    );
  }


  Widget _buildMiniStat({
    required String title,
    required int count,
    required Color color,
    required Color bg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            title,
            style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ACCOUNTS LIST SLIVER
  // ─────────────────────────────────────────────────────────────
  Widget _buildAccountsList({
    required List<LawyerModel> lawyers,
    required List<UserModel> clients,
    required List<UserModel> admins,
  }) {
    // If not super admin and viewing admins tab:
    if (!_isCurrentAdminSuperAdmin && _activeFilter == 'admins') {
      return SliverToBoxAdapter(
        child: _buildSuperAdminOnlyPlaceholder(),
      );
    }

    // 1. Filter Admins (Only for Super Admins)
    List<UserModel> filteredAdmins = [];
    if (_isCurrentAdminSuperAdmin && (_activeFilter == 'all' || _activeFilter == 'admins' || _activeFilter == 'suspended')) {
      filteredAdmins = admins.where((a) {
        if (_activeFilter == 'suspended' && !a.isSuspended) return false;
        return AppSearchUtils.matchesAny(_searchQuery, [
          a.name,
          a.phone,
          a.accountId,
        ]);
      }).toList();
    }

    // 2. Filter Lawyers
    List<LawyerModel> filteredLawyers = [];
    if (_activeFilter == 'all' || _activeFilter == 'lawyers' || _activeFilter == 'suspended') {
      filteredLawyers = lawyers.where((l) {
        if (_activeFilter == 'suspended' && !l.isSuspended) return false;
        return AppSearchUtils.matchesAny(_searchQuery, [
          l.name,
          l.phone,
          l.city,
          l.accountId,
        ]);
      }).toList();
    }

    // 3. Filter Clients
    List<UserModel> filteredClients = [];
    if (_activeFilter == 'all' || _activeFilter == 'clients' || _activeFilter == 'suspended') {
      filteredClients = clients.where((c) {
        if (_activeFilter == 'suspended' && !c.isSuspended) return false;
        return AppSearchUtils.matchesAny(_searchQuery, [
          c.name,
          c.phone,
          c.accountId,
        ]);
      }).toList();
    }

    final totalCount = filteredAdmins.length + filteredLawyers.length + filteredClients.length;

    if (totalCount == 0) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.search_off_rounded, color: Color(0xFF94A3B8), size: 32),
              ),
              const SizedBox(height: 14),
              Text(
                'لم يتم العثور على أي حساب يطابق البحث',
                style: GoogleFonts.cairo(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            // Render order: Admins first, then Lawyers, then Clients
            if (index < filteredAdmins.length) {
              final admin = filteredAdmins[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildAdminAccountCard(admin),
              );
            } else if (index < filteredAdmins.length + filteredLawyers.length) {
              final lawyer = filteredLawyers[index - filteredAdmins.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildLawyerAccountCard(lawyer),
              );
            } else {
              final client = filteredClients[index - filteredAdmins.length - filteredLawyers.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildClientAccountCard(client),
              );
            }
          },
          childCount: totalCount,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LAWYER ACCOUNT CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildLawyerAccountCard(LawyerModel l) {
    final bool isApproved = l.isApproved;
    final bool isSuspended = l.isSuspended;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuspended
              ? const Color(0xFFFDA4AF)
              : (isApproved ? const Color(0xFFE2E8F0) : const Color(0xFFFED7AA)),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Role Badge + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const AccountRoleBadge(role: 'lawyer'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isApproved
                      ? const Color(0xFFECFDF5)
                      : (isSuspended ? const Color(0xFFFFF1F2) : const Color(0xFFFEF2F2)),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isApproved
                        ? const Color(0xFF10B981).withValues(alpha: 0.3)
                        : (isSuspended ? const Color(0xFFE11D48).withValues(alpha: 0.3) : const Color(0xFFEF4444)),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isApproved
                            ? const Color(0xFF10B981)
                            : (isSuspended ? const Color(0xFFE11D48) : const Color(0xFFEF4444)),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isApproved ? 'نشط' : (isSuspended ? 'موقف' : 'مرفوض'),
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isApproved
                            ? const Color(0xFF059669)
                            : (isSuspended ? const Color(0xFFE11D48) : const Color(0xFFDC2626)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Lawyer Profile Details
          Row(
            textDirection: TextDirection.rtl,
            children: [
              GestureDetector(
                onTap: () => ProfileDetailsModal.showLawyerModal(context, lawyer: l, isAdmin: true),
                onLongPress: () {
                  if ((l.photoBase64 != null && l.photoBase64!.isNotEmpty) ||
                      (l.photoUrl != null && l.photoUrl!.isNotEmpty)) {
                    ProfileDetailsModal.openPhotoViewer(
                      context,
                      name: l.name,
                      photoBase64: l.photoBase64,
                      photoUrl: l.photoUrl,
                      subtitle: 'محامٍ ومستشار قانوني',
                    );
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0B2A5B),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildLawyerAvatarContent(l),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.name,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                    Text(
                      'محامٍ ومستشار قانوني • ${l.city}',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '📞 ${l.phone}',
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF0B2A5B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (l.accountId.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: l.accountId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ معرّف الحساب')),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFFD49B1A)),
                            ),
                          ),
                          Text(
                            AccountIdUtils.format12Digits(l.accountId),
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B2A5B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '🆔 المعرّف:',
                            style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Action Buttons: Change Password | Suspend / Activate | Delete
          Row(
            children: [
              // 1. Change Password Action
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: () => _showChangePasswordDialog(phone: l.phone, name: l.name, uid: l.uid),
                  icon: const Icon(Icons.key_rounded, size: 15, color: Color(0xFFD49B1A)),
                  label: Text(
                    'كلمة السر',
                    style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Suspend / Activate Toggle
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: () => _toggleLawyerStatus(l),
                  icon: Icon(
                    isSuspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 16,
                    color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                  ),
                  label: Text(
                    isSuspended ? 'تنشيط' : 'إيقاف',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. Delete Action
              IconButton(
                onPressed: () => _confirmDeleteLawyer(l),
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                tooltip: 'حذف المحامي نهائياً',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CLIENT ACCOUNT CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildClientAccountCard(UserModel c) {
    final bool isSuspended = c.isSuspended;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuspended ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Role Badge + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const AccountRoleBadge(role: 'client'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isSuspended ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSuspended
                        ? const Color(0xFFE11D48).withValues(alpha: 0.3)
                        : const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSuspended ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isSuspended ? 'موقف' : 'نشط',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isSuspended ? const Color(0xFFE11D48) : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Client Details
          Row(
            textDirection: TextDirection.rtl,
            children: [
              GestureDetector(
                onTap: () => ProfileDetailsModal.showClientModal(context, client: c, isAdmin: true),
                onLongPress: () {
                  if ((c.photoBase64 != null && c.photoBase64!.isNotEmpty) ||
                      (c.photoUrl != null && c.photoUrl!.isNotEmpty)) {
                    ProfileDetailsModal.openPhotoViewer(
                      context,
                      name: c.name,
                      photoBase64: c.photoBase64,
                      photoUrl: c.photoUrl,
                      subtitle: 'عميل مسجل في المنصة',
                    );
                  }
                },
                child: Container(
                  width: 50,
                  height: 50,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF0B2A5B),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildClientAvatarContent(c),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.name,
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                    Text(
                      '📞 ${c.phone}',
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF0B2A5B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (c.accountId.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: c.accountId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ معرّف الحساب')),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFFD49B1A)),
                            ),
                          ),
                          Text(
                            AccountIdUtils.format12Digits(c.accountId),
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B2A5B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '🆔 المعرّف:',
                            style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              // 1. Change Password
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: () => _showChangePasswordDialog(phone: c.phone, name: c.name, uid: c.uid),
                  icon: const Icon(Icons.key_rounded, size: 15, color: Color(0xFFD49B1A)),
                  label: Text(
                    'كلمة السر',
                    style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Suspend / Activate
              Expanded(
                flex: 4,
                child: OutlinedButton.icon(
                  onPressed: () => _toggleClientStatus(c),
                  icon: Icon(
                    isSuspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
                    size: 16,
                    color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                  ),
                  label: Text(
                    isSuspended ? 'تنشيط' : 'إيقاف',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. Delete Client
              IconButton(
                onPressed: () => _confirmDeleteClient(c),
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                tooltip: 'حذف العميل نهائياً',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // ADMIN ACCOUNT CARD
  // ─────────────────────────────────────────────────────────────
  Widget _buildAdminAccountCard(UserModel a) {
    final bool isSuspended = a.isSuspended;
    final bool isPrimary = PhoneUtils.isSuperAdminPhone(a.phone) || a.isPrimary;
    final bool isSelf = PhoneUtils.normalize(_currentAdminPhone) == PhoneUtils.normalize(a.phone);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSuspended ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Role Badge + Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              const AccountRoleBadge(role: 'admin'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: isSuspended ? const Color(0xFFFFF1F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSuspended
                        ? const Color(0xFFE11D48).withValues(alpha: 0.3)
                        : const Color(0xFF10B981).withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSuspended ? const Color(0xFFE11D48) : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isSuspended ? 'موقف' : (isPrimary ? 'مشرف رئيسي' : 'نشط'),
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isSuspended ? const Color(0xFFE11D48) : const Color(0xFF059669),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Admin Details
          Row(
            textDirection: TextDirection.rtl,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0B2A5B),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.shield_rounded, color: Color(0xFFD49B1A), size: 26),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name.isNotEmpty ? a.name : 'مشرف النظام',
                      style: GoogleFonts.cairo(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                    Text(
                      '📞 ${a.phone}',
                      textDirection: TextDirection.ltr,
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: const Color(0xFF0B2A5B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (a.accountId.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: a.accountId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم نسخ معرّف الحساب')),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.copy_rounded, size: 13, color: Color(0xFFD49B1A)),
                            ),
                          ),
                          Text(
                            AccountIdUtils.format12Digits(a.accountId),
                            style: GoogleFonts.sourceCodePro(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF0B2A5B),
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '🆔 المعرّف:',
                            style: GoogleFonts.cairo(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          const SizedBox(height: 12),

          // Actions
          Row(
            children: [
              // 1. Change Password
              Expanded(
                flex: 4,
                child: ElevatedButton.icon(
                  onPressed: () {
                    if (isPrimary && !isSelf) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'لا يمكن تعديل كلمة سر المشرف الأساسي إلا بواسطة صاحب الحساب نفسه',
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                          ),
                          backgroundColor: const Color(0xFF0B2A5B),
                        ),
                      );
                      return;
                    }
                    _showChangePasswordDialog(phone: a.phone, name: a.name, uid: a.uid);
                  },
                  icon: Icon(
                    isPrimary ? Icons.lock_outline_rounded : Icons.key_rounded,
                    size: 15,
                    color: const Color(0xFFD49B1A),
                  ),
                  label: Text(
                    isPrimary ? 'محمي (ذاتي)' : 'كلمة السر',
                    style: GoogleFonts.cairo(fontSize: 11.5, fontWeight: FontWeight.w800),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Suspend / Activate (Only for non-primary admins)
              if (!isPrimary) ...[
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleAdminStatus(a),
                    icon: Icon(
                      isSuspended ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 16,
                      color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                    ),
                    label: Text(
                      isSuspended ? 'تنشيط' : 'إيقاف',
                      style: GoogleFonts.cairo(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isSuspended ? const Color(0xFF10B981) : const Color(0xFFE11D48),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                // 3. Delete Admin
                IconButton(
                  onPressed: () => _confirmDeleteAdmin(a),
                  icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 22),
                  tooltip: 'حذف المشرف نهائياً',
                ),
              ] else ...[
                Expanded(
                  flex: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_user_rounded, size: 14, color: Color(0xFFD49B1A)),
                        const SizedBox(width: 4),
                        Text(
                          'مشرف أساسي محمي',
                          style: GoogleFonts.cairo(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2A5B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // DIALOGS & ACTIONS
  // ─────────────────────────────────────────────────────────────

  /// 1. نافذة تغيير وتعيين كلمة السر
  void _showChangePasswordDialog({required String phone, String? name, String? uid}) {
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

                // 3. User Box
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
                          PhoneUtils.toLocalDisplay(phone),
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
                                final newPass = PhoneUtils.normalize(passCtrl.text.trim());
                                if (newPass.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف', style: GoogleFonts.cairo()),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                  return;
                                }

                                final messenger = ScaffoldMessenger.of(context);
                                final nav = Navigator.of(dlgCtx);
                                setDlgState(() => isSaving = true);
                                final res = await _authService.adminResetUserPassword(
                                  phone: phone,
                                  newPassword: newPass,
                                  targetUid: uid,
                                );

                                if (!mounted) return;
                                nav.pop();

                                if (res['success'] == true) {
                                  final waPhone = PasswordResetModel.formatWhatsAppNumber(phone);
                                  final message = 'مرحباً بك،\n'
                                      'تم تعيين كلمة المرور لحسابك في تطبيق محاميك بنجاح.\n\n'
                                      '🔑 كلمة المرور: $newPass\n'
                                      '📱 رقم الدخول: $phone\n\n'
                                      'يمكنك الآن تسجيل الدخول مباشرة.';
                                  final waUri = Uri.parse('https://wa.me/$waPhone?text=${Uri.encodeComponent(message)}');

                                  // Copy to clipboard automatically
                                  await Clipboard.setData(ClipboardData(text: message));

                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text('تم تعيين كلمة المرور بنجاح ونسخها للحافظة!', style: GoogleFonts.cairo()),
                                      backgroundColor: const Color(0xFF10B981),
                                      action: SnackBarAction(
                                        label: 'إرسال عبر واتساب',
                                        textColor: Colors.white,
                                        onPressed: () => launchUrl(waUri, mode: LaunchMode.externalApplication),
                                      ),
                                    ),
                                  );
                                } else {
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(res['error'] ?? 'فشل تعيين كلمة المرور', style: GoogleFonts.cairo()),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
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

  /// 2. تبديل حالة المحامي (تنشيط / إيقاف)
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

  /// 3. تبديل حالة العميل (تنشيط / إيقاف)
  Future<void> _toggleClientStatus(UserModel c) async {
    final messenger = ScaffoldMessenger.of(context);
    final willSuspend = !c.isSuspended;

    try {
      if (willSuspend) {
        await _firestoreService.suspendClient(c.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم إيقاف حساب العميل: ${c.name}', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      } else {
        await _firestoreService.activateClient(c.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم إعادة تنشيط حساب العميل: ${c.name} بنجاح', style: GoogleFonts.cairo()),
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

  /// 4. تأكيد وحذف المحامي نهائياً
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

  /// 5. تأكيد وحذف العميل نهائياً
  Future<void> _confirmDeleteClient(UserModel c) async {
    final confirmed = await AppDialog.deleteConfirm(
      context,
      title: 'حذف العميل نهائياً',
      message: 'هل أنت متأكد من رغبتك في حذف حساب العميل (${c.name}) نهائياً؟ سيتم مسح بيانات الحساب ولا يمكن التراجع عن هذا الإجراء.',
      confirmLabel: 'تأكيد الحذف',
      cancelLabel: 'إلغاء',
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _firestoreService.deleteClient(c.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم حذف حساب العميل بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('فشل حذف حساب العميل: $e', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  /// 6. نافذة إضافة مشرف جديد للنظام
  void _showAddAdminDialog() {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: '123456');
    bool isSaving = false;
    bool obscurePass = true;

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          elevation: 16,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0B2A5B), width: 1.5),
                      ),
                      child: const Center(
                        child: Icon(Icons.shield_rounded, color: Color(0xFFD49B1A), size: 30),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'إضافة مشرف جديد للنظام',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.w900,
                      fontSize: 17,
                      color: const Color(0xFF0B2A5B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'سيتم منح هذا الحساب صلاحيات الإشراف الإداري على المنصة',
                    style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF64748B)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Name Field
                  TextField(
                    controller: nameCtrl,
                    textDirection: TextDirection.rtl,
                    decoration: InputDecoration(
                      labelText: 'الاسم الكامل للمشرف',
                      labelStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF0B2A5B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Phone Field
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'رقم هاتف المشرف (11 رقم)',
                      hintText: '011XXXXXXXX',
                      labelStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF0B2A5B)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Password Field
                  TextField(
                    controller: passCtrl,
                    obscureText: obscurePass,
                    textDirection: TextDirection.ltr,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      labelStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                      prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF0B2A5B)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                          color: const Color(0xFF94A3B8),
                        ),
                        onPressed: () => setDlgState(() => obscurePass = !obscurePass),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
                    ),
                  ),
                  const SizedBox(height: 18),

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
                                  final name = nameCtrl.text.trim();
                                  final phone = phoneCtrl.text.trim();
                                  final pass = passCtrl.text.trim();

                                  if (name.isEmpty || phone.isEmpty || pass.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('يرجى ملء جميع الحقول المطلوبة', style: GoogleFonts.cairo()),
                                        backgroundColor: const Color(0xFFDC2626),
                                      ),
                                    );
                                    return;
                                  }

                                  if (pass.length < 6) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('كلمة المرور يجب ألا تقل عن 6 أحرف', style: GoogleFonts.cairo()),
                                        backgroundColor: const Color(0xFFDC2626),
                                      ),
                                    );
                                    return;
                                  }

                                  setDlgState(() => isSaving = true);
                                  final res = await _authService.createAdminAccount(
                                    name: name,
                                    phone: phone,
                                    password: pass,
                                  );

                                  if (!mounted) return;
                                  setDlgState(() => isSaving = false);

                                  if (res['success'] == true) {
                                    if (dlgCtx.mounted) {
                                      Navigator.pop(dlgCtx);
                                    }
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['message']?.toString() ?? 'تم إضافة المشرف واعتماده بنجاح', style: GoogleFonts.cairo()),
                                        backgroundColor: const Color(0xFF10B981),
                                      ),
                                    );
                                  } else {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(res['error']?.toString() ?? 'تعذر إضافة حساب المشرف', style: GoogleFonts.cairo()),
                                        backgroundColor: const Color(0xFFDC2626),
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0B2A5B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: isSaving
                              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : Text('حفظ واعتماد', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13.5)),
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

  /// 7. تبديل حالة المشرف (تنشيط / إيقاف)
  Future<void> _toggleAdminStatus(UserModel a) async {
    if (PhoneUtils.isSuperAdminPhone(a.phone) || a.isPrimary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن إيقاف الحساب الأساسي للمشرف', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    final willSuspend = !a.isSuspended;

    try {
      if (willSuspend) {
        await _firestoreService.suspendAdmin(a.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم إيقاف حساب المشرف: ${a.name}', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFE11D48),
          ),
        );
      } else {
        await _firestoreService.activateAdmin(a.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم تنشيط حساب المشرف: ${a.name} بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('فشل تحديث حالة المشرف: $e', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  /// 8. تأكيد وحذف المشرف نهائياً
  Future<void> _confirmDeleteAdmin(UserModel a) async {
    if (PhoneUtils.isSuperAdminPhone(a.phone) || a.isPrimary) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('لا يمكن حذف الحساب الأساسي للمشرف', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    final confirmed = await AppDialog.deleteConfirm(
      context,
      title: 'حذف المشرف نهائياً',
      message: 'هل أنت متأكد من رغبتك في حذف حساب المشرف (${a.name}) نهائياً؟ سيتم إلغاء صلاحياته الإدارية فوراً.',
      confirmLabel: 'تأكيد الحذف',
      cancelLabel: 'إلغاء',
    );

    if (confirmed == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      try {
        await _firestoreService.deleteAdmin(a.uid);
        messenger.showSnackBar(
          SnackBar(
            content: Text('تم حذف حساب المشرف بنجاح', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('فشل حذف حساب المشرف: $e', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Widget _buildLawyerAvatarContent(LawyerModel l) {
    return AppImageUtils.buildAvatarImage(
      photoBase64: l.photoBase64,
      photoUrl: l.photoUrl,
      fallback: _buildFallbackLetter(l.name, const Color(0xFFFFFBEB), const Color(0xFFD49B1A)),
    );
  }

  Widget _buildClientAvatarContent(UserModel c) {
    return AppImageUtils.buildAvatarImage(
      photoBase64: c.photoBase64,
      photoUrl: c.photoUrl,
      fallback: _buildFallbackLetter(c.name, const Color(0xFFEFF6FF), const Color(0xFF2563EB)),
    );
  }

  Widget _buildFallbackLetter(String name, Color bg, Color textCol) {
    final letter = name.trim().isNotEmpty ? name.trim().characters.first : 'م';
    return Container(
      color: bg,
      child: Center(
        child: Text(
          letter,
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.w900,
            fontSize: 18,
            color: textCol,
          ),
        ),
      ),
    );
  }

  Widget _buildSuperAdminOnlyPlaceholder() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0B2A5B), Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.lock_person_rounded, size: 40, color: Color(0xFFD49B1A)),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'هذه الصفحة مخصصة للأدمن الأساسي فقط',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF0B2A5B),
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'عذراً، الوصول إلى سجل المشرفين وإدارة حساباتهم محصور حصرياً بالمشرفين الأساسيين للنظام.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, size: 15, color: Color(0xFFD49B1A)),
                const SizedBox(width: 6),
                Text(
                  'صلاحيات إدارية خاصة',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
