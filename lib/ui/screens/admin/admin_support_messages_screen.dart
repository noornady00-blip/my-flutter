import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/search_utils.dart';
import '../../../data/models/lawyer.dart';
import '../../../data/models/user_model.dart';
import '../../../network/notification_service.dart';
import '../../custom_widgets/profile_details_modal.dart';
import '../../custom_widgets/glass_widgets.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/image_utils.dart';

// ============================================================================
// AdminSupportMessagesScreen
// Real-time support messaging dashboard with multi-select, call/WhatsApp triggers,
// read-state toggles, and sender profile inspector.
// ============================================================================

class AdminSupportMessagesScreen extends StatefulWidget {
  const AdminSupportMessagesScreen({super.key});

  @override
  State<AdminSupportMessagesScreen> createState() => _AdminSupportMessagesScreenState();
}

class _AdminSupportMessagesScreenState extends State<AdminSupportMessagesScreen> {
  String _filter = 'all'; // 'all', 'unread', 'read'
  bool _isSelectionMode = false;
  final Set<String> _selectedDocIds = <String>{};
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    NotificationService().markNotificationsReadForEntity(type: 'support_message');
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _cleanPhoneForCall(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (clean.startsWith('00')) {
      clean = '+${clean.substring(2)}';
    }
    return clean;
  }

  String _cleanPhoneForWhatsApp(String phone) {
    return PhoneUtils.formatWhatsAppNumber(phone);
  }

  Future<void> _makePhoneCall(BuildContext context, String phone) async {
    final clean = _cleanPhoneForCall(phone);
    final uri = Uri.parse('tel:$clean');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح تطبيق الهاتف تلقائياً للرقم: $clean', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في تشغيل الاتصال: $e', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phone) async {
    final clean = _cleanPhoneForWhatsApp(phone);
    final uri = Uri.parse('https://wa.me/$clean');
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذر فتح تطبيق واتساب. يرجى التأكد من تثبيته.', style: GoogleFonts.cairo()),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في فتح واتساب: $e', style: GoogleFonts.cairo()),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _toggleStatus(DocumentReference ref, String currentStatus) async {
    final newStatus = currentStatus == 'unread' ? 'read' : 'unread';
    await ref.update({'status': newStatus});
  }

  Future<void> _deleteMessage(BuildContext context, DocumentReference ref) async {
    final confirm = await showDialog<bool>(
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
                'تأكيد حذف الرسالة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: const Color(0xFF0B2A5B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'هل أنت متأكد من رغبتك في حذف هذه الرسالة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
                style: GoogleFonts.cairo(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
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
                      onPressed: () => Navigator.pop(ctx, true),
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

    if (confirm == true) {
      try {
        await ref.delete();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف الرسالة بنجاح', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر حذف الرسالة: $e', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFFDC2626),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmBulkDelete(BuildContext context, List<String> docIds) async {
    if (docIds.isEmpty) return;

    final confirm = await showDialog<bool>(
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
                  child: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFE11D48), size: 30),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'حذف ${docIds.length} رسائل محددة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                  color: const Color(0xFF0B2A5B),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'هل أنت متأكد من رغبتك في حذف ${docIds.length} رسالة محددة نهائياً من النظام؟ لا يمكن التراجع عن هذا الإجراء.',
                style: GoogleFonts.cairo(fontSize: 12.5, color: const Color(0xFF64748B), height: 1.4),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
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
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('حذف (${docIds.length})', style: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirm == true) {
      try {
        final batch = FirebaseFirestore.instance.batch();
        for (final id in docIds) {
          batch.delete(FirebaseFirestore.instance.collection('support_messages').doc(id));
        }
        await batch.commit();

        setState(() {
          _selectedDocIds.clear();
          _isSelectionMode = false;
        });

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم حذف ${docIds.length} رسالة بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تعذر حذف الرسائل: $e', style: GoogleFonts.cairo()),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  Future<void> _openSenderProfile(BuildContext context, Map<String, dynamic> data) async {
    final String role = (data['senderRole'] ?? data['role'] ?? 'client').toString().toLowerCase();
    final String? senderUid = data['senderUid']?.toString();
    final String name = (data['name']?.toString() ?? 'مستخدم منصة محاميك').trim();
    final String phone = (data['phone']?.toString() ?? '').trim();
    final String? photoBase64 = data['photoBase64']?.toString();
    final String? photoUrl = data['photoUrl']?.toString();

    if (role == 'lawyer') {
      LawyerModel? lawyer;
      if (senderUid != null && senderUid.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('lawyers').doc(senderUid).get();
          if (doc.exists && doc.data() != null) {
            lawyer = LawyerModel.fromMap(doc.data()!, doc.id);
          }
        } catch (_) {}
      }
      lawyer ??= LawyerModel(
        uid: senderUid ?? 'unknown',
        name: name,
        phone: phone,
        whatsapp: phone,
        city: data['city']?.toString() ?? 'الخرطوم',
        status: 'approved',
        photoBase64: photoBase64,
        photoUrl: photoUrl,
      );
      if (context.mounted) {
        ProfileDetailsModal.showLawyerModal(context, lawyer: lawyer, isAdmin: true);
      }
    } else {
      UserModel? client;
      if (senderUid != null && senderUid.isNotEmpty) {
        try {
          final doc = await FirebaseFirestore.instance.collection('users').doc(senderUid).get();
          if (doc.exists && doc.data() != null) {
            client = UserModel.fromMap(doc.data()!, doc.id);
          }
        } catch (_) {}
      }
      client ??= UserModel(
        uid: senderUid ?? 'unknown',
        name: name,
        phone: phone,
        role: 'client',
        status: 'active',
        photoBase64: photoBase64,
        photoUrl: photoUrl,
      );
      if (context.mounted) {
        ProfileDetailsModal.showClientModal(context, client: client, isAdmin: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color headerGold = Color(0xFFD49B1A);
    const Color pageBg = Color(0xFFFCFBF9);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('support_messages')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final filteredDocs = docs.where((doc) {
          final data = doc.data();
          final status = data['status']?.toString() ?? 'unread';
          if (_filter == 'unread' && status != 'unread') return false;
          if (_filter == 'read' && status != 'read') return false;

          if (_searchQuery.isNotEmpty) {
            return AppSearchUtils.matchesAny(_searchQuery, [
              data['name']?.toString(),
              data['phone']?.toString(),
              data['email']?.toString(),
              data['subject']?.toString(),
              data['message']?.toString(),
              data['city']?.toString(),
              data['accountId']?.toString(),
            ]);
          }
          return true;
        }).toList();

        final bool allSelected = filteredDocs.isNotEmpty &&
            filteredDocs.every((doc) => _selectedDocIds.contains(doc.id));

        return Scaffold(
          backgroundColor: pageBg,
          appBar: AppBar(
            backgroundColor: headerGold,
            elevation: 0,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Color(0xFF0B2A5B)),
            leading: _isSelectionMode
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF0B2A5B)),
                    tooltip: 'إلغاء التحديد',
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = false;
                        _selectedDocIds.clear();
                      });
                    },
                  )
                : null,
            title: Text(
              _isSelectionMode
                  ? 'تم تحديد ${_selectedDocIds.length} رسالة'
                  : 'رسائل التواصل والدعم',
              style: GoogleFonts.cairo(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
            ),
            actions: [
              if (!_isSelectionMode) ...[
                if (filteredDocs.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0B2A5B),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    icon: const Icon(Icons.checklist_rounded, size: 20, color: Color(0xFF0B2A5B)),
                    label: Text(
                      'تحديد الكل',
                      style: GoogleFonts.cairo(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF0B2A5B),
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _isSelectionMode = true;
                        _selectedDocIds.clear();
                        for (final d in filteredDocs) {
                          _selectedDocIds.add(d.id);
                        }
                      });
                    },
                  ),
              ] else ...[
                // Toggle Select All / Deselect All
                IconButton(
                  icon: Icon(
                    allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                    color: const Color(0xFF0B2A5B),
                  ),
                  tooltip: allSelected ? 'إلغاء تحديد الكل' : 'تحديد الكل',
                  onPressed: () {
                    setState(() {
                      if (allSelected) {
                        _selectedDocIds.clear();
                      } else {
                        for (final d in filteredDocs) {
                          _selectedDocIds.add(d.id);
                        }
                      }
                    });
                  },
                ),
                // Bulk Delete Action
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFDC2626)),
                  tooltip: 'حذف الرسائل المحددة',
                  onPressed: _selectedDocIds.isEmpty
                      ? null
                      : () => _confirmBulkDelete(context, _selectedDocIds.toList()),
                ),
              ],
            ],
          ),
          body: Column(
            children: [
              // Search Box
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                color: Colors.white,
                child: TextField(
                  controller: _searchCtrl,
                  textDirection: TextDirection.rtl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'ابحث بالاسم، الهاتف، أو نص الرسالة...',
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

              // Filter Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.05))),
                ),
                child: Row(
                  children: [
                    _buildFilterChip('all', 'الكل'),
                    const SizedBox(width: 8),
                    _buildFilterChip('unread', 'غير مقروءة'),
                    const SizedBox(width: 8),
                    _buildFilterChip('read', 'مقروءة'),
                  ],
                ),
              ),

              // Messages List
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48, color: Color(0xFFDC2626)),
                              const SizedBox(height: 12),
                              Text(
                                'حدث خطأ في تحميل الرسائل: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: headerGold),
                      );
                    }

                    if (filteredDocs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFFFFBEB),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.mark_email_read_outlined,
                                  size: 48,
                                  color: Color(0xFFD49B1A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'لا توجد نتائج مطابقة للبحث'
                                    : (_filter == 'unread' ? 'لا توجد رسائل غير مقروءة' : 'صندوق رسائل التواصل فارغ'),
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF0B2A5B),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'جرب البحث بكلمات أخرى أو تحقق من كتابة الكلمات'
                                    : 'أي رسائل استفسار أو تواصل من المستخدمين ستظهر هنا فوراً',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.cairo(
                                  fontSize: 12.5,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredDocs.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 14),
                      itemBuilder: (context, index) {
                        final doc = filteredDocs[index];
                        final data = doc.data();
                        return _buildMessageCard(context, doc.reference, data);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _filter == key;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _filter = key),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0B2A5B) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : const Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSenderAvatar(String? photoBase64, String? photoUrl, String name) {
    const double size = 46;
    final fallback = _buildFallbackAvatar(name, size);
    final content = ClipOval(
      child: AppImageUtils.buildAvatarImage(
        photoBase64: photoBase64,
        photoUrl: photoUrl,
        width: size,
        height: size,
        fallback: fallback,
      ),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF0B2A5B), width: 2.0),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B2A5B).withValues(alpha: 0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(child: content),
    );
  }

  Widget _buildFallbackAvatar(String name, double size) {
    final letter = name.trim().isNotEmpty ? name.trim().characters.first : 'م';
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: Color(0xFF0B2A5B),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: GoogleFonts.cairo(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w900,
          color: const Color(0xFFD49B1A),
        ),
      ),
    );
  }

  Widget _buildMessageCard(
    BuildContext context,
    DocumentReference ref,
    Map<String, dynamic> data,
  ) {
    final String docId = ref.id;
    final bool isSelected = _selectedDocIds.contains(docId);
    final String name = (data['name']?.toString() ?? 'مستخدم منصة محاميك').trim();
    final String phone = (data['phone']?.toString() ?? '').trim();
    final String message = (data['message']?.toString() ?? '').trim();
    final String status = data['status']?.toString() ?? 'unread';
    final bool isUnread = status == 'unread';
    final String role = (data['senderRole'] ?? data['role'] ?? 'client').toString().toLowerCase();
    final bool isLawyer = role == 'lawyer';

    DateTime? createdAt;
    final timestamp = data['createdAt'];
    if (timestamp is Timestamp) {
      createdAt = timestamp.toDate();
    }

    String dateFormatted = '';
    if (createdAt != null) {
      try {
        dateFormatted = DateFormat('yyyy/MM/dd - hh:mm a', 'ar').format(createdAt);
      } catch (_) {
        dateFormatted = DateFormat('yyyy/MM/dd - hh:mm a').format(createdAt);
      }
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_isSelectionMode) {
            setState(() {
              if (isSelected) {
                _selectedDocIds.remove(docId);
              } else {
                _selectedDocIds.add(docId);
              }
            });
          } else {
            if (isUnread) {
              ref.update({'status': 'read'});
            }
          }
        },
        onLongPress: () {
          setState(() {
            _isSelectionMode = true;
            if (isSelected) {
              _selectedDocIds.remove(docId);
            } else {
              _selectedDocIds.add(docId);
            }
          });
        },
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFFBEB) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFFE2E8F0),
              width: isSelected ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? const Color(0xFFD49B1A).withValues(alpha: 0.12)
                    : const Color(0xFF0B2A5B).withValues(alpha: 0.035),
                blurRadius: isSelected ? 12 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Message header: Avatar, Name, Role, Timestamp, and Read Status
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    // Multi-select checkbox
                    if (_isSelectionMode) ...[
                      InkWell(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              _selectedDocIds.remove(docId);
                            } else {
                              _selectedDocIds.add(docId);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 24,
                          height: 24,
                          margin: const EdgeInsets.only(left: 10),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFFD49B1A) : Colors.white,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFD49B1A) : const Color(0xFF94A3B8),
                              width: 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                              : null,
                        ),
                      ),
                    ],

                    // Avatar & Sender Info (Clickable to open profile modal)
                    Expanded(
                      child: InkWell(
                        onTap: _isSelectionMode
                            ? () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedDocIds.remove(docId);
                                  } else {
                                    _selectedDocIds.add(docId);
                                  }
                                });
                              }
                            : () => _openSenderProfile(context, data),
                        borderRadius: BorderRadius.circular(12),
                        child: Row(
                          textDirection: TextDirection.rtl,
                          children: [
                            _buildSenderAvatar(
                              data['photoBase64']?.toString(),
                              data['photoUrl']?.toString(),
                              name,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          style: GoogleFonts.cairo(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w800,
                                            color: const Color(0xFF0B2A5B),
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: isLawyer ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(
                                            color: isLawyer ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE),
                                            width: 0.8,
                                          ),
                                        ),
                                        child: Text(
                                          isLawyer ? 'محامي' : 'عميل',
                                          style: GoogleFonts.cairo(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: isLawyer ? const Color(0xFFB45309) : const Color(0xFF1D4ED8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (dateFormatted.isNotEmpty)
                                    Text(
                                      dateFormatted,
                                      style: GoogleFonts.cairo(
                                        fontSize: 11,
                                        color: const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Read status badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isUnread ? const Color(0xFFFEF3C7) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isUnread ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0),
                          width: 1,
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
                              color: isUnread ? const Color(0xFFD97706) : const Color(0xFF94A3B8),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isUnread ? 'جديدة' : 'مقروءة',
                            style: GoogleFonts.cairo(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: isUnread ? const Color(0xFF92400E) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 2. Phone Row with copy action
                if (phone.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                    ),
                    child: Row(
                      textDirection: TextDirection.ltr,
                      children: [
                        InkWell(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: phone));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تم نسخ رقم الهاتف: $phone', style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF10B981),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(
                            padding: EdgeInsets.all(3),
                            child: Icon(Icons.copy_rounded, size: 15, color: Color(0xFF64748B)),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          phone,
                          style: GoogleFonts.cairo(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0B2A5B),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.phone_iphone_rounded, size: 16, color: Color(0xFFD49B1A)),
                      ],
                    ),
                  ),

                const SizedBox(height: 10),

                // 3. Message Body Bubble
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
                  ),
                  child: Text(
                    message.isNotEmpty ? message : '(لا يوجد نص رسالة)',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
                      height: 1.5,
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),

                const SizedBox(height: 12),

                // 4. Interactive Glass Buttons
                Row(
                  children: [
                    // WhatsApp
                    Expanded(
                      flex: 3,
                      child: GlassButton(
                        onPressed: phone.isEmpty ? null : () => _openWhatsApp(context, phone),
                        backgroundColor: const Color(0xFFECFDF5),
                        borderColor: const Color(0xFFA7F3D0).withValues(alpha: 0.6),
                        textColor: const Color(0xFF059669),
                        icon: Icons.chat_rounded,
                        label: 'واتساب',
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        borderRadius: 10,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Phone Call
                    Expanded(
                      flex: 3,
                      child: GlassButton(
                        onPressed: phone.isEmpty ? null : () => _makePhoneCall(context, phone),
                        backgroundColor: const Color(0xFFEFF6FF),
                        borderColor: const Color(0xFFBFDBFE).withValues(alpha: 0.6),
                        textColor: const Color(0xFF1D4ED8),
                        icon: Icons.call_rounded,
                        label: 'اتصال',
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        borderRadius: 10,
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Toggle Read/Unread
                    GlassButton(
                      onPressed: () => _toggleStatus(ref, status),
                      backgroundColor: isUnread ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                      borderColor: isUnread ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0),
                      textColor: isUnread ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                      icon: isUnread ? Icons.done_all_rounded : Icons.mark_email_unread_rounded,
                      tooltip: isUnread ? 'تحديد كمقروء' : 'تحديد كغير مقروء',
                      padding: const EdgeInsets.all(9),
                      borderRadius: 10,
                      child: Icon(
                        isUnread ? Icons.done_all_rounded : Icons.mark_email_unread_rounded,
                        size: 18,
                        color: isUnread ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(width: 6),

                    // Delete
                    GlassButton(
                      onPressed: () => _deleteMessage(context, ref),
                      backgroundColor: const Color(0xFFFFF1F2),
                      borderColor: const Color(0xFFFDA4AF).withValues(alpha: 0.6),
                      textColor: const Color(0xFFE11D48),
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'حذف الرسالة',
                      padding: const EdgeInsets.all(9),
                      borderRadius: 10,
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        size: 18,
                        color: Color(0xFFE11D48),
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
}
