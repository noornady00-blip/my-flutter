import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahameek/core/theme/app_theme.dart';
import 'package:mahameek/ui/custom_widgets/app_logo_badge.dart';
import 'package:mahameek/data/models/lawyer.dart';
import 'package:mahameek/ui/custom_widgets/executive_lawyer_card.dart';

void main() {
  testWidgets('RTL Directionality and Arabic Locale renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('محاميك'),
            ),
            body: const Center(
              child: AppLogoBadge(height: 40),
            ),
          ),
        ),
      ),
    );

    // Verify Arabic text appears in widget tree
    expect(find.text('محاميك'), findsOneWidget);
    expect(find.byType(AppLogoBadge), findsOneWidget);
  });

  testWidgets('AppTheme tokens match Navy and Gold brand guidelines', (WidgetTester tester) async {
    expect(AppTheme.navyDark, const Color(0xFF0B2A5B));
    expect(AppTheme.gold, const Color(0xFFD49B1A));
    expect(AppTheme.themeData.scaffoldBackgroundColor, AppTheme.offWhite);
  });

  testWidgets('ExecutiveLawyerCard renders without overflow in RTL layout', (WidgetTester tester) async {
    final lawyer = LawyerModel(
      uid: 'test_lawyer_1',
      name: 'الأستاذ أحمد فضل الله عثمان',
      phone: '0912345678',
      city: 'الخرطوم',
      specialization: 'محامٍ وموثق عقود للشركات والعقود التجارية',
      status: 'approved',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: ExecutiveLawyerCard(
                lawyer: lawyer,
                index: 0,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('الأستاذ أحمد فضل الله عثمان'), findsOneWidget);
    expect(find.text('الخرطوم'), findsOneWidget);
  });
}
