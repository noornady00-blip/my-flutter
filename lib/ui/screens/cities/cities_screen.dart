import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../custom_widgets/city_landmark_widget.dart';
import '../../custom_widgets/app_logo_badge.dart';
import '../../custom_widgets/awake_badge.dart';
import '../../custom_widgets/floating_nav_bar.dart';
import '../../custom_widgets/executive_lawyer_card.dart';
import '../../../data/models/lawyer.dart';
import '../../../network/firestore_service.dart';
import '../lawyers/lawyers_list_screen.dart';
import '../main_navigation_screen.dart';
import '../../../network/auth_service.dart';
import '../../custom_widgets/app_drawer.dart';
import '../../../core/utils/search_utils.dart';

class CitiesScreen extends StatefulWidget {
  final String? initialCity;
  final ValueChanged<int>? onNavigateTab;
  final VoidCallback? onOpenDrawer;
  final bool isEmbeddedInNav;
  final bool autoFocusSearch;

  const CitiesScreen({
    super.key,
    this.initialCity,
    this.onNavigateTab,
    this.onOpenDrawer,
    this.isEmbeddedInNav = false,
    this.autoFocusSearch = false,
  });

  @override
  State<CitiesScreen> createState() => _CitiesScreenState();
}

class _CitiesScreenState extends State<CitiesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String _searchQuery = '';
  int _selectedNav = 0;

  // Approved lawyers cache for instant unified search
  StreamSubscription<List<LawyerModel>>? _lawyersSub;
  List<LawyerModel> _allApprovedLawyers = [];

  // Exactly the 12 Sudanese cities
  final List<Map<String, String>> _sudanCities = [
    {'name': 'الخرطوم', 'state': 'ولاية الخرطوم', 'desc': 'العاصمة القومية'},
    {'name': 'أم درمان', 'state': 'ولاية الخرطوم', 'desc': 'العاصمة الوطنية'},
    {'name': 'بحري', 'state': 'ولاية الخرطوم', 'desc': 'الخرطوم بحري'},
    {'name': 'بورتسودان', 'state': 'ولاية البحر الأحمر', 'desc': 'الميناء الرئيسي والعاصمة الإدارية'},
    {'name': 'كسلا', 'state': 'ولاية كسلا', 'desc': 'أرض التاكا والقاش'},
    {'name': 'عطبرة', 'state': 'ولاية نهر النيل', 'desc': 'عاصمة الحديد والنار'},
    {'name': 'ود مدني', 'state': 'ولاية الجزيرة', 'desc': 'حاضرة الجزيرة الخضراء'},
    {'name': 'الأبيض', 'state': 'ولاية شمال كردفان', 'desc': 'عروس الرمال'},
    {'name': 'الفاشر', 'state': 'ولاية شمال دارفور', 'desc': 'حاضرة دارفور التاريخية'},
    {'name': 'نيالا', 'state': 'ولاية جنوب دارفور', 'desc': 'لؤلؤة جنوب دارفور'},
    {'name': 'دنقلا', 'state': 'الولاية الشمالية', 'desc': 'أرض الحضارة النوبية والتاريخ'},
    {'name': 'جميع المدن', 'state': 'كافة ولايات ومدن السودان', 'desc': 'استعراض كافة المحامين المعتمدين'},
  ];

  // Filtered cities based on search query
  List<Map<String, String>> get _displayedCities {
    final query = _searchQuery.trim();
    if (query.isEmpty) return _sudanCities;
    return _sudanCities.where((c) {
      return AppSearchUtils.matchesAny(query, [
        c['name'],
        c['state'],
        c['desc'],
      ]);
    }).toList();
  }

  // Matching lawyers for instant search by name, city, phone, or accountId
  List<LawyerModel> get _matchingLawyers {
    final query = _searchQuery.trim();
    if (query.isEmpty) return [];
    return _allApprovedLawyers.where((l) {
      return AppSearchUtils.matchesAny(query, [
        l.name,
        l.city,
        l.phone,
        l.accountId,
      ]);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    // Listen to approved lawyers stream for real-time search
    _lawyersSub = FirestoreService().getApprovedLawyers().listen((lawyers) {
      if (mounted) {
        setState(() => _allApprovedLawyers = lawyers);
      }
    });

    if (widget.initialCity != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToLawyers(widget.initialCity!);
      });
    }
    if (widget.autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _searchFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _lawyersSub?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _navigateToLawyers(String city) {
    if (city == 'جميع المدن' || city == 'كافة المدن' || city == 'كافة المحامين') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const LawyersListScreen(
            city: 'جميع المدن',
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => LawyersListScreen(
            city: city,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color headerGold = Color(0xFFD49B1A); // Warm rich amber
    const Color pageBg = Color(0xFFFCFBF9);

    final bool hasSearchQuery = _searchQuery.trim().isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: pageBg,
      drawer: widget.isEmbeddedInNav ? null : _buildDrawer(),
      appBar: _buildTopAppBar(headerGold),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 14),
              _buildHeroHeader(),
              const SizedBox(height: 16),
              _buildSearchInput(),
              const SizedBox(height: 16),
              if (!hasSearchQuery) ...[
                _buildSectionTitle(),
                const SizedBox(height: 14),
                _buildCitiesGrid(),
              ] else ...[
                // Active Search Mode: Show Matching Lawyers + Matching Cities
                if (_matchingLawyers.isNotEmpty) ...[
                  _buildMatchingLawyersSection(),
                  const SizedBox(height: 22),
                ],
                if (_displayedCities.isNotEmpty) ...[
                  _buildMatchingCitiesSectionHeader(),
                  const SizedBox(height: 14),
                  _buildCitiesGrid(),
                  const SizedBox(height: 16),
                ],
                if (_matchingLawyers.isEmpty && _displayedCities.isEmpty) ...[
                  _buildSearchEmptyState(),
                ],
              ],
              const SizedBox(height: 90),
            ],
          ),
        ),
      ),
      bottomNavigationBar: widget.isEmbeddedInNav ? null : _buildBottomNav(headerGold),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 1. TOP APP BAR (Logo with Eye-pleasing Capsule Background + Menu)
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
          // Left side: Official Logo with soft, eye-pleasing white pill container + Awake 24/7 Badge
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AppLogoBadge(
                height: 26,
                withPillBackground: true,
              ),
              const SizedBox(width: 8),
              const Awake247Badge(),
            ],
          ),

          // Right side: Hamburger Menu Button
          InkWell(
            onTap: () {
              if (widget.onOpenDrawer != null) {
                widget.onOpenDrawer!();
              } else {
                _scaffoldKey.currentState?.openDrawer();
              }
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 42,
              height: 42,
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
                  Icons.menu_rounded,
                  color: Color(0xFF0B2A5B), // Dark navy icon
                  size: 25,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 2. HERO HEADER ("دليل مدن ومحامي السودان" + Decorative Divider + Subtitle)
  // ─────────────────────────────────────────────────────────────
  Widget _buildHeroHeader() {
    return Column(
      children: [
        Text(
          'دليل مدن ومحامي السودان',
          style: GoogleFonts.cairo(
            fontSize: 25,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF0B2A5B),
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Golden decorative accent bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFD49B1A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFFD49B1A),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              width: 36,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xFFD49B1A),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),
        Text(
          'ابحث باسم المحامي أو اختر مدينتك للتواصل الفوري',
          style: GoogleFonts.cairo(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0);
  }

  // ─────────────────────────────────────────────────────────────
  // 3. SEARCH INPUT (Unified search with luxury gold badge & Cairo typography)
  // ─────────────────────────────────────────────────────────────
  Widget _buildSearchInput() {
    final bool isFocused = _searchFocusNode.hasFocus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isFocused
                ? const Color(0xFFD49B1A)
                : const Color(0xFFE2E8F0),
            width: isFocused ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2A5B).withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: const Color(0xFFD49B1A).withValues(alpha: isFocused ? 0.12 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            // Luxury Golden Search Icon Badge
            Container(
              margin: const EdgeInsets.fromLTRB(6, 6, 8, 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFD49B1A), Color(0xFFFFD574)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFD49B1A).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),

            // Search TextField
            Expanded(
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                textDirection: TextDirection.rtl,
                onChanged: (val) => setState(() => _searchQuery = val),
                style: GoogleFonts.cairo(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B2A5B),
                ),
                decoration: InputDecoration(
                  hintText: 'ابحث باسم المحامي، المدينة، أو التخصص...',
                  hintStyle: GoogleFonts.cairo(
                    color: const Color(0xFF94A3B8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  filled: false,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),

            // Clear Button
            if (_searchQuery.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  padding: const EdgeInsets.all(5),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }



  // ─────────────────────────────────────────────────────────────
  // 4. SECTION TITLE & "كافة المحامين" BUTTON
  // ─────────────────────────────────────────────────────────────
  Widget _buildSectionTitle() {
    final String titleText = _searchQuery.isEmpty
        ? 'مدن السودان (${_displayedCities.length})'
        : 'نتائج البحث (${_displayedCities.length})';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Right Side: Title + Golden Underline
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  titleText,
                  style: GoogleFonts.cairo(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Container(
                  width: 38,
                  height: 3.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD49B1A),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // Left Side: Beautiful Standout "كافة المحامين" Button
          _buildAllLawyersPillButton(),
        ],
      ),
    );
  }

  Widget _buildAllLawyersPillButton() {
    return InkWell(
      onTap: () => _navigateToLawyers('جميع المدن'),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2A5B), // Rich dark navy
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2A5B).withValues(alpha: 0.20),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.gavel_rounded,
              color: Color(0xFFD49B1A), // Golden gavel
              size: 15,
            ),
            const SizedBox(width: 6),
            Text(
              'كافة المحامين',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Color(0xFFD49B1A),
              size: 10,
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // MATCHING LAWYERS SECTION (Instant Search Results)
  // ─────────────────────────────────────────────────────────────
  Widget _buildMatchingLawyersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            textDirection: TextDirection.rtl,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B2A5B),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      color: Color(0xFFD49B1A),
                      size: 15,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'المحامون المطابقون (${_matchingLawyers.length})',
                    style: GoogleFonts.cairo(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0B2A5B),
                    ),
                  ),
                ],
              ),
              _buildAllLawyersPillButton(),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _matchingLawyers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              return ExecutiveLawyerCard(
                lawyer: _matchingLawyers[index],
                index: index,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingCitiesSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: const Color(0xFF0B2A5B),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: Color(0xFFD49B1A),
              size: 15,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'المدن المطابقة (${_displayedCities.length})',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B2A5B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchEmptyState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEDE8DF), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(
            Icons.person_search_rounded,
            size: 52,
            color: Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد نتائج تطابق بحثك',
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0B2A5B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'جرّب البحث باسم آخر للمحامي أو مدينة أخرى مثل الخرطوم، أم درمان، بورتسودان، أو كسلا',
            style: GoogleFonts.cairo(
              fontSize: 12.5,
              color: const Color(0xFF64748B),
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _navigateToLawyers('جميع المدن'),
            icon: const Icon(Icons.gavel_rounded, size: 16, color: Color(0xFF0B2A5B)),
            label: Text(
              'تصفح كافة المحامين',
              style: GoogleFonts.cairo(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF0B2A5B),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD49B1A),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 5. CITIES GRID (Responsive Layout with Large 3D Embossed Medallions)
  // ─────────────────────────────────────────────────────────────
  Widget _buildCitiesGrid() {
    final list = _displayedCities;

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(36),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.location_off_outlined, size: 54, color: Color(0xFFCBD5E1)),
            const SizedBox(height: 12),
            Text(
              'لا توجد مدينة بهذا الاسم',
              style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
            ),
            const SizedBox(height: 6),
            Text(
              'جرّب البحث باسم محامي أو تصفح كافة المحامين',
              style: GoogleFonts.cairo(fontSize: 12, color: const Color(0xFF94A3B8)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double screenWidth = constraints.maxWidth;

        // Responsive columns, aspect ratio, and medallion size
        final int crossAxisCount;
        final double childAspectRatio;
        final double iconDimension;
        final double horizontalPadding;
        final double crossSpacing;
        final double mainSpacing;

        if (screenWidth >= 1050) {
          crossAxisCount = 6;
          childAspectRatio = 0.86;
          iconDimension = 110;
          horizontalPadding = 24;
          crossSpacing = 16;
          mainSpacing = 18;
        } else if (screenWidth >= 750) {
          crossAxisCount = 4;
          childAspectRatio = 0.84;
          iconDimension = 100;
          horizontalPadding = 20;
          crossSpacing = 14;
          mainSpacing = 16;
        } else if (screenWidth >= 520) {
          crossAxisCount = 3;
          childAspectRatio = 0.82;
          iconDimension = 90;
          horizontalPadding = 16;
          crossSpacing = 12;
          mainSpacing = 14;
        } else {
          // Mobile phones
          crossAxisCount = 3;
          childAspectRatio = 0.78;
          iconDimension = 80;
          horizontalPadding = 12;
          crossSpacing = 10;
          mainSpacing = 12;
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: crossSpacing,
              mainAxisSpacing: mainSpacing,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              final city = list[index];
              return _buildCityCard(city, index, iconDimension);
            },
          ),
        );
      },
    );
  }

  Widget _buildCityCard(Map<String, String> city, int index, double iconDimension) {
    final cityName = city['name']!;

    return InkWell(
      onTap: () => _navigateToLawyers(cityName),
      borderRadius: BorderRadius.circular(20),
      hoverColor: const Color(0xFFD49B1A).withValues(alpha: 0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFEDE8DF),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0B2A5B).withValues(alpha: 0.04),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Landmark 3D Embossed Medallion (Large & Centered)
            Expanded(
              child: Center(
                child: CityLandmarkWidget(
                  cityName: cityName,
                  width: iconDimension,
                  height: iconDimension,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // City Name (Deep Navy Cairo font)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                cityName,
                style: GoogleFonts.cairo(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0B2A5B),
                  height: 1.15,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),

            // Minimal Location Pin indicator in elegant metallic warm gold (#FFA000)
            const Icon(
              Icons.location_on_rounded,
              color: Color(0xFFD49B1A),
              size: 16,
            ),
          ],
        ),
      ),
    )
        .animate(delay: Duration(milliseconds: 15 * (index % 12)))
        .fadeIn(duration: 280.ms)
        .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.0, 1.0));
  }

  // ─────────────────────────────────────────────────────────────
  // 6. BOTTOM NAVIGATION BAR (Floating Pill Design)
  // ─────────────────────────────────────────────────────────────
  Widget _buildBottomNav(Color headerGold) {
    return FloatingNavBar(
      currentIndex: _selectedNav,
      barBackgroundColor: headerGold,
      activeBgColor: Colors.white,
      activeColor: const Color(0xFF0B2A5B),
      inactiveColor: const Color(0xAA0F1B3E),
      onTap: (index) {
        setState(() => _selectedNav = index);
        if (widget.onNavigateTab != null) {
          widget.onNavigateTab!(index);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => MainNavigationScreen(initialIndex: index)),
            (_) => false,
          );
        }
      },
      items: const [
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
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // 8. ROLE-BASED DRAWER (Custom menu tailored by Client/Lawyer/Admin/Guest)
  // ─────────────────────────────────────────────────────────────
  Widget _buildDrawer() {
    return AppDrawer(
      onNavigateTab: widget.onNavigateTab,
      onChangePassword: _showChangePasswordDialog,
    );
  }

  void _showChangePasswordDialog() {
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
            24,
            20,
            24,
            MediaQuery.of(modalCtx).viewInsets.bottom + 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'تغيير كلمة المرور',
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0B2A5B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أدخل كلمة المرور الحالية ثم الجديدة للحفاظ على أمان حسابك',
                  style: GoogleFonts.cairo(fontSize: 13, color: const Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),

                // Old Password
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: oldPassCtrl,
                    obscureText: obscureOld,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور الحالية',
                      hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFD49B1A)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureOld ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        onPressed: () => setModalState(() => obscureOld = !obscureOld),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // New Password
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: newPassCtrl,
                    obscureText: obscureNew,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'كلمة المرور الجديدة (6 خانات على الأقل)',
                      hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.key_rounded, color: Color(0xFFD49B1A)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureNew ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        onPressed: () => setModalState(() => obscureNew = !obscureNew),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Confirm Password
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: confirmPassCtrl,
                    obscureText: obscureConfirm,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.cairo(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'تأكيد كلمة المرور الجديدة',
                      hintStyle: GoogleFonts.cairo(color: const Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFFD49B1A)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: const Color(0xFF94A3B8),
                          size: 20,
                        ),
                        onPressed: () => setModalState(() => obscureConfirm = !obscureConfirm),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: GoogleFonts.cairo(color: const Color(0xFFDC2626), fontSize: 13)),
                ],

                const SizedBox(height: 18),

                 ElevatedButton(
                  onPressed: loading
                      ? null
                      : () async {
                          if (oldPassCtrl.text.trim().isEmpty) {
                            setModalState(() => error = 'يرجى إدخال كلمة المرور الحالية');
                            return;
                          }
                          if (newPassCtrl.text.trim().length < 6) {
                            setModalState(() => error = 'كلمة المرور الجديدة يجب أن تكون 6 أحرف على الأقل');
                            return;
                          }
                          if (newPassCtrl.text.trim() != confirmPassCtrl.text.trim()) {
                            setModalState(() => error = 'كلمة المرور وتأكيدها غير متطابقين');
                            return;
                          }

                          setModalState(() {
                            loading = true;
                            error = null;
                          });

                          Map<String, dynamic> res;
                          try {
                            res = await AuthService().reauthenticateAndChangePassword(
                              currentPassword: oldPassCtrl.text.trim(),
                              newPassword: newPassCtrl.text.trim(),
                            );
                          } catch (e) {
                            res = {'success': false, 'error': 'حدث خطأ غير متوقع، يرجى المحاولة مجدداً'};
                          }

                          // Always reset loading first, regardless of mount state
                          setModalState(() {
                            loading = false;
                            if (res['success'] != true) {
                              error = res['error']?.toString() ?? 'تعذر تغيير كلمة المرور';
                            }
                          });

                          if (res['success'] == true) {
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تم تغيير كلمة المرور بنجاح!',
                                      style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0B2A5B),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'تحديث كلمة المرور',
                          style: GoogleFonts.cairo(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
