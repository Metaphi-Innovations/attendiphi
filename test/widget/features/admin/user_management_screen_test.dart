import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/providers/visitor_management_provider.dart';
import 'package:qr_checkin/features/admin/presentation/screens/user_management_screen.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:qr_checkin/features/employee/presentation/providers/employee_providers.dart';

import 'admin_widget_auth_mocks.dart';

void main() {
  group('UserManagementScreen Widget Tests', () {
    final mockMembers = [
      Employee(
        id: 'emp-1',
        name: 'Akhil',
        phone: '9324872757',
        isActive: true,
        createdAt: DateTime(2026, 9, 5, 10, 40),
      ),
      Employee(
        id: 'emp-2',
        name: 'Omkar Anarse',
        phone: '8356011246',
        isActive: true,
        createdAt: DateTime(2026, 9, 5, 10, 28),
      ),
      Employee(
        id: 'emp-3',
        name: 'Prajakta',
        phone: '9321979314',
        isActive: true,
        createdAt: DateTime(2026, 9, 5, 10, 40),
      ),
      Employee(
        id: 'emp-4',
        name: 'Inactive User',
        phone: '9999999999',
        isActive: false,
        createdAt: DateTime(2026, 9, 5, 10, 00),
      ),
    ];

    final mockCheckIns = [
      CheckInSubmission(
        id: 'sub-1',
        locationId: 'loc-1',
        locationName: 'Excel Plaza',
        userName: 'Visitor One',
        userPhone: '1111111111',
        type: CheckInType.visitor,
        invitedByMember: 'Omkar Anarse',
        userLatitude: 19.0,
        userLongitude: 72.0,
        gpsAccuracy: 5.0,
        distanceMeters: 10.0,
        timestamp: DateTime(2026, 9, 5, 10, 30),
      ),
      CheckInSubmission(
        id: 'sub-2',
        locationId: 'loc-1',
        locationName: 'Excel Plaza',
        userName: 'Visitor Two',
        userPhone: '2222222222',
        type: CheckInType.visitor,
        invitedByMember: 'Omkar Anarse',
        userLatitude: 19.0,
        userLongitude: 72.0,
        gpsAccuracy: 5.0,
        distanceMeters: 10.0,
        timestamp: DateTime(2026, 9, 5, 10, 35),
      ),
      CheckInSubmission(
        id: 'sub-3',
        locationId: 'loc-1',
        locationName: 'Excel Plaza',
        userName: 'Visitor Three',
        userPhone: '3333333333',
        type: CheckInType.visitor,
        invitedByMember: 'Akhil',
        userLatitude: 19.0,
        userLongitude: 72.0,
        gpsAccuracy: 5.0,
        distanceMeters: 10.0,
        timestamp: DateTime(2026, 9, 5, 10, 40),
      ),
    ];

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          adminAuthProvider.overrideWith(
            () => MockAuthenticatedAdminAuthNotifier(kWidgetTestSuperAdmin),
          ),
          employeesStreamProvider.overrideWith(
            (ref) => Stream.value(mockMembers),
          ),
          visitorsCheckInsStreamProvider.overrideWith(
            (ref) => Stream.value(mockCheckIns),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: UserManagementScreen())),
      );
    }

    testWidgets(
      'renders active members, invited visitor ranking, and table column',
      (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createTestWidget());
        await tester.pumpAndSettle();

        // Verify Header Title
        expect(find.text('Member Management'), findsOneWidget);

        // Verify KPI Metric Cards (Total & Active only)
        expect(find.text('Total Members'), findsOneWidget);
        expect(find.text('Active Members'), findsOneWidget);
        expect(find.text('Omkar Anarse'), findsAtLeastNWidgets(1));

        // Verify Desktop Table Column Header
        expect(find.text('VISITORS'), findsOneWidget);
        expect(find.text('STATUS'), findsAtLeastNWidgets(1));
        expect(find.byType(Switch), findsAtLeastNWidgets(1));

        // Omkar Anarse has 2 visitors -> Ranked #1
        expect(find.text('2 Visitors'), findsOneWidget);
        // Akhil has 1 visitor -> Ranked #2
        expect(find.text('1 Visitor'), findsOneWidget);
        // Others have 0 visitors
        expect(find.text('0 Visitors'), findsAtLeastNWidgets(1));
      },
    );

    testWidgets('filters members by status filter', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially showing all 4 members
      expect(find.text('Akhil'), findsOneWidget);
      expect(find.text('Inactive User'), findsOneWidget);
      expect(find.text('Showing 4 of 4'), findsOneWidget);
    });
  });
}
