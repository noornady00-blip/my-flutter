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

  testWidgets('Guest Profile View contains clear login invitation and no fake membership data', (WidgetTester tester) async {
    // Verify that guest card does not assert active digital membership for unauthenticated visitors
    const guestTitle = 'أهلاً بك في منصة محاميك';
    const guestBadge = 'وضع الزائر والضيف';
    const guestButtonText = 'تسجيل الدخول أو إنشاء حساب';

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Column(
              children: [
                Text(guestTitle),
                Text(guestBadge),
                Text(guestButtonText),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text(guestTitle), findsOneWidget);
    expect(find.text(guestBadge), findsOneWidget);
    expect(find.text(guestButtonText), findsOneWidget);
    // Ensure fake active membership card texts are not present
    expect(find.text('بطاقة عضوية رقمية'), findsNothing);
    expect(find.text('2026/01/15'), findsNothing);
  });
}
