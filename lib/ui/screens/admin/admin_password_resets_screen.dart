import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/search_utils.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../data/models/password_reset_model.dart';
import '../../../network/auth_service.dart';
import '../../../network/firestore_service.dart';
import '../../../network/notification_service.dart';
import '../../custom_widgets/facebook_account_header.dart';
import '../../custom_widgets/glass_widgets.dart';

// ============================================================================
// AdminPasswordResetsScreen
// Dedicated management screen for handling user password reset tickets,
// resetting credentials via AuthService, and dispatching WhatsApp credentials.
// ============================================================================

class AdminPasswordResetsScreen extends StatefulWidget {
  const AdminPasswordResetsScreen({super.key});

  @override
  State<AdminPasswordResetsScreen> createState() => _AdminPasswordResetsScreenState();
}

class _AdminPasswordResetsScreenState extends State<AdminPasswordResetsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    NotificationService().markNotificationsReadForEntity(type: 'password_reset');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
                                  if (ticketId != null && ticketId.isNotEmpty) {
                                    await _firestoreService.deletePasswordResetTicket(ticketId);
                                  }
                                  _showPasswordResetSuccessDialog(
                                    phone: phone,
                                    name: name,
                                    newPassword: newPass,
                                    ticketId: ticketId,
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

  void _showPasswordResetSuccessDialog({
    required String phone,
    String? name,
    required String newPassword,
    String? ticketId,
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
                'تم تحديث كلمة المرور في النظام، يمكنك إرسال البيانات لصاحب الحساب فوراً عبر واتساب',
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
                                  PhoneUtils.toLocalDisplay(phone),
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
                onPressed: () async {
                  if (ticketId != null && ticketId.isNotEmpty) {
                    await _firestoreService.deletePasswordResetTicket(ticketId);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
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
                onPressed: () async {
                  if (ticketId != null && ticketId.isNotEmpty) {
                    await _firestoreService.deletePasswordResetTicket(ticketId);
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                },
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
        centerTitle: true,
        leading: Center(
          child: InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0B2A5B), size: 18),
              ),
            ),
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.key_rounded, color: Color(0xFF0B2A5B), size: 20),
            ),
            const SizedBox(width: 8),
            Text(
              'طلبات استعادة كلمة المرور',
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: const Color(0xFF0B2A5B),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Box
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
            ),
            child: TextField(
              controller: _searchCtrl,
              textDirection: TextDirection.ltr,
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'ابحث برقم الهاتف...',
                hintTextDirection: TextDirection.rtl,
                hintStyle: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF94A3B8)),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            ),
          ),

          // Requests List
          Expanded(
            child: StreamBuilder<List<PasswordResetModel>>(
              stream: _firestoreService.getPasswordResetsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: headerGold));
                }

                final requests = snapshot.data ?? [];
                final filtered = requests.where((r) {
                  return AppSearchUtils.matchesAny(_searchQuery, [
                    r.phone,
                    r.name,
                    r.cleanPhone,
                    r.notes,
                    r.role,
                    r.city,
                  ]);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: const BoxDecoration(
                              color: Color(0xFFECFDF5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 40),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'لا توجد نتائج مطابقة لبحثك'
                                : 'لا توجد طلبات استعادة كلمة مرور معلقة',
                            style: GoogleFonts.cairo(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF0B2A5B),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'تأكد من إدخال رقم الهاتف بشكل صحيح'
                                : 'كافة طلبات استعادة الحسابات تمت معالجتها بنجاح',
                            style: GoogleFonts.cairo(
                              fontSize: 12.5,
                              color: const Color(0xFF64748B),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final req = filtered[index];
                    return _buildResetCard(req);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTicket(String ticketId) {
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
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE11D48), size: 30),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'تأكيد حذف الطلب',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: const Color(0xFF0B2A5B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'هل أنت متأكد من رغبتك في حذف طلب استعادة كلمة المرور نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
                style: GoogleFonts.cairo(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
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
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _firestoreService.deletePasswordResetTicket(ticketId);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('تم حذف الطلب بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                              backgroundColor: const Color(0xFF10B981),
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

  Widget _buildResetCard(PasswordResetModel req) {
    final formattedDate = DateFormat('yyyy/MM/dd - hh:mm a').format(req.createdAt);

    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FacebookAccountHeader(
            phone: req.phone,
            uid: req.uid,
            fallbackName: req.name,
            fallbackPhotoUrl: req.photoUrl,
            fallbackPhotoBase64: req.photoBase64,
            subtitle: formattedDate,
          ),
          const SizedBox(height: 14),

          // Action buttons: Reset password + Delete ticket
          Row(
            children: [
              // 1. Change password button
              Expanded(
                flex: 3,
                child: GlassButton(
                  onPressed: () => _showAdminResetPasswordDialog(
                    phone: req.phone,
                    name: req.name,
                    ticketId: req.id,
                    targetUid: req.uid,
                  ),
                  backgroundColor: const Color(0xFF0B2A5B),
                  borderColor: const Color(0xFF0B2A5B).withValues(alpha: 0.25),
                  textColor: Colors.white,
                  icon: Icons.key_rounded,
                  label: 'تغيير كلمة المرور',
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  borderRadius: 12,
                ),
              ),
              const SizedBox(width: 10),

              // 2. Delete ticket button
              Expanded(
                flex: 2,
                child: GlassButton(
                  onPressed: () => _confirmDeleteTicket(req.id),
                  backgroundColor: const Color(0xFFFFF1F2),
                  borderColor: const Color(0xFFFDA4AF).withValues(alpha: 0.6),
                  textColor: const Color(0xFFE11D48),
                  icon: Icons.delete_outline_rounded,
                  label: 'حذف',
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  borderRadius: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
