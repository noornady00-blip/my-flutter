import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/firestore_service.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/executive_lawyer_card.dart';
import '../../../core/utils/search_utils.dart';

class AllLawyersScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const AllLawyersScreen({super.key, this.onOpenDrawer});

  @override
  State<AllLawyersScreen> createState() => _AllLawyersScreenState();
}

class _AllLawyersScreenState extends State<AllLawyersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  String _searchQuery = '';

  late final Stream<List<LawyerModel>> _lawyersStream;

  @override
  void initState() {
    super.initState();
    _lawyersStream = _firestoreService.getApprovedLawyers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LawyerModel> _filterLawyers(List<LawyerModel> lawyers) {
    return lawyers.where((l) {
      final isApproved = l.status == 'approved';
      final matchesSearch = AppSearchUtils.matchesAny(_searchQuery, [
        l.name,
        l.city,
        l.phone,
        l.accountId,
      ]);
      return isApproved && matchesSearch;
    }).toList();
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 1.2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.search_rounded, color: Color(0xFF0B2A5B), size: 18),
                  const SizedBox(width: 4),
                  Text(
                    'بحث المحامين',
                    style: GoogleFonts.cairo(
                      fontSize: 13,
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
      body: SafeArea(
        child: Column(
          children: [
            // 1. Search Bar
            _buildSearchBar(),

            // 2. Lawyers Stream List (Approved Only)
            Expanded(
              child: StreamBuilder<List<LawyerModel>>(
                stream: _lawyersStream,
                initialData: FirestoreService.inMemoryApprovedLawyers,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      (snapshot.data == null || snapshot.data!.isEmpty)) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildErrorState();
                  }

                  final all = snapshot.data ?? [];
                  final filtered = _filterLawyers(all);

                  if (filtered.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.separated(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return ExecutiveLawyerCard(
                        lawyer: filtered[index],
                        index: index,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v.trim()),
        textDirection: TextDirection.rtl,
        style: GoogleFonts.cairo(fontSize: 14, color: const Color(0xFF0B2A5B)),
        decoration: InputDecoration(
          hintText: 'ابحث باسم المحامي، المدينة، أو المعرّف الموحد...',
          hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFF59E0B)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF94A3B8)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFF59E0B), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              color: Color(0xFFFFFBEB),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_search_rounded, size: 44, color: Color(0xFFF59E0B)),
          ),
          const SizedBox(height: 14),
          Text(
            'لم يتم العثور على محامين',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF0B2A5B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'جرب تغيير كلمة البحث أو كتابة اسم المحامي والمدينة',
            style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Text(
        'تعذر تحميل بيانات المحامين',
        style: GoogleFonts.cairo(color: AppTheme.error),
      ),
    );
  }
}
