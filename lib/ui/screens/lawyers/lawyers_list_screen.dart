import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/firestore_service.dart';
import '../../custom_widgets/executive_lawyer_card.dart';
import '../../../core/utils/search_utils.dart';

class LawyersListScreen extends StatefulWidget {
  final String city;
  const LawyersListScreen({super.key, required this.city});

  @override
  State<LawyersListScreen> createState() => _LawyersListScreenState();
}

class _LawyersListScreenState extends State<LawyersListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedSpec = 'الكل';
  final _firestoreService = FirestoreService();
  late final Stream<List<LawyerModel>> _lawyersStream;
  List<LawyerModel>? _initialLawyers;

  static const List<String> _specializations = [
    'الكل',
    'جنائي',
    'مدني',
    'شرعي وتوثيق',
    'تجاري وشركات',
    'عقارات وأراضي',
    'عمالي وإداري',
  ];

  @override
  void initState() {
    super.initState();
    _lawyersStream = _firestoreService.getLawyersByCity(widget.city);
    final inMem = FirestoreService.inMemoryApprovedLawyers;
    if (inMem != null && inMem.isNotEmpty) {
      _initialLawyers = inMem
          .where((l) => widget.city == 'جميع المدن' || l.city == widget.city)
          .toList();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LawyerModel> _filter(List<LawyerModel> lawyers) {
    return lawyers.where((l) {
      final isApproved = l.status == 'approved';
      final matchesQuery = AppSearchUtils.matchesAny(_searchQuery, [
        l.name,
        l.specialization,
        l.city,
        l.phone,
      ]);
      final matchesSpec = _selectedSpec == 'الكل' || l.specialization == _selectedSpec;
      return isApproved && matchesQuery && matchesSpec;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFCFBF9),
      body: Column(
        children: [
          _buildHeader(),
          // Specialization filter chips
          _buildSpecializationsFilter(),
          Expanded(
            child: StreamBuilder<List<LawyerModel>>(
              stream: _lawyersStream,
              initialData: _initialLawyers,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    (snapshot.data == null || snapshot.data!.isEmpty)) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppTheme.gold),
                  );
                }
                if (snapshot.hasError) {
                  return _buildError();
                }
                final lawyers = _filter(snapshot.data ?? []);
                if (lawyers.isEmpty) return _buildEmpty();
                return _buildList(lawyers);
              },
            ),
          ),
        ],
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
        separatorBuilder: (_, _) => const SizedBox(width: 8),
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
                color: isSelected ? AppTheme.navyDark : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.navyDark : const Color(0xFFE2E8F0),
                ),
              ),
              child: Center(
                child: Text(
                  spec,
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? AppTheme.gold : const Color(0xFF64748B),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    final bool isAllCities = widget.city == 'جميع المدن' ||
        widget.city == 'كافة المدن' ||
        widget.city == 'كافة المحامين';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.navyDark,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Color(0x28000000),
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35),
                          width: 1.2,
                        ),
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          isAllCities ? 'كافة المحامين المعتمدين' : 'المحامون في ',
                          style: GoogleFonts.cairo(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              isAllCities ? 'كافة ولايات ومدن السودان 🇸🇩' : widget.city,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.gold,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              isAllCities ? Icons.gavel_rounded : Icons.location_on_rounded,
                              color: AppTheme.gold,
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                textDirection: TextDirection.rtl,
                onChanged: (v) => setState(() => _searchQuery = v),
                style: GoogleFonts.cairo(color: AppTheme.navyDark),
                decoration: InputDecoration(
                  hintText: isAllCities
                      ? 'ابحث باسم المحامي أو المدينة أو التخصص...'
                      : 'ابحث باسم المحامي أو التخصص...',
                  hintStyle: GoogleFonts.cairo(color: AppTheme.grey, fontSize: 13.5),
                  prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.gold),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppTheme.gold, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<LawyerModel> lawyers) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
      itemCount: lawyers.length,
      itemBuilder: (context, index) {
        return ExecutiveLawyerCard(
          lawyer: lawyers[index],
          index: index,
        );
      },
    );
  }

  Widget _buildEmpty() {
    final bool isAllCities = widget.city == 'جميع المدن' ||
        widget.city == 'كافة المدن' ||
        widget.city == 'كافة المحامين';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search, size: 64, color: AppTheme.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'لا يوجد محامي يطابق البحث'
                : isAllCities
                    ? 'لا يوجد محامون مسجلون حالياً'
                    : 'لا يوجد محامون مسجلون في ${widget.city} حالياً',
            style: AppTheme.bodyLarge.copyWith(color: AppTheme.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('حدث خطأ في تحميل البيانات', style: AppTheme.bodyLarge),
        ],
      ),
    );
  }
}
