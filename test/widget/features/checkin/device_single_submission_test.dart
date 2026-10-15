import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/theme/app_theme.dart';
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/presentation/screens/checkin_result_screen.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:qr_checkin/features/employee/presentation/providers/employee_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

CheckInSubmission _submission({
  required String name,
  String phone = '+918356011246',
  String? memberId,
  CheckInType type = CheckInType.member,
  String id = 'sub-test-01',
}) {
  return CheckInSubmission(
    id: id,
    locationId: 'location_x',
    locationName: 'Excel Plaza, Ghatkopar',
    userName: name,
    userPhone: phone,
    type: type,
    userLatitude: 19.0834,
    userLongitude: 72.9140,
    gpsAccuracy: 4.0,
    distanceMeters: 10.0,
    timestamp: DateTime.now(),
    memberId: memberId,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  List<Override> memberOverrides(List<Employee> employees) {
    return [
      publicMembersStreamProvider.overrideWith(
        (ref) => Stream<List<Employee>>.value(employees),
      ),
      employeeByIdProvider.overrideWith((ref, id) async {
        for (final employee in employees) {
          if (employee.id == id) return employee;
        }
        return null;
      }),
    ];
  }

  group('Device Single Submission & Re-Scan Tests', () {
    testWidgets(
      'CheckInResultScreen displays recorded attendee details and synced status',
      (tester) async {
        final submission = _submission(
          name: 'Omkar Anarse',
          memberId: 'member_omkar',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: memberOverrides(const [
              Employee(
                id: 'member_omkar',
                name: 'Omkar Anarse',
                phone: '+918356011246',
              ),
            ]),
            child: MaterialApp(
              theme: AppTheme.light,
              home: CheckInResultScreen(submission: submission),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Attendance Recorded'), findsOneWidget);
        expect(find.text('Omkar Anarse'), findsOneWidget);
        expect(find.textContaining('+918356011246'), findsOneWidget);
        expect(
          find.textContaining('Your attendance has been recorded'),
          findsOneWidget,
        );
        // Verify "Add Another Check-in" button is completely removed
        expect(find.textContaining('Add Another Check-in'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'CheckInResultScreen shows submitted memberId even if a similar name exists',
      (tester) async {
        const omkar = Employee(
          id: 'member_omkar',
          name: 'Omkar Anarse',
          phone: '+918356011246',
        );
        const omkaarr = Employee(
          id: 'member_omkaarr',
          name: 'Omkaarr',
          phone: '+919000000001',
        );
        final submission = _submission(
          name: 'Omkaarr',
          phone: '+919000000001',
          memberId: 'member_omkar',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: memberOverrides(const [omkaarr, omkar]),
            child: MaterialApp(
              theme: AppTheme.light,
              home: CheckInResultScreen(submission: submission),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Omkar Anarse'), findsOneWidget);
        expect(find.text('Omkaarr'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('CheckInResultScreen shows Member B from their memberId', (
      tester,
    ) async {
      const memberB = Employee(
        id: 'member_b',
        name: 'Pooja Nair',
        phone: '+919876543210',
      );
      const memberC = Employee(
        id: 'member_c',
        name: 'Rohan Mehta',
        phone: '+919876543211',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: memberOverrides(const [memberB, memberC]),
          child: MaterialApp(
            theme: AppTheme.light,
            home: CheckInResultScreen(
              submission: _submission(
                id: 'sub-b',
                name: 'stale',
                phone: '+910000000000',
                memberId: 'member_b',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Pooja Nair'), findsOneWidget);
      expect(find.text('Rohan Mehta'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CheckInResultScreen shows Member C from their memberId', (
      tester,
    ) async {
      const memberB = Employee(
        id: 'member_b',
        name: 'Pooja Nair',
        phone: '+919876543210',
      );
      const memberC = Employee(
        id: 'member_c',
        name: 'Rohan Mehta',
        phone: '+919876543211',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: memberOverrides(const [memberB, memberC]),
          child: MaterialApp(
            theme: AppTheme.light,
            home: CheckInResultScreen(
              submission: _submission(
                id: 'sub-c',
                name: 'stale',
                phone: '+910000000000',
                memberId: 'member_c',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rohan Mehta'), findsOneWidget);
      expect(find.text('Pooja Nair'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'CheckInResultScreen auto-loads last submission from device storage if null extra is passed',
      (tester) async {
        final submission = _submission(
          id: 'sub-cached-01',
          name: 'Rahul Sharma',
          phone: '+919876543210',
          type: CheckInType.visitor,
        );

        final prefs = await SharedPreferences.getInstance();
        final service = DeviceCheckInService(prefs);
        await service.recordSubmission(
          sessionDateStr: '2026-09-03',
          submission: submission,
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              ...memberOverrides(const []),
            ],
            child: MaterialApp(
              theme: AppTheme.light,
              home: const CheckInResultScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Attendance Recorded'), findsOneWidget);
        expect(find.text('Rahul Sharma'), findsOneWidget);
        expect(find.textContaining('+919876543210'), findsOneWidget);
        expect(find.textContaining('Add Another Check-in'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'stale omkaaarr snapshot never replaces Omkar Anarse memberId',
      (tester) async {
        const omkar = Employee(
          id: 'member_omkar',
          name: 'Omkar Anarse',
          phone: '8356011246',
        );
        const inactiveDuplicate = Employee(
          id: 'member_omkar_inactive',
          name: 'omkar',
          phone: '8356011246',
          isActive: false,
        );
        final submission = _submission(
          name: 'omkaaarr',
          phone: '+918356011246',
          memberId: 'member_omkar',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: memberOverrides(const [inactiveDuplicate, omkar]),
            child: MaterialApp(
              theme: AppTheme.light,
              home: CheckInResultScreen(
                submission: submission,
                memberId: 'member_omkar',
                checkInId: submission.id,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Omkar Anarse'), findsOneWidget);
        expect(find.text('omkaaarr'), findsNothing);
        expect(find.text('omkar'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
