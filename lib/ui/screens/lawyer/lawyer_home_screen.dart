import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/auth_service.dart';
import '../../../network/firestore_service.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/awake_badge.dart';
import '../../custom_widgets/profile_details_modal.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/account_id_utils.dart';
import '../../custom_widgets/sudan_phone_field.dart';

class LawyerHomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateSettings;
  const LawyerHomeScreen({super.key, this.onNavigateSettings});

  @override
  State<LawyerHomeScreen> createState() => _LawyerHomeScreenState();
}

class _LawyerHomeScreenState extends State<LawyerHomeScreen> {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();

  String? _uid;
  String? _cachedName;
  String? _cachedPhone;
  String? _cachedPhotoUrl;
  bool _isLoading = true;

  final List<String> _sudaneseCities = const [
    'الخرطوم',
    'أم درمان',
    'بحري',
    'بورتسودان',
    'كسلا',
    'القضارف',
    'ود مدني',
    'الأبيض',
    'الفاشر',
    'نيالا',
    'عطبرة',
    'شندي',
    'دنقلا',
    'مروي',
    'سنار',
    'الدمازين',
    'زالنجي',
    'الضعين',
    'الجنينة',
    'كادقلي',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialSession();
  }

  Future<void> _loadInitialSession() async {
    final session = await _authService.getSavedSession();
    final user = _authService.currentUser;
    setState(() {
      _uid = session['uid'] ?? user?.uid;
      _cachedName = session['name'] ?? 'الأستاذ المحامي';
      _cachedPhone = session['phone'];
      _cachedPhotoUrl = session['photoUrl'];
      _isLoading = false;
    });
  }

  Future<void> _openEditModal({
    required String title,
    required String label,
    required String initialValue,
    required IconData icon,
    required TextInputType keyboardType,
    bool isPhone = false,
    required Future<bool> Function(String value) onSave,
  }) async {
    final rawInitial = isPhone ? PhoneUtils.extractLocalSudanDigits(initialValue) : initialValue;
    final controller = TextEditingController(text: rawInitial);
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showModalBottomSheet(
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
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: const Color(0xFFD49B1A), size: 22),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        title,
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF0B2A5B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  isPhone
                      ? SudanPhoneFormField(
                          controller: controller,
                          hintText: '9XXXXXXXX',
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'يرجى إدخال الرقم';
                            if (v.trim().length < PhoneUtils.sudanPhoneLength) {
                              return 'يجب إدخال 9 أرقام (مثال: 912345678)';
                            }
                            return null;
                          },
                        )
                      : TextFormField(
                          controller: controller,
                          keyboardType: keyboardType,
                          textDirection: TextDirection.rtl,
                          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
                          decoration: InputDecoration(
                            labelText: label,
                            labelStyle: GoogleFonts.cairo(color: const Color(0xFF64748B)),
                            prefixIcon: Icon(icon, color: const Color(0xFFD49B1A), size: 20),
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
                              borderSide: const BorderSide(color: Color(0xFFD49B1A), width: 1.5),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'هذا الحقل مطلوب';
                            return null;
                          },
                        ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (!formKey.currentState!.validate()) return;
                              setModalState(() => saving = true);
                              final valToSave = isPhone
                                  ? PhoneUtils.normalizeSudanPhone(controller.text.trim())
                                  : controller.text.trim();
                              final success = await onSave(valToSave);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      success ? 'تم حفظ التعديل بنجاح' : 'تعذر الحفظ، تحقق من الاتصال بالإنترنت',
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                                    ),
                                    backgroundColor: success ? const Color(0xFF10B981) : AppTheme.error,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0B2A5B),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: saving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(
                              'حفظ التعديلات',
                              style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDropdownModal({
    required String title,
    required String currentVal,
    required List<String> options,
    required Future<bool> Function(String value) onSave,
  }) async {
    String selected = currentVal;
    bool saving = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
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
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B2A5B),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  itemCount: options.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final isSelected = opt == selected;
                    return ListTile(
                      title: Text(
                        opt,
                        style: GoogleFonts.cairo(
                          fontSize: 14,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFF0B2A5B),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: Color(0xFFD49B1A), size: 20)
                          : null,
                      onTap: () => setModalState(() => selected = opt),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setModalState(() => saving = true);
                          final success = await onSave(selected);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  success ? 'تم حفظ التعديل بنجاح' : 'تعذر الحفظ',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                                ),
                                backgroundColor: success ? const Color(0xFF10B981) : AppTheme.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text('حفظ الاختيار', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, color: Colors.white)),
                ),
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

    if (_isLoading) {
      return const Scaffold(
        backgroundColor: pageBg,
        body: Center(child: CircularProgressIndicator(color: headerGold)),
      );
    }

    if (_uid == null) {
      return Scaffold(
        backgroundColor: pageBg,
        body: Center(
          child: Text(
            'يرجى تسجيل الدخول بحساب محامي',
            style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

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
                const AppLogoBadge.header(),
                const SizedBox(width: 8),
                const Awake247Badge(),
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
                    const Icon(Icons.shield_rounded, color: Color(0xFF0B2A5B), size: 16),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'مكتب المحامي',
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
      body: StreamBuilder<LawyerModel?>(
        stream: _firestoreService.streamLawyer(_uid!),
        builder: (context, snapshot) {
          final lawyer = snapshot.data;
          final name = lawyer?.name.isNotEmpty == true ? lawyer!.name : (_cachedName ?? 'الأستاذ المحامي');
          final phone = lawyer?.phone.isNotEmpty == true ? lawyer!.phone : (_cachedPhone ?? '---');
          final whatsapp = lawyer?.whatsapp.isNotEmpty == true ? lawyer!.whatsapp : phone;
          final city = lawyer?.city.isNotEmpty == true ? lawyer!.city : 'الخرطوم';
          final accountId = lawyer?.accountId ?? '';
          final photoBase64 = lawyer?.photoBase64;
          final photoUrl = (lawyer?.photoUrl != null && lawyer!.photoUrl!.isNotEmpty)
              ? lawyer.photoUrl
              : _cachedPhotoUrl;

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 95),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Executive Hero Identity Card
                _buildExecutiveHeroCard(
                  name: name,
                  city: city,
                  accountId: accountId,
                  photoUrl: photoUrl,
                  photoBase64: photoBase64,
                  lawyer: lawyer,
                ),
                const SizedBox(height: 14),


                // 3. Client Live Interaction Preview Card
                _buildLiveClientInteractionCard(
                  phone: phone,
                  whatsapp: whatsapp,
                  lawyer: lawyer,
                ),
                const SizedBox(height: 20),

                // 4. Section Title: Direct Profile Management
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
                      'بياناتك الظاهرة للمراجعين',
                      style: GoogleFonts.cairo(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 5. Unified Data Management Suite
                _buildDataManagementSuite(
                  phone: phone,
                  whatsapp: whatsapp,
                  city: city,
                  accountId: accountId,
                ),
                const SizedBox(height: 16),

                // 6. Photo Notice Box
                _buildPhotoNoticeBox(),
              ],
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. Executive Hero Identity Card
  // ─────────────────────────────────────────────────────────────
  Widget _buildExecutiveHeroCard({
    required String name,
    required String city,
    required String accountId,
    String? photoUrl,
    String? photoBase64,
    LawyerModel? lawyer,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFF0B2A5B),
            Color(0xFF162552),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Lawyer Avatar (Long press to view photo, Tap for profile)
              GestureDetector(
                onTap: () {
                  if (lawyer != null) {
                    ProfileDetailsModal.showLawyerModal(context, lawyer: lawyer);
                  } else if ((photoUrl != null && photoUrl.isNotEmpty) ||
                      (photoBase64 != null && photoBase64.isNotEmpty)) {
                    ProfileDetailsModal.openPhotoViewer(
                      context,
                      name: name,
                      photoUrl: photoUrl,
                      photoBase64: photoBase64,
                      subtitle: city.isNotEmpty ? 'محامٍ ومستشار قانوني - $city' : 'محامٍ ومستشار قانوني',
                    );
                  }
                },
                onLongPress: () {
                  if ((photoUrl != null && photoUrl.isNotEmpty) ||
                      (photoBase64 != null && photoBase64.isNotEmpty)) {
                    ProfileDetailsModal.openPhotoViewer(
                      context,
                      name: name,
                      photoUrl: photoUrl,
                      photoBase64: photoBase64,
                      subtitle: city.isNotEmpty ? 'محامٍ ومستشار قانوني - $city' : 'محامٍ ومستشار قانوني',
                    );
                  }
                },
                child: Container(
                  width: 60,
                  height: 60,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0B2A5B), width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: _buildAvatar(photoUrl, photoBase64, name),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Name and Credentials
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: GoogleFonts.cairo(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFFD49B1A), size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD49B1A).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFD49B1A).withValues(alpha: 0.35)),
                      ),
                      child: Text(
                        'محامٍ ومستشار قانوني',
                        style: GoogleFonts.cairo(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFFD54F),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: Color(0xFF94A3B8), size: 14),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            city,
                            style: GoogleFonts.cairo(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFCBD5E1),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (accountId.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: accountId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم نسخ الـ ID الموحد (12 رقم) بنجاح',
                                  style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                              backgroundColor: const Color(0xFF0B2A5B),
                              duration: const Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFD49B1A).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.badge_rounded, color: Color(0xFFD49B1A), size: 13),
                              const SizedBox(width: 4),
                              Text(
                                'الـ ID: ${AccountIdUtils.formatForDisplay(accountId)}',
                                style: GoogleFonts.cairo(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textDirection: TextDirection.ltr,
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.copy_rounded, color: Color(0xFFD49B1A), size: 12),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0x33FFFFFF)),
          const SizedBox(height: 10),

          // Active Status Pill
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                    'عضوية محامي نشطة ومعتمدة في المنصة',
                    style: GoogleFonts.cairo(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFA7F3D0),
                    ),
                  ),
                ],
              ),
              const Icon(Icons.gavel_rounded, color: Color(0xFFD49B1A), size: 16),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. Client Live Interaction Preview Card (No Overflows)
  // ─────────────────────────────────────────────────────────────
  Widget _buildLiveClientInteractionCard({
    required String phone,
    required String whatsapp,
    LawyerModel? lawyer,
  }) {
    return Container(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility_rounded, color: Color(0xFFD49B1A), size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'تجربة قنوات التواصل للعملاء',
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                ],
              ),
              if (lawyer != null)
                InkWell(
                  onTap: () => ProfileDetailsModal.showLawyerModal(context, lawyer: lawyer),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2A5B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'معاينة البطاقة',
                      style: GoogleFonts.cairo(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFD49B1A)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Two Interactive Communication Buttons (Upgraded Luxury UI & Proper LTR Numbers)
          Row(
            children: [
              // WhatsApp Interactive
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final clean = PhoneUtils.formatWhatsAppNumber(whatsapp);
                    final uri = Uri.parse('https://wa.me/$clean');
                    if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFA7F3D0), width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF10B981),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.chat_rounded, color: Colors.white, size: 13),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            PhoneUtils.formatForDisplay(whatsapp),
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF065F46),
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Phone Call Interactive
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final cleanPhone = PhoneUtils.normalizeSudanPhone(phone, withPlus: true);
                    final uri = Uri(scheme: 'tel', path: cleanPhone);
                    if (await canLaunchUrl(uri)) launchUrl(uri);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFCBD5E1), width: 1.3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Color(0xFF0B2A5B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.phone_rounded, color: Colors.white, size: 13),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            PhoneUtils.formatForDisplay(phone),
                            textDirection: TextDirection.ltr,
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                              letterSpacing: 0.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
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

  // ─────────────────────────────────────────────────────────────
  // 3. Unified Data Management Suite (Sleek List Layout)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDataManagementSuite({
    required String phone,
    required String whatsapp,
    required String city,
    required String accountId,
  }) {
    return Container(
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
          // 0. Account ID Row
          if (accountId.isNotEmpty) ...[
            _buildSuiteRow(
              icon: Icons.badge_rounded,
              iconColor: const Color(0xFFD49B1A),
              label: 'المعرّف الموحد الرقمي (12 رقم)',
              value: AccountIdUtils.formatForDisplay(accountId),
              isPhone: false,
              onTap: () {
                Clipboard.setData(ClipboardData(text: accountId));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('تم نسخ المعرّف الموحد (12 رقم) بنجاح',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                    backgroundColor: const Color(0xFF0B2A5B),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
            const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xFFF1F5F9)),
          ],

          // 1. WhatsApp Row
          _buildSuiteRow(
            icon: Icons.chat_bubble_rounded,
            iconColor: const Color(0xFF25D366),
            label: 'رقم الواتساب المعتمد',
            value: whatsapp,
            isPhone: true,
            onTap: () => _openEditModal(
              title: 'تعديل رقم الواتساب',
              label: 'رقم الواتساب',
              initialValue: whatsapp,
              icon: Icons.chat_rounded,
              keyboardType: TextInputType.phone,
              isPhone: true,
              onSave: (val) => _firestoreService.updateLawyerProfile(uid: _uid!, whatsapp: val),
            ),
          ),
          const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xFFF1F5F9)),

          // 2. Phone Row
          _buildSuiteRow(
            icon: Icons.phone_rounded,
            iconColor: const Color(0xFF0B2A5B),
            label: 'رقم الهاتف المباشر',
            value: phone,
            isPhone: true,
            onTap: () => _openEditModal(
              title: 'تعديل رقم الهاتف',
              label: 'رقم الهاتف',
              initialValue: phone,
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              isPhone: true,
              onSave: (val) => _firestoreService.updateLawyerProfile(uid: _uid!, phone: val),
            ),
          ),
          const Divider(height: 1, indent: 54, endIndent: 16, color: Color(0xFFF1F5F9)),

          // 3. City Row
          _buildSuiteRow(
            icon: Icons.location_on_rounded,
            iconColor: const Color(0xFFDC2626),
            label: 'المدينة ومقر الممارسة',
            value: city,
            isPhone: false,
            onTap: () => _openDropdownModal(
              title: 'اختر مدينتك',
              currentVal: city,
              options: _sudaneseCities,
              onSave: (val) => _firestoreService.updateLawyerProfile(uid: _uid!, city: val),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuiteRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    bool isPhone = false,
    required VoidCallback onTap,
  }) {
    final displayValue = isPhone ? PhoneUtils.formatForDisplay(value) : value;

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
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  Text(
                    displayValue,
                    textDirection: isPhone ? TextDirection.ltr : TextDirection.rtl,
                    style: GoogleFonts.cairo(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.edit_rounded, color: Color(0xFFD97706), size: 12),
                  const SizedBox(width: 3),
                  Text(
                    'تعديل',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 4. Photo Notice Box
  // ─────────────────────────────────────────────────────────────
  Widget _buildPhotoNoticeBox() {
    return InkWell(
      onTap: widget.onNavigateSettings,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.photo_camera_outlined, color: Color(0xFFD49B1A), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'لتغيير صورتك الشخصية، انتقل إلى تبويب "الإعدادات" في الأسفل.',
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF475569),
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF94A3B8), size: 13),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String? photoBase64, [String? name]) {
    if (photoUrl != null && photoUrl.isNotEmpty && photoUrl != 'default') {
      if (photoUrl.startsWith('http://') || photoUrl.startsWith('https://')) {
        return Image.network(
          photoUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildAvatarFromBase64OrFallback(photoBase64, name),
        );
      } else if (photoUrl.startsWith('data:image')) {
        try {
          final base64String = photoUrl.split(',').last;
          final bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildAvatarFallback(name),
          );
        } catch (_) {}
      } else if (!kIsWeb) {
        try {
          final file = File(photoUrl);
          if (file.existsSync()) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildAvatarFromBase64OrFallback(photoBase64, name),
            );
          }
        } catch (_) {}
      }
    }
    return _buildAvatarFromBase64OrFallback(photoBase64, name);
  }

  Widget _buildAvatarFromBase64OrFallback(String? photoBase64, [String? name]) {
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        final cleanBase64 = photoBase64.contains(',')
            ? photoBase64.split(',').last
            : photoBase64;
        final bytes = base64Decode(cleanBase64);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildAvatarFallback(name),
        );
      } catch (_) {}
    }
    return _buildAvatarFallback(name);
  }

  Widget _buildAvatarFallback([String? name]) {
    final String initial = (name != null && name.trim().isNotEmpty)
        ? name.trim().characters.first
        : 'م';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E2E5C),
            Color(0xFF0B2A5B),
            Color(0xFF0A1229),
          ],
        ),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFE082),
              Color(0xFFD49B1A),
            ],
          ).createShader(bounds),
          child: Text(
            initial,
            style: GoogleFonts.cairo(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.05,
            ),
          ),
        ),
      ),
    );
  }
}
