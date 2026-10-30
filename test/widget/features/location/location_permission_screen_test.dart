import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:qr_checkin/core/l10n/app_strings.dart';
import 'package:qr_checkin/core/permissions/permission_service.dart';
import 'package:qr_checkin/core/utils/cookie_helper_stub.dart' as cookie_stub;
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/checkin/data/datasources/check_in_remote_data_source.dart';
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/domain/entities/public_device_session_attendance.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_providers.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_validation_provider.dart';
import 'package:qr_checkin/features/location/presentation/screens/location_permission_screen.dart';
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

  Widget createWidgetUnderTest({
    String? sessionDateStr,
    DateTime Function()? nowProvider,
    bool restrictionsEnabled = true,
  }) {
    return ProviderScope(
      overrides: [
        checkInRestrictionsConfigProvider.overrideWith(
          (ref) => Stream.value(
            CheckInRestrictionsConfig(
              locationRestrictionEnabled: restrictionsEnabled,
              dateRestrictionEnabled: restrictionsEnabled,
              deviceRestrictionEnabled: restrictionsEnabled,
            ),
          ),
        ),
        locationConfigFamilyProvider(testLocation.id).overrideWith(
          (ref) async => testLocation,
        ),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: LocationPermissionScreen(
            location: testLocation,
            sessionDateStr: sessionDateStr,
            nowProvider: nowProvider ?? () => DateTime(2026, 9, 3, 10, 0),
          ),
        ),
      ),
    );
  }

  group('LocationPermissionScreen Date Validation Widget Tests', () {
    testWidgets('shows THURSDAY ONLY notice when opened on a non-Thursday', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          sessionDateStr: null,
          nowProvider: () => DateTime(2026, 9, 9, 10, 0), // Wednesday
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('THURSDAY ONLY'), findsOneWidget);
      expect(find.text('Check-In Closed Today'), findsOneWidget);
      expect(find.text('Allowed Perimeter:'), findsNothing);
    });

    testWidgets('shows SESSION EXPIRED when scanned QR date has passed', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(sessionDateStr: '2026-08-27'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('SESSION EXPIRED'), findsOneWidget);
      expect(find.text('QR Standee Expired'), findsOneWidget);
      expect(find.text('Scan Active Standee'), findsNothing);
      // Ensure GPS radar was not rendered in expired state
      expect(find.text('Allowed Perimeter:'), findsNothing);
    });

    testWidgets(
      'activates session and initiates location check for today Thursday',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(sessionDateStr: '2026-09-03'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('SESSION EXPIRED'), findsNothing);
        expect(find.text('UPCOMING SESSION'), findsNothing);
        expect(find.text('Jade Luxury Banquets, Mumbai'), findsOneWidget);
        expect(find.text('Allowed Perimeter:'), findsNothing);
      },
    );

    testWidgets(
      'shows SESSION EXPIRED for past Thursday QR when today is later',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(
            sessionDateStr: '2026-09-03',
            nowProvider: () => DateTime(2026, 9, 24, 10, 0),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('SESSION EXPIRED'), findsOneWidget);
        expect(find.text('QR Standee Expired'), findsOneWidget);
        expect(find.text('Allowed Perimeter:'), findsNothing);
      },
    );

    testWidgets(
      'shows UPCOMING SESSION when scanned QR date is in the future',
      (tester) async {
        await tester.pumpWidget(
          createWidgetUnderTest(sessionDateStr: '2027-09-24'),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('UPCOMING SESSION'), findsOneWidget);
        expect(find.text('Session Not Active Yet'), findsOneWidget);
        expect(find.text('Scan Another QR'), findsNothing);
        expect(find.text('Allowed Perimeter:'), findsNothing);
      },
    );

    testWidgets(
      'device ON + prior submission shows Attendance Recorded, not GPS form',
      (tester) async {
        final submission = CheckInSubmission(
          id: 'sub-loc',
          locationId: testLocation.id,
          locationName: testLocation.name,
          userName: 'Pooja Nair',
          userPhone: '+919876543211',
          type: CheckInType.member,
          userLatitude: testLocation.latitude,
          userLongitude: testLocation.longitude,
          gpsAccuracy: 8,
          distanceMeters: 4,
          timestamp: DateTime(2026, 10, 30, 10, 0),
          memberId: 'emp_2',
        );
        final key = DeviceCheckInService().getSessionKey(
          sessionDateStr: '2026-10-30',
          locationId: testLocation.id,
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
              locationConfigFamilyProvider(testLocation.id).overrideWith(
                (ref) async => testLocation,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LocationPermissionScreen(
                  location: testLocation,
                  sessionDateStr: '2026-10-30',
                  nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        // Config invalidate on open + GPay success animation timers.
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Attendance Recorded'), findsOneWidget);
        expect(find.text('Pooja Nair'), findsOneWidget);
        expect(find.text('Allowed Perimeter:'), findsNothing);
        expect(find.text('Select Member Name *'), findsNothing);
      },
    );

    testWidgets(
      'device ON + empty prefs + remote lock shows Attendance Recorded',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final prior = CheckInSubmission(
          id: 'sub-rpc',
          locationId: testLocation.id,
          locationName: testLocation.name,
          userName: 'Remote Member',
          userPhone: '+919876543299',
          type: CheckInType.member,
          userLatitude: testLocation.latitude,
          userLongitude: testLocation.longitude,
          gpsAccuracy: 10,
          distanceMeters: 5,
          timestamp: DateTime(2026, 10, 30, 9, 30),
          memberId: 'emp_rpc',
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
              locationConfigFamilyProvider(testLocation.id).overrideWith(
                (ref) async => testLocation,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LocationPermissionScreen(
                  location: testLocation,
                  sessionDateStr: '2026-10-30',
                  nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        // Config invalidate on open + GPay success animation timers.
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Attendance Recorded'), findsOneWidget);
        expect(find.text('Remote Member'), findsOneWidget);
        expect(find.text('Allowed Perimeter:'), findsNothing);
        expect(find.text('Select Member Name *'), findsNothing);
      },
    );

    testWidgets(
      'device OFF + empty prefs + remote lock still shows GPS / form path',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final prior = CheckInSubmission(
          id: 'sub-standee',
          locationId: testLocation.id,
          locationName: testLocation.name,
          userName: 'Should Not Show',
          userPhone: '+919876543288',
          type: CheckInType.member,
          userLatitude: testLocation.latitude,
          userLongitude: testLocation.longitude,
          gpsAccuracy: 10,
          distanceMeters: 5,
          timestamp: DateTime(2026, 10, 30, 9, 30),
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
              locationConfigFamilyProvider(testLocation.id).overrideWith(
                (ref) async => testLocation,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LocationPermissionScreen(
                  location: testLocation,
                  sessionDateStr: '2026-10-30',
                  nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('Attendance Recorded'), findsNothing);
        expect(find.text('Should Not Show'), findsNothing);
        expect(find.text(testLocation.name), findsOneWidget);
        expect(find.text('Allowed Perimeter:'), findsNothing);
      },
    );

    testWidgets(
      'fresh QR shows in-app Allow dialog before any permission request',
      (tester) async {
        var permissionRequests = 0;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checkInRestrictionsConfigProvider.overrideWith(
                (ref) => Stream.value(
                  const CheckInRestrictionsConfig(
                    locationRestrictionEnabled: true,
                    dateRestrictionEnabled: false,
                    deviceRestrictionEnabled: false,
                  ),
                ),
              ),
              locationConfigFamilyProvider(testLocation.id).overrideWith(
                (ref) async => testLocation,
              ),
              permissionServiceProvider.overrideWithValue(
                PermissionService(
                  isWebOverride: true,
                  isLocationServiceEnabled: () async => true,
                  checkPermission: () async => LocationPermission.whileInUse,
                  requestPermission: () async {
                    permissionRequests++;
                    return LocationPermission.whileInUse;
                  },
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LocationPermissionScreen(
                  location: testLocation,
                  sessionDateStr: '2026-10-30',
                  nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text(AppStrings.locationPermissionDialogTitle), findsOneWidget);
        expect(find.text(AppStrings.locationPermissionDialogBody), findsOneWidget);
        expect(find.text(AppStrings.locationPermissionAllow), findsWidgets);
        expect(permissionRequests, 0);
      },
    );

    testWidgets(
      'Allow in dialog then deny shows guidance and Allow Location CTA',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checkInRestrictionsConfigProvider.overrideWith(
                (ref) => Stream.value(
                  const CheckInRestrictionsConfig(
                    locationRestrictionEnabled: true,
                    dateRestrictionEnabled: false,
                    deviceRestrictionEnabled: false,
                  ),
                ),
              ),
              locationConfigFamilyProvider(testLocation.id).overrideWith(
                (ref) async => testLocation,
              ),
              permissionServiceProvider.overrideWithValue(
                PermissionService(
                  isWebOverride: true,
                  isLocationServiceEnabled: () async => true,
                  checkPermission: () async => LocationPermission.deniedForever,
                  requestPermission: () async =>
                      LocationPermission.deniedForever,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LocationPermissionScreen(
                  location: testLocation,
                  sessionDateStr: '2026-10-30',
                  nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text(AppStrings.locationPermissionDialogTitle), findsOneWidget);
        await tester.tap(find.text(AppStrings.locationPermissionAllow).last);
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text(AppStrings.locationPermissionPermanentlyDenied), findsNothing);
        expect(find.text(AppStrings.locationPermissionDenied), findsOneWidget);
        expect(find.text(AppStrings.locationRetry), findsNothing);
        expect(find.text(AppStrings.locationPermissionAllow), findsOneWidget);
      },
    );

    testWidgets(
      'OS location off after Allow shows turn-on guidance with Allow CTA',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              checkInRestrictionsConfigProvider.overrideWith(
                (ref) => Stream.value(
                  const CheckInRestrictionsConfig(
                    locationRestrictionEnabled: true,
                    dateRestrictionEnabled: false,
                    deviceRestrictionEnabled: false,
                  ),
                ),
              ),
              locationConfigFamilyProvider(testLocation.id).overrideWith(
                (ref) async => testLocation,
              ),
              permissionServiceProvider.overrideWithValue(
                PermissionService(
                  isWebOverride: true,
                  isLocationServiceEnabled: () async => false,
                  checkPermission: () async => LocationPermission.deniedForever,
                  requestPermission: () async =>
                      LocationPermission.deniedForever,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LocationPermissionScreen(
                  location: testLocation,
                  sessionDateStr: '2026-10-30',
                  nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                ),
              ),
            ),
          ),
        );
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        await tester.tap(find.text(AppStrings.locationPermissionAllow).last);
        await tester.pump();
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.text(AppStrings.locationPermissionPermanentlyDenied), findsNothing);
        expect(find.textContaining('Location is blocked'), findsNothing);
        expect(find.text(AppStrings.locationServiceDisabled), findsOneWidget);
        expect(find.text(AppStrings.locationRetry), findsNothing);
        expect(find.text(AppStrings.locationPermissionAllow), findsOneWidget);
      },
    );

    testWidgets(
      'remounted QR scan shows the Allow dialog again',
      (tester) async {
        Widget buildScreen({required Key key}) {
          return ProviderScope(
            overrides: [
              checkInRestrictionsConfigProvider.overrideWith(
                (ref) => Stream.value(
                  const CheckInRestrictionsConfig(
                    locationRestrictionEnabled: true,
                    dateRestrictionEnabled: false,
                    deviceRestrictionEnabled: false,
                  ),
                ),
              ),
              locationConfigFamilyProvider(testLocation.id).overrideWith(
                (ref) async => testLocation,
              ),
              permissionServiceProvider.overrideWithValue(
                PermissionService(
                  isWebOverride: true,
                  isLocationServiceEnabled: () async => true,
                  checkPermission: () async => LocationPermission.whileInUse,
                  requestPermission: () async => LocationPermission.whileInUse,
                ),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: LocationPermissionScreen(
                  key: key,
                  location: testLocation,
                  sessionDateStr: '2026-10-30',
                  nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                ),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildScreen(key: const ValueKey('scan-1')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text(AppStrings.locationPermissionDialogTitle), findsOneWidget);

        // Dismiss without allowing, then remount as a new QR scan.
        await tester.tap(find.text(AppStrings.locationPermissionNotNow));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.pumpWidget(buildScreen(key: const ValueKey('scan-2')));
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(find.text(AppStrings.locationPermissionDialogTitle), findsOneWidget);
      },
    );

    testWidgets('skips Thursday/expired gates when restrictions are OFF', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          sessionDateStr: '2026-08-27',
          nowProvider: () => DateTime(2026, 9, 9, 10, 0), // Wednesday + past QR
          restrictionsEnabled: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('THURSDAY ONLY'), findsNothing);
      expect(find.text('SESSION EXPIRED'), findsNothing);
      // Location UI still shown; GPS radius is not enforced when OFF.
      expect(find.text('Jade Luxury Banquets, Mumbai'), findsOneWidget);
      expect(find.text('Allowed Perimeter:'), findsNothing);
      expect(find.text('Outside Allowed Radius'), findsNothing);
    });

    testWidgets('allows upcoming QR date when restrictions are OFF', (
      tester,
    ) async {
      await tester.pumpWidget(
        createWidgetUnderTest(
          sessionDateStr: '2026-10-15',
          nowProvider: () => DateTime(2026, 10, 5, 10, 0), // Monday
          restrictionsEnabled: false,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('UPCOMING SESSION'), findsNothing);
      expect(find.text('THURSDAY ONLY'), findsNothing);
      expect(find.text('Jade Luxury Banquets, Mumbai'), findsOneWidget);
      expect(find.text('Allowed Perimeter:'), findsNothing);
      expect(find.text('Outside Allowed Radius'), findsNothing);
    });
  });
}
