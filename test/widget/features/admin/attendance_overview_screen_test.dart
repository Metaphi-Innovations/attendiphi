import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_dashboard_provider.dart';
import 'package:qr_checkin/features/admin/presentation/screens/attendance_overview_screen.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:qr_checkin/features/employee/presentation/providers/employee_providers.dart';

void main() {
  final testMembers = [
    const Employee(
      id: 'emp_1',
      name: 'Atharva Patil',
      phone: '9876543210',
      role: 'Member',
    ),
    const Employee(
      id: 'emp_2',
      name: 'Rinku Sharma',
      phone: '9876543211',
      role: 'Member',
    ),
  ];

  final testSubmissions = [
    // Atharva present on Sep 3, 2026
    CheckInSubmission(
      id: 'sub_1',
      locationId: 'loc_1',
      locationName: 'Excel Plaza',
      userName: 'Atharva Patil',
      userPhone: '9876543210',
      type: CheckInType.member,
      userLatitude: 19.0834,
      userLongitude: 72.9140,
      gpsAccuracy: 10,
      distanceMeters: 5,
      timestamp: DateTime(2026, 9, 3, 10, 0),
    ),
    // Substitute for Rinku on Sep 3, 2026
    CheckInSubmission(
      id: 'sub_2',
      locationId: 'loc_1',
      locationName: 'Excel Plaza',
      userName: 'Yashraj',
      userPhone: '9876543299',
      type: CheckInType.substitute,
      substituteForMember: 'Rinku Sharma',
      userLatitude: 19.0834,
      userLongitude: 72.9140,
      gpsAccuracy: 10,
      distanceMeters: 8,
      timestamp: DateTime(2026, 9, 3, 10, 15),
    ),
  ];

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        employeesStreamProvider.overrideWith(
          (ref) => Stream.value(testMembers),
        ),
        checkInsStreamProvider.overrideWith(
          (ref) => Stream.value(testSubmissions),
        ),
      ],
      child: const MaterialApp(home: AttendanceOverviewScreen()),
    );
  }

  group('AttendanceOverviewScreen Widget Tests', () {
    testWidgets(
      'renders screen title, live badge, and toolbar filters without KPI cards',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Check header
        expect(find.text('Attendance Overview'), findsOneWidget);
        expect(find.text('LIVE MATRIX'), findsNothing);

        // Verify KPI Cards are removed
        expect(find.text('Total Presents (M)'), findsNothing);
        expect(find.text('Total Substitutes (S)'), findsNothing);
        expect(find.text('Total Absences (-)'), findsNothing);
        expect(find.text('Attendance Rate'), findsNothing);

        // Check search input present
        expect(find.byIcon(Icons.search), findsOneWidget);
      },
    );

    testWidgets('displays matrix with member names and Thursday date headers', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Members displayed
      expect(find.text('Atharva Patil'), findsOneWidget);
      expect(find.text('Rinku Sharma'), findsOneWidget);

      // Thursday headers displayed
      expect(find.text('03 Sep'), findsWidgets);
      expect(find.text('10 Sep'), findsWidgets);

      // Matrix cells with M (Present) and S (Substitute) badges
      expect(find.text('M'), findsWidgets);
      expect(find.text('S'), findsWidgets);
    });

    testWidgets('search filters member rows accurately', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Type search query
      await tester.enterText(find.byType(TextField), 'Atharva');
      await tester.pumpAndSettle();

      expect(find.text('Atharva Patil'), findsOneWidget);
      expect(find.text('Rinku Sharma'), findsNothing);
    });

    testWidgets(
      'month filter updates P, S, A, and RATE columns for the selected month',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pumpAndSettle();

        // Open month filter dropdown
        final dropdownFinder = find.byType(DropdownButton<DateTime?>);
        expect(dropdownFinder, findsOneWidget);

        await tester.tap(dropdownFinder);
        await tester.pumpAndSettle();

        // Select 'October 2026' from the dropdown
        final octoberItem = find.text('October 2026').last;
        await tester.tap(octoberItem);
        await tester.pumpAndSettle();

        // Verify October Thursday dates are visible (01 Oct, 08 Oct, etc.)
        expect(find.text('01 Oct'), findsWidgets);
        expect(find.text('08 Oct'), findsWidgets);
        // Sep dates are no longer shown
        expect(find.text('03 Sep'), findsNothing);

        // Members remain visible; summary columns stay pinned (P/S/A/RATE).
        expect(find.text('Atharva Patil'), findsOneWidget);
        expect(find.text('Rinku Sharma'), findsOneWidget);
        expect(find.text('P'), findsWidgets);
        expect(find.text('RATE'), findsWidgets);
        // Present/Substitute counts are 0 for October (no Oct check-ins in fixtures).
        expect(find.text('0'), findsWidgets);
        // Past Oct Thursdays (e.g. 01 Oct when "today" is later) contribute Absents,
        // so RATE shows a percentage rather than a neutral dash.
        expect(find.textContaining('%'), findsWidgets);
      },
    );
  });
}
