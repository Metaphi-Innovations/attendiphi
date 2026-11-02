import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/cookie_helper_stub.dart' as cookie_stub;
import 'package:qr_checkin/features/checkin/data/datasources/check_in_remote_data_source.dart';
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/presentation/providers/checkin_providers.dart';
import 'package:qr_checkin/features/checkin/presentation/screens/checkin_result_screen.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:qr_checkin/features/employee/presentation/providers/employee_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCheckInRemote extends Fake implements CheckInRemoteDataSource {
  _FakeCheckInRemote({this.summary});

  CheckInSubmission? summary;
  int summaryCalls = 0;

  @override
  Future<CheckInSubmission?> getPublicCheckInSummary(String checkInId) async {
    summaryCalls++;
    return summary;
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cookie_stub.clearWebCookieMemoryForTests();
  });

  final prior = CheckInSubmission(
    id: 'sub-result-1',
    locationId: 'location_x',
    locationName: 'Metaphi',
    userName: 'Omkar anarse',
    userPhone: '8356011246',
    type: CheckInType.member,
    userLatitude: 19.08,
    userLongitude: 72.91,
    gpsAccuracy: 10,
    distanceMeters: 5,
    timestamp: DateTime(2026, 10, 30, 10, 0),
    memberId: 'mem-omkar',
  );

  testWidgets(
    'null submission + checkInId hydrates name, phone, and type from public RPC',
    (tester) async {
      final remote = _FakeCheckInRemote(summary: prior);
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkInRemoteDataSourceProvider.overrideWithValue(remote),
            sharedPreferencesProvider.overrideWithValue(prefs),
            deviceCheckInServiceProvider.overrideWithValue(
              DeviceCheckInService(prefs, remote),
            ),
            publicMembersStreamProvider.overrideWith(
              (ref) => Stream.value(const <Employee>[]),
            ),
            employeeByIdProvider('mem-omkar').overrideWith(
              (ref) async => null,
            ),
          ],
          child: const MaterialApp(
            home: CheckInResultScreen(
              checkInId: 'sub-result-1',
              memberId: 'mem-omkar',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Attendance Recorded'), findsOneWidget);
      expect(find.text('Omkar anarse'), findsOneWidget);
      expect(find.textContaining('8356011246'), findsOneWidget);
      expect(find.textContaining('Member'), findsOneWidget);
      expect(remote.summaryCalls, 1);
    },
  );

  testWidgets(
    'null submission + empty ids stays generic (no blank identity required)',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      cookie_stub.clearWebCookieMemoryForTests();
      final prefs = await SharedPreferences.getInstance();
      final remote = _FakeCheckInRemote();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            checkInRemoteDataSourceProvider.overrideWithValue(remote),
            sharedPreferencesProvider.overrideWithValue(prefs),
            deviceCheckInServiceProvider.overrideWithValue(
              DeviceCheckInService(prefs, remote),
            ),
            publicMembersStreamProvider.overrideWith(
              (ref) => Stream.value(const <Employee>[]),
            ),
          ],
          child: const MaterialApp(home: CheckInResultScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Attendance Recorded'), findsOneWidget);
      expect(find.text('Omkar anarse'), findsNothing);
      expect(remote.summaryCalls, 0);
    },
  );

  testWidgets(
    'submission extra shows Substitute type without waiting on RPC',
    (tester) async {
      final sub = prior.copyWith(
        id: 'sub-sub',
        userName: 'Priya Shah',
        userPhone: '9876543210',
        type: CheckInType.substitute,
        memberId: null,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicMembersStreamProvider.overrideWith(
              (ref) => Stream.value(const <Employee>[]),
            ),
          ],
          child: MaterialApp(
            home: CheckInResultScreen(submission: sub),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Priya Shah'), findsOneWidget);
      expect(find.textContaining('Substitute'), findsOneWidget);
    },
  );

  testWidgets(
    'Substitute success shows substitute name/phone, not covered member',
    (tester) async {
      const covered = Employee(
        id: 'member_covered',
        name: 'omkar anarseF',
        phone: '9876543213',
      );
      final sub = prior.copyWith(
        id: 'sub-yash',
        userName: 'yashraj',
        userPhone: '8356011246',
        type: CheckInType.substitute,
        memberId: covered.id,
        substituteForMember: covered.name,
        substituteName: 'yashraj',
        substitutePhone: '8356011246',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            publicMembersStreamProvider.overrideWith(
              (ref) => Stream.value(const [covered]),
            ),
            employeeByIdProvider(covered.id).overrideWith(
              (ref) async => covered,
            ),
          ],
          child: MaterialApp(
            home: CheckInResultScreen(
              submission: sub,
              memberId: covered.id,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('yashraj'), findsOneWidget);
      expect(find.textContaining('8356011246'), findsOneWidget);
      expect(find.textContaining('Substitute'), findsOneWidget);
      expect(find.text('omkar anarseF'), findsNothing);
      expect(find.textContaining('9876543213'), findsNothing);
    },
  );

  testWidgets('submission extra shows Visitor type', (tester) async {
    final visitor = prior.copyWith(
      id: 'sub-vis',
      userName: 'Alex Guest',
      userPhone: '9000000001',
      type: CheckInType.visitor,
      memberId: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          publicMembersStreamProvider.overrideWith(
            (ref) => Stream.value(const <Employee>[]),
          ),
        ],
        child: MaterialApp(
          home: CheckInResultScreen(submission: visitor),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Alex Guest'), findsOneWidget);
    expect(find.textContaining('Visitor'), findsOneWidget);
  });
}
