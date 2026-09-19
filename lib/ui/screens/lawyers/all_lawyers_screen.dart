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
  String _selectedSpec = 'الكل';

  final List<String> _specializations = [
    'الكل',
    'جنائي',
    'مدني',
    'شرعي وتوثيق',
    'تجاري وشركات',
    'عقارات وأراضي',
    'عمالي وإداري',
  ];

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
        l.specialization,
        l.phone,
      ]);
      final matchesSpec = _selectedSpec == 'الكل' || l.specialization == _selectedSpec;
      return isApproved && matchesSearch && matchesSpec;
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
            const AppLogoBadge(
              height: 30,
              withPillBackground: true,
            ),
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

            // 2. Specializations Filter Chips
            _buildSpecializationsFilter(),

            // 3. Lawyers Stream List (Approved Only)
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
          hintText: 'ابحث باسم المحامي، التخصص، أو المدينة...',
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

  Widget _buildSpecializationsFilter() {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _specializations.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final spec = _specializations[index];
          final isSelected = _selectedSpec == spec;

          return InkWell(
            onTap: () => setState(() => _selectedSpec = spec),
            borderRadius: BorderRadius.circular(20),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF0B2A5B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? const Color(0xFF0B2A5B) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: Text(
                  spec,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFFFDE68A) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        },
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
            'جرب تغيير كلمة البحث أو اختيار تصنيف آخر',
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
