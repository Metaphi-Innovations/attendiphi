import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_dashboard_provider.dart';
import 'package:qr_checkin/features/admin/presentation/screens/visitor_management_screen.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';

void main() {
  final testVisitors = [
    CheckInSubmission(
      id: 'vis_1',
      locationId: 'loc_1',
      locationName: 'Excel Plaza',
      userName: 'Rahul Sharma',
      userPhone: '9876543210',
      userEmail: 'rahul@acme.com',
      type: CheckInType.visitor,
      companyName: 'Acme Corp',
      category: 'IT Services',
      invitedByMember: 'Atharva Patil',
      userLatitude: 19.0834,
      userLongitude: 72.9140,
      gpsAccuracy: 10,
      distanceMeters: 12,
      timestamp: DateTime(2026, 9, 3, 10, 30),
    ),
    // Duplicate record of Rahul Sharma with identical minute timestamp
    CheckInSubmission(
      id: 'vis_1_dup',
      locationId: 'loc_1',
      locationName: 'Excel Plaza',
      userName: 'Rahul Sharma',
      userPhone: '9876543210',
      userEmail: 'rahul@acme.com',
      type: CheckInType.visitor,
      companyName: 'Acme Corp',
      category: 'IT Services',
      invitedByMember: 'Atharva Patil',
      userLatitude: 19.0834,
      userLongitude: 72.9140,
      gpsAccuracy: 10,
      distanceMeters: 12,
      timestamp: DateTime(2026, 9, 3, 10, 30),
    ),
    CheckInSubmission(
      id: 'vis_2',
      locationId: 'loc_1',
      locationName: 'Excel Plaza',
      userName: 'Sneha Patel',
      userPhone: '9876543222',
      userEmail: 'sneha@design.com',
      type: CheckInType.visitor,
      companyName: 'Design Studio',
      category: 'Architecture',
      invitedByMember: 'Rinku Sharma',
      userLatitude: 19.0834,
      userLongitude: 72.9140,
      gpsAccuracy: 10,
      distanceMeters: 18,
      timestamp: DateTime(2026, 9, 3, 11, 0),
    ),
  ];

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        checkInsStreamProvider
            .overrideWith((ref) => Stream.value(testVisitors)),
      ],
      child: const MaterialApp(
        home: VisitorManagementScreen(),
      ),
    );
  }

  group('VisitorManagementScreen Widget Tests', () {
    testWidgets('renders screen title, live badge, and toolbar filters without KPI cards',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('Visitors Overview'), findsOneWidget);
      expect(find.text('LIVE VISITORS'), findsNothing);

      // Verify 4 KPI summary cards are removed
      expect(find.text('Total Visitors'), findsNothing);
      expect(find.text('Unique Companies'), findsNothing);
      expect(find.text('Unique Categories'), findsNothing);
      expect(find.text('Top Inviting Member'), findsNothing);

      // Verify table headers rendered cleanly
      expect(find.text('GPS STATUS'), findsOneWidget);
      expect(find.text('ACTIONS'), findsOneWidget);

      // Verify Thursday session dropdown filter
      expect(find.text('All Thursdays / All Dates'), findsOneWidget);

      // Verify pagination footer bar is removed
      expect(find.textContaining('Showing 1–'), findsNothing);
      expect(find.text('Rows per page:'), findsNothing);
    });

    testWidgets('displays visitors tabular data, On-site status, and deduplicates duplicate rows',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Check visitor names - Rahul Sharma appears exactly once despite duplicate stream item
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Sneha Patel'), findsOneWidget);

      // Check company names
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('Design Studio'), findsOneWidget);

      // Check GPS status indicators (only "On-site" without distance meter suffix)
      expect(find.text('On-site'), findsNWidgets(2));

      // Check action icons (Edit Details and View Details rendered; Flag and Delete removed)
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.visibility_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('searches visitors by company name accurately',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Search for "Acme"
      await tester.enterText(find.byType(TextField), 'Acme');
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Sneha Patel'), findsNothing);
    });
  });
}
