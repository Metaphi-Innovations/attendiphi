import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/l10n/app_strings.dart';
import 'package:qr_checkin/core/utils/cookie_helper_stub.dart' as cookie_stub;
import 'package:qr_checkin/core/widgets/app_button.dart';
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/checkin/data/datasources/check_in_remote_data_source.dart';
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/domain/entities/public_device_session_attendance.dart';
import 'package:qr_checkin/features/checkin/presentation/providers/checkin_providers.dart';
import 'package:qr_checkin/features/checkin/presentation/screens/checkin_form_screen.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:qr_checkin/features/employee/presentation/providers/employee_providers.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/usecases/validate_user_proximity.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCheckInRemote extends Fake implements CheckInRemoteDataSource {
  _FakeCheckInRemote(this.publicAttendance);

  final PublicDeviceSessionAttendance? publicAttendance;

  @override
  Future<PublicDeviceSessionAttendance?> getPublicDeviceSessionAttendance({
    required String deviceId,
    required String sessionDateYmd,
  }) async => publicAttendance;

  @override
  Future<CheckInSubmission?> getDeviceSubmission(
    String deviceId,
    DateTime sessionDate,
  ) async => null;

  @override
  Future<bool> isDeviceSessionLocked({
    required String deviceId,
    required String sessionDateYmd,
  }) async => false;

  @override
  Future<CheckInSubmission?> getPublicCheckInSummary(String checkInId) async =>
      null;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cookie_stub.clearWebCookieMemoryForTests();
  });
  const testLocation = LocationConfig(
    id: 'test_venue',
    name: 'Jade Luxury Banquets, Mumbai',
    latitude: 18.9888622,
    longitude: 72.8152475,
    radiusMeters: 500.0,
    address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
  );

  const testProximity = ProximityResult(
    distanceMeters: 10.0,
    isWithinRadius: true,
    allowedRadiusMeters: 500.0,
    userLatitude: 18.9888622,
    userLongitude: 72.8152475,
    gpsAccuracy: 5.0,
  );

  final testEmployees = [
    const Employee(
      id: 'emp_1',
      name: 'Rohan Mehta',
      phone: '9876543210',
      email: 'rohan@example.com',
    ),
    const Employee(
      id: 'emp_2',
      name: 'Pooja Nair',
      phone: '9876543211',
      email: 'pooja@example.com',
    ),
    const Employee(
      id: 'emp_inactive',
      name: 'Inactive Person',
      phone: '9000000099',
      email: 'inactive@example.com',
      isActive: false,
    ),
  ];

  List<Override> baseOverrides({bool restrictionsEnabled = true}) => [
    checkInRestrictionsConfigProvider.overrideWith(
      (ref) => Stream.value(
        CheckInRestrictionsConfig(
          locationRestrictionEnabled: restrictionsEnabled,
          dateRestrictionEnabled: restrictionsEnabled,
          deviceRestrictionEnabled: restrictionsEnabled,
        ),
      ),
    ),
    locationConfigFamilyProvider('test_venue')
        .overrideWith((ref) => Future.value(testLocation)),
    publicMembersStreamProvider.overrideWith(
      (ref) => Stream.value(testEmployees),
    ),
    publicMembersOnceProvider.overrideWith(
      (ref) async => testEmployees,
    ),
    liveCheckInsStreamProvider.overrideWith(
      (ref) => Stream.value(const <CheckInSubmission>[]),
    ),
    sessionCheckedInMemberIdsProvider.overrideWith(
      (ref, sessionDateYmd) => Stream.value(const <String>{}),
    ),
  ];

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: baseOverrides(),
      child: MaterialApp(
        home: CheckInFormScreen(
          locationId: 'test_venue',
          proximityResult: testProximity,
          nowProvider: () => DateTime(2026, 9, 3, 10, 0),
        ),
      ),
    );
  }

  group('CheckInFormScreen Widget Tests', () {
    testWidgets('shows Thursday-only block notice when today is not Thursday', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: baseOverrides(),
          child: MaterialApp(
            home: CheckInFormScreen(
              locationId: 'test_venue',
              proximityResult: testProximity,
              nowProvider: () => DateTime(2026, 9, 9, 10, 0), // Wednesday
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Check-In Available on Thursday Only'), findsOneWidget);
    });

    testWidgets(
      'device restriction ON skips form when prior session submission exists',
      (tester) async {
        final submission = CheckInSubmission(
          id: 'sub-prior',
          locationId: 'test_venue',
          locationName: 'Jade Luxury Banquets, Mumbai',
          userName: 'Rohan Mehta',
          userPhone: '+919876543210',
          type: CheckInType.member,
          userLatitude: 18.9888622,
          userLongitude: 72.8152475,
          gpsAccuracy: 5,
          distanceMeters: 10,
          timestamp: DateTime(2026, 10, 30, 10, 0),
          memberId: 'emp_1',
        );
        final key = DeviceCheckInService().getSessionKey(
          sessionDateStr: '2026-10-30',
          locationId: 'test_venue',
        );
        final json = jsonEncode(submission.toMap());
        SharedPreferences.setMockInitialValues({
          key: json,
          'app_last_submission': json,
        });

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checkInRestrictionsConfigProvider.overrideWith(
                (ref) => Stream.value(
                  const CheckInRestrictionsConfig(
                    locationRestrictionEnabled: true,
                    dateRestrictionEnabled: false,
                    deviceRestrictionEnabled: true,
                  ),
                ),
              ),
              locationConfigFamilyProvider('test_venue').overrideWith(
                (ref) => Future.value(testLocation),
              ),
              publicMembersStreamProvider.overrideWith(
                (ref) => Stream.value(testEmployees),
              ),
              publicMembersOnceProvider.overrideWith(
                (ref) async => testEmployees,
              ),
              liveCheckInsStreamProvider.overrideWith(
                (ref) => Stream.value(const <CheckInSubmission>[]),
              ),
              sessionCheckedInMemberIdsProvider.overrideWith(
                (ref, sessionDateYmd) => Stream.value(const <String>{}),
              ),
            ],
            child: MaterialApp(
              home: CheckInFormScreen(
                locationId: 'test_venue',
                proximityResult: testProximity,
                sessionDateStr: '2026-10-30',
                nowProvider: () => DateTime(2026, 10, 30, 11, 0),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Attendance Recorded'), findsOneWidget);
        expect(find.text('Rohan Mehta'), findsOneWidget);
        expect(find.text('Select Member Name *'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Check-In'), findsNothing);
      },
    );

    testWidgets(
      'device ON + empty prefs + remote lock shows Attendance Recorded, not form',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final prior = CheckInSubmission(
          id: 'sub-rpc-form',
          locationId: 'test_venue',
          locationName: 'Jade Luxury Banquets, Mumbai',
          userName: 'Cached First',
          userPhone: '+919876543277',
          type: CheckInType.member,
          userLatitude: 18.9888622,
          userLongitude: 72.8152475,
          gpsAccuracy: 5,
          distanceMeters: 10,
          timestamp: DateTime(2026, 10, 30, 10, 0),
          // Not in the test roster — success card must use submission.userName.
          memberId: 'emp_unlisted',
        );
        final service = DeviceCheckInService(
          prefs,
          _FakeCheckInRemote(
            PublicDeviceSessionAttendance(
              locked: true,
              submission: prior,
              checkInId: prior.id,
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              deviceCheckInServiceProvider.overrideWithValue(service),
              checkInRestrictionsConfigProvider.overrideWith(
                (ref) => Stream.value(
                  const CheckInRestrictionsConfig(
                    locationRestrictionEnabled: true,
                    dateRestrictionEnabled: false,
                    deviceRestrictionEnabled: true,
                  ),
                ),
              ),
              locationConfigFamilyProvider('test_venue').overrideWith(
                (ref) => Future.value(testLocation),
              ),
              publicMembersStreamProvider.overrideWith(
                (ref) => Stream.value(testEmployees),
              ),
              publicMembersOnceProvider.overrideWith(
                (ref) async => testEmployees,
              ),
              liveCheckInsStreamProvider.overrideWith(
                (ref) => Stream.value(const <CheckInSubmission>[]),
              ),
              sessionCheckedInMemberIdsProvider.overrideWith(
                (ref, sessionDateYmd) => Stream.value(const <String>{}),
              ),
            ],
            child: MaterialApp(
              home: CheckInFormScreen(
                locationId: 'test_venue',
                proximityResult: testProximity,
                sessionDateStr: '2026-10-30',
                nowProvider: () => DateTime(2026, 10, 30, 11, 0),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Attendance Recorded'), findsOneWidget);
        expect(find.text('Cached First'), findsOneWidget);
        expect(find.text('Select Member Name *'), findsNothing);
        expect(find.widgetWithText(AppButton, 'Check-In'), findsNothing);
      },
    );

    testWidgets(
      'device OFF + empty prefs + remote lock still shows Member form',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final prior = CheckInSubmission(
          id: 'sub-standee-form',
          locationId: 'test_venue',
          locationName: 'Jade Luxury Banquets, Mumbai',
          userName: 'Must Not Gate',
          userPhone: '+919876543266',
          type: CheckInType.member,
          userLatitude: 18.9888622,
          userLongitude: 72.8152475,
          gpsAccuracy: 5,
          distanceMeters: 10,
          timestamp: DateTime(2026, 10, 30, 10, 0),
        );
        final service = DeviceCheckInService(
          prefs,
          _FakeCheckInRemote(
            PublicDeviceSessionAttendance(
              locked: true,
              submission: prior,
              checkInId: prior.id,
            ),
          ),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              deviceCheckInServiceProvider.overrideWithValue(service),
              checkInRestrictionsConfigProvider.overrideWith(
                (ref) => Stream.value(
                  const CheckInRestrictionsConfig(
                    locationRestrictionEnabled: true,
                    dateRestrictionEnabled: false,
                    deviceRestrictionEnabled: false,
                  ),
                ),
              ),
              locationConfigFamilyProvider('test_venue').overrideWith(
                (ref) => Future.value(testLocation),
              ),
              publicMembersStreamProvider.overrideWith(
                (ref) => Stream.value(testEmployees),
              ),
              publicMembersOnceProvider.overrideWith(
                (ref) async => testEmployees,
              ),
              liveCheckInsStreamProvider.overrideWith(
                (ref) => Stream.value(const <CheckInSubmission>[]),
              ),
              sessionCheckedInMemberIdsProvider.overrideWith(
                (ref, sessionDateYmd) => Stream.value(const <String>{}),
              ),
            ],
            child: MaterialApp(
              home: CheckInFormScreen(
                locationId: 'test_venue',
                proximityResult: testProximity,
                sessionDateStr: '2026-10-30',
                nowProvider: () => DateTime(2026, 10, 30, 11, 0),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Attendance Recorded'), findsNothing);
        expect(find.text('Must Not Gate'), findsNothing);
        expect(find.text('Select Member Name *'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Check-In'), findsOneWidget);
      },
    );

    testWidgets(
      'renders top Check-in Type options with Member selected by default',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Production QR: Member / Substitute / Visitor only (Face detached).
        expect(find.text('Member'), findsWidgets);
        expect(find.text('Substitute'), findsOneWidget);
        expect(find.text('Visitor'), findsOneWidget);
        expect(find.text('Face'), findsNothing);

        // Member is selected by default — dropdown UI, no face camera.
        expect(find.text('Member Face Verification'), findsNothing);
        expect(find.text('Face Verification'), findsNothing);
        expect(find.text('Take Live Selfie'), findsNothing);
        expect(find.text('Start Camera'), findsNothing);
        expect(find.text('Verify Face'), findsNothing);
        expect(find.text('Select Member Name *'), findsOneWidget);
        expect(find.text('Type to search your name'), findsOneWidget);
        expect(find.text('Search registered member...'), findsNothing);
        expect(find.text('Phone Number * (Auto-filled)'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Check-In'), findsOneWidget);

        // Check-In is present but disabled until a member is selected.
        final disabledButton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Check-In'),
        );
        expect(disabledButton.enabled, isFalse);
        expect(disabledButton.onPressed, isNull);
      },
    );

    testWidgets(
      'typing in name field filters members and selecting enables Check-In',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // No nested search field — typeahead is the name field itself.
        expect(find.text('Search registered member...'), findsNothing);
        expect(find.text('Type to search your name'), findsOneWidget);

        // Type into the name field to filter suggestions.
        await tester.enterText(find.byType(TextFormField).first, 'Rohan');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Search registered member...'), findsNothing);
        expect(find.text('Rohan Mehta'), findsOneWidget);
        expect(find.text('Pooja Nair'), findsNothing);

        await tester.tap(find.text('Rohan Mehta'));
        await tester.pump();
        // Allow suggestion-close delay + unfocus.
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Rohan Mehta'), findsOneWidget);
        expect(find.text('9876543210'), findsOneWidget);
        expect(find.text(AppStrings.validationPhoneRequired), findsNothing);

        final enabledButton = tester.widget<AppButton>(
          find.widgetWithText(AppButton, 'Check-In'),
        );
        expect(enabledButton.enabled, isTrue);
        expect(enabledButton.onPressed, isNotNull);
      },
    );

    testWidgets(
      'opening and closing member dropdown does not trigger phone required error, and selecting autofills without error',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Open dropdown via dropdown arrow icon
        await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Close dropdown via chevron
        await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        // Ensure phone required error was not triggered
        expect(find.text(AppStrings.validationPhoneRequired), findsNothing);

        // Now select a member
        await tester.enterText(find.byType(TextFormField).first, 'Pooja');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        await tester.tap(find.text('Pooja Nair'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Pooja Nair'), findsOneWidget);
        expect(find.text('9876543211'), findsOneWidget);
        expect(find.text(AppStrings.validationPhoneRequired), findsNothing);
      },
    );

    testWidgets('inactive members are not offered in member typeahead', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.byIcon(Icons.arrow_drop_down_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Rohan Mehta'), findsOneWidget);
      expect(find.text('Pooja Nair'), findsOneWidget);
      expect(find.text('Inactive Person'), findsNothing);
    });

    testWidgets(
      'switching to Substitute displays substitute form with member typeahead and photo card',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Substitute option
        await tester.tap(find.text('Substitute'));
        await tester.pump(const Duration(milliseconds: 200));

        // Verify Substitute-specific fields
        expect(find.text('Substitute Full Name *'), findsOneWidget);
        expect(find.text('Phone Number *'), findsOneWidget);
        expect(find.text('Email Address (Optional)'), findsOneWidget);
        expect(find.text('Substituting For (Member Name) *'), findsOneWidget);
        expect(find.text('Type to search member name'), findsOneWidget);
        expect(
          find.text('Select member you are substituting for'),
          findsNothing,
        );
        expect(find.text('Face Verification Photo *'), findsOneWidget);
      },
    );

    testWidgets(
      'selecting a member from substitute typeahead sets target member',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Substitute option
        await tester.tap(find.text('Substitute'));
        await tester.pump(const Duration(milliseconds: 200));

        // Focus substitute-for typeahead and type to filter
        final substituteForField = find.widgetWithText(
          TextFormField,
          'Type to search member name',
        );
        expect(substituteForField, findsOneWidget);
        await tester.tap(substituteForField);
        await tester.pump();
        await tester.enterText(substituteForField, 'Rohan');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Rohan Mehta'), findsOneWidget);
        await tester.tap(find.text('Rohan Mehta'));
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Rohan Mehta'), findsOneWidget);
      },
    );

    testWidgets(
      'substitute typeahead stays open after field unfocus (keyboard Done)',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Substitute'));
        await tester.pump(const Duration(milliseconds: 200));

        final substituteForField = find.widgetWithText(
          TextFormField,
          'Type to search member name',
        );
        await tester.tap(substituteForField);
        await tester.pump();
        await tester.enterText(substituteForField, 'Roh');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Rohan Mehta'), findsOneWidget);

        // Simulate soft-keyboard Done: unfocus without tapping outside.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump(const Duration(milliseconds: 300));

        // Suggestions must remain so the user can still pick a name.
        expect(find.text('Rohan Mehta'), findsOneWidget);
      },
    );

    testWidgets(
      'switching to Visitor displays visitor form with company, category, invited by typeahead',
      (tester) async {
        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Tap Visitor option
        await tester.tap(find.text('Visitor'));
        await tester.pump(const Duration(milliseconds: 200));

        // Verify Visitor-specific fields
        expect(find.text('Visitor Full Name *'), findsOneWidget);
        expect(find.text('Phone Number *'), findsOneWidget);
        expect(find.text('Email Address *'), findsOneWidget);
        expect(find.text('Invited By (Select Member) *'), findsOneWidget);
        expect(find.text('Type to search inviting member'), findsOneWidget);
        expect(find.text('Select member who invited you'), findsNothing);
      },
    );

    testWidgets(
      'selecting a member from invited-by typeahead sets inviting member',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.tap(find.text('Visitor'));
        await tester.pump(const Duration(milliseconds: 200));

        final invitedByField = find.widgetWithText(
          TextFormField,
          'Type to search inviting member',
        );
        expect(invitedByField, findsOneWidget);
        await tester.ensureVisible(invitedByField);
        await tester.tap(invitedByField);
        await tester.pump();
        await tester.enterText(invitedByField, 'Pooja');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('Pooja Nair'), findsOneWidget);
        await tester.tap(find.text('Pooja Nair'));
        await tester.pump(const Duration(milliseconds: 250));

        expect(find.text('Pooja Nair'), findsOneWidget);
      },
    );

    testWidgets(
      'switching tabs resets and clears fields so new tab starts empty',
      (tester) async {
        tester.view.physicalSize = const Size(1000, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Switch to Visitor and enter name
        await tester.tap(find.text('Visitor'));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.enterText(find.byType(TextField).first, 'John Doe');
        await tester.pump();

        // Switch to Substitute
        await tester.tap(find.text('Substitute'));
        await tester.pump(const Duration(milliseconds: 200));

        // Fields should be reset
        expect(find.text('John Doe'), findsNothing);
        expect(find.text('Enter your full name'), findsOneWidget);

        // Verify phone icon is present
        expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
      },
    );

    testWidgets('shows Visitor fields and submit button on Visitor tab', (
      tester,
    ) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Visitor
      await tester.tap(find.text('Visitor'));
      await tester.pump(const Duration(milliseconds: 200));

      // Visitor specific fields are present
      expect(find.text('Visitor Full Name *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);

      // Submit button is present with Check-In label
      expect(find.widgetWithText(AppButton, 'Check-In'), findsOneWidget);
    });
  });
}
