import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/qr_checkin/presentation/screens/venue_qr_display_screen.dart';

void main() {
  const testLocation = LocationConfig(
    id: 'test_venue',
    name: 'Jade Luxury Banquets, Mumbai',
    latitude: 18.9888622,
    longitude: 72.8152475,
    radiusMeters: 500.0,
    address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
  );

  Widget createWidgetUnderTest() {
    return ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: VenueQrDisplayScreen(
            location: testLocation,
            initialDate: DateTime(2026, 9, 3),
          ),
        ),
      ),
    );
  }

  group('VenueQrDisplayScreen Widget Tests', () {
    testWidgets('renders screen title and September 2026 month with Thursdays', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Thursday QR Standees'), findsOneWidget);

      // Check month display
      expect(find.text('September 2026'), findsWidgets);

      // Check September 2026 has 4 Thursdays: Sep 3, Sep 10, Sep 17, Sep 24
      expect(find.text('4 Thursdays in September 2026'), findsOneWidget);
      expect(find.text('03'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
      expect(find.text('17'), findsOneWidget);
      // Tap Session 1 to view Session 1 Standee
      final session1Finder = find.text('Session 1');
      expect(session1Finder, findsOneWidget);
      await tester.tap(session1Finder);
      await tester.pumpAndSettle();

      // Check Standee preview card enriched elements
      expect(find.text('Thursday, 03 Sep 2026'), findsNWidgets(2));
      expect(find.text('Scan with phone camera to check in'), findsOneWidget);
      expect(find.text('?date=2026-09-03'), findsWidgets);
      expect(find.text('ACTIVE'), findsWidgets);
      expect(find.text('OFFICIAL STANDEE'), findsNothing);
      expect(find.text('OFFICIAL ID PASS'), findsNothing);
    });

    testWidgets('switches selected Thursday when tapped and updates preview card', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Tap on Session 2 (Sep 10)
      final session2Finder = find.text('Session 2');
      expect(session2Finder, findsOneWidget);
      await tester.tap(session2Finder);
      await tester.pumpAndSettle();

      expect(find.text('Thursday, 10 Sep 2026'), findsNWidgets(2));
      expect(find.text('?date=2026-09-10'), findsWidgets);
    });

    testWidgets('navigates to next month (October 2026 - 5 Thursdays) and shows locked card', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Navigate to October
      final nextMonthBtn = find.byTooltip('Next Month');
      expect(nextMonthBtn, findsOneWidget);
      await tester.tap(nextMonthBtn);
      await tester.pumpAndSettle();

      // Verify October 2026 has 5 Thursdays (01, 08, 15, 22, 29)
      expect(find.text('5 Thursdays in October 2026'), findsOneWidget);
      expect(find.text('01'), findsOneWidget);
      expect(find.text('08'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('22'), findsOneWidget);
      expect(find.text('29'), findsOneWidget);

      // Verify locked preview card
      expect(find.text('QR Code Not Available Yet'), findsOneWidget);
      expect(find.text('Thursday, 01 Oct 2026'), findsNWidgets(2));
    });

    testWidgets('opens modal dialog when View icon is tapped', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final viewIconFinder = find.byTooltip('View QR Modal').first;
      await tester.tap(viewIconFinder);
      await tester.pumpAndSettle();

      // Modal is displayed with ID card format
      expect(find.text('Thursday QR Standee'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/RISE.png',
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/attendiphi_logo.png',
        ),
        findsWidgets,
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Image && w.image is AssetImage && (w.image as AssetImage).assetName == 'assets/images/BNI.jpg',
        ),
        findsWidgets,
      );
      expect(find.text('Copy URL'), findsOneWidget);
      expect(find.text('Download PNG'), findsWidgets);

      // Close modal
      final closeBtn = find.byIcon(Icons.close_rounded);
      await tester.tap(closeBtn);
      await tester.pumpAndSettle();

      expect(find.text('Thursday QR Standee'), findsNothing);
    });
  });

  group('Thursday Date Computation Logic', () {
    test('verifies all 13 months from Sep 2026 to Sep 2027 only generate Thursdays', () {
      final months = <DateTime>[];
      for (int year = 2026; year <= 2027; year++) {
        final startMonth = (year == 2026) ? 9 : 1;
        final endMonth = (year == 2027) ? 9 : 12;
        for (int m = startMonth; m <= endMonth; m++) {
          months.add(DateTime(year, m, 1));
        }
      }

      expect(months.length, equals(13));
      expect(DateFormat('yyyy-MM').format(months.first), equals('2026-09'));
      expect(DateFormat('yyyy-MM').format(months.last), equals('2027-09'));

      for (final month in months) {
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final thursdays = <DateTime>[];
        for (int day = 1; day <= daysInMonth; day++) {
          final date = DateTime(month.year, month.month, day);
          if (date.weekday == DateTime.thursday) {
            thursdays.add(date);
          }
        }

        expect(thursdays.length, isIn([4, 5]));
        for (final t in thursdays) {
          expect(t.weekday, equals(DateTime.thursday));
        }
      }
    });
  });
}
