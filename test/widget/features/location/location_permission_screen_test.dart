import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:go_router/go_router.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
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
import 'package:qr_checkin/features/location/data/datasources/location_device_data_source.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/usecases/validate_user_proximity.dart';
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

class _FakeDeviceLocation implements LocationDeviceDataSource {
  _FakeDeviceLocation(this.position, {this.pending, this.failFirst});

  final Position position;
  final Completer<Position>? pending;
  Object? failFirst;
  int calls = 0;
  int clears = 0;

  @override
  Future<Position> getCurrentPosition({
    bool permissionAlreadyGranted = false,
    bool forceRefresh = false,
  }) async {
    calls++;
    final failure = failFirst;
    if (failure != null) {
      failFirst = null;
      throw failure;
    }
    if (pending != null) return pending!.future;
    return position;
  }

  @override
  void clearCachedPosition() => clears++;
}

Position _position(double lat, double lon) => Position(
  latitude: lat,
  longitude: lon,
  timestamp: DateTime(2026, 10, 30, 11, 0),
  accuracy: 20,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

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

    group('smart location recovery', () {
      List<Override> gpsOverrides({
        required PermissionService service,
        LocationDeviceDataSource? device,
      }) => [
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
        permissionServiceProvider.overrideWithValue(service),
        if (device != null) locationDeviceDataSourceProvider.overrideWithValue(device),
      ];

      Widget gpsHarness({
        required PermissionService service,
        LocationDeviceDataSource? device,
        Key? key,
      }) {
        return ProviderScope(
          overrides: gpsOverrides(service: service, device: device),
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

      Future<void> settle(WidgetTester tester, [int frames = 8]) async {
        for (var i = 0; i < frames; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      testWidgets('undecided permission auto-shows system prompt then verifies', (
        tester,
      ) async {
        var prompts = 0;
        var permission = LocationPermission.denied;
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
        );
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => permission,
              getCurrentPositionFn: (_) async {
                prompts++;
                permission = LocationPermission.whileInUse;
                return _position(testLocation.latitude, testLocation.longitude);
              },
            ),
            device: device,
          ),
        );
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(prompts, 1);
        expect(device.calls, 1);
        expect(find.text('Continue to Check-In'), findsOneWidget);
      });

      testWidgets('Allow CTA recovers when auto prompt is dismissed', (
        tester,
      ) async {
        var permission = LocationPermission.denied;
        var allowFix = false;
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
        );
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => permission,
              getCurrentPositionFn: (_) async {
                if (!allowFix) {
                  throw const PermissionDeniedException('denied');
                }
                permission = LocationPermission.whileInUse;
                return _position(testLocation.latitude, testLocation.longitude);
              },
            ),
            device: device,
          ),
        );
        await settle(tester);

        expect(find.text(AppStrings.locationPermissionDenied), findsOneWidget);
        expect(find.text(AppStrings.locationPermissionAllow), findsOneWidget);
        expect(device.calls, 0);

        allowFix = true;
        await tester.ensureVisible(find.text(AppStrings.locationPermissionAllow));
        await tester.tap(find.text(AppStrings.locationPermissionAllow));
        await settle(tester, 12);

        expect(device.calls, 1);
        expect(find.text('Continue to Check-In'), findsOneWidget);
      });

      testWidgets('already granted verifies with zero taps (no dialog)', (
        tester,
      ) async {
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
        );
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => LocationPermission.whileInUse,
            ),
            device: device,
          ),
        );
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(AppStrings.locationPermissionAllow), findsNothing);
        expect(device.calls, 1);
        expect(find.text('Continue to Check-In'), findsOneWidget);
      });

      testWidgets('auto prompt dismissed shows neutral denied UI + Allow CTA', (
        tester,
      ) async {
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => LocationPermission.denied,
              getCurrentPositionFn: (_) async =>
                  throw const PermissionDeniedException('denied'),
            ),
          ),
        );
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text(AppStrings.locationPermissionDenied), findsOneWidget);
        expect(find.text(AppStrings.locationPermissionBlockedTitle), findsNothing);
        expect(find.text(AppStrings.locationServiceOffTitle), findsNothing);
        expect(find.text(AppStrings.locationPermissionAllow), findsOneWidget);
        expect(find.text(AppStrings.locationServiceHowTo), findsOneWidget);
        expect(find.textContaining('scan the QR again'), findsNothing);
        expect(find.textContaining('reload'), findsNothing);
      });

      testWidgets('blocked site shows settings guidance without Retry; '
          'resume after Allow verifies', (tester) async {
        var prompts = 0;
        var permission = LocationPermission.deniedForever;
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
        );
        final container = ProviderContainer(
          overrides: gpsOverrides(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => permission,
              requestPermission: () async {
                prompts++;
                return permission;
              },
              getCurrentPositionFn: (_) async {
                prompts++;
                return _position(0, 0);
              },
            ),
            device: device,
          ),
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
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
        await settle(tester);

        expect(find.text(AppStrings.locationPermissionBlockedTitle), findsOneWidget);
        expect(find.text(AppStrings.locationPermissionPermanentlyDenied), findsOneWidget);
        expect(find.text(AppStrings.locationBlockedAndroidHeading), findsOneWidget);
        for (final step in AppStrings.locationBlockedAndroidSteps) {
          expect(find.text(step), findsOneWidget);
        }
        expect(find.text(AppStrings.locationRetryShort), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(prompts, 0);

        // User allows in site settings, then returns to the tab.
        permission = LocationPermission.whileInUse;
        await container
            .read(locationValidationFamilyProvider(testLocation).notifier)
            .recheckAfterResume();
        await settle(tester);
        expect(find.text('Continue to Check-In'), findsOneWidget);
        expect(prompts, 0);
      });

      testWidgets('GPS off shows the Location is Turned Off dialog; Retry '
          'after enabling verifies', (tester) async {
        var gpsOn = false;
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
        );
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: false,
              isLocationServiceEnabled: () async => gpsOn,
              checkPermission: () async => LocationPermission.whileInUse,
            ),
            device: device,
          ),
        );
        await settle(tester);

        final dialog = find.byType(AlertDialog);
        expect(dialog, findsOneWidget);
        expect(
          find.descendant(
            of: dialog,
            matching: find.text(AppStrings.locationServiceOffTitle),
          ),
          findsOneWidget,
        );
        expect(find.text(AppStrings.locationServiceOffBody), findsWidgets);
        for (final step in AppStrings.locationServiceOffSteps) {
          expect(find.text(step), findsWidgets);
        }

        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.text(AppStrings.locationServiceHowTo),
          ),
        );
        await tester.pump();
        expect(find.text(AppStrings.locationServiceHowToDetails), findsOneWidget);

        gpsOn = true;
        await tester.tap(
          find.descendant(
            of: dialog,
            matching: find.text(AppStrings.locationServiceOffRetry),
          ),
        );
        await settle(tester);

        expect(find.byType(AlertDialog), findsNothing);
        expect(device.calls, 1);
        expect(find.text('Continue to Check-In'), findsOneWidget);
      });

      testWidgets('loading UI while fetching, then verified', (tester) async {
        final gate = Completer<Position>();
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
          pending: gate,
        );
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => LocationPermission.whileInUse,
            ),
            device: device,
          ),
        );
        await settle(tester);

        expect(find.text(AppStrings.locationFetchingPosition), findsWidgets);
        expect(find.text('Continue to Check-In'), findsNothing);

        gate.complete(_position(testLocation.latitude, testLocation.longitude));
        await settle(tester);
        expect(find.text('Continue to Check-In'), findsOneWidget);
      });

      testWidgets('timeout shows Retry; Retry recovers without rescan', (
        tester,
      ) async {
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
          failFirst: const LocationTimeoutException(),
        );
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => LocationPermission.whileInUse,
            ),
            device: device,
          ),
        );
        await settle(tester);

        expect(find.text(AppStrings.locationTimeout), findsOneWidget);
        await tester.ensureVisible(find.text(AppStrings.locationRetryShort));
        await tester.tap(find.text(AppStrings.locationRetryShort));
        await settle(tester);

        expect(device.calls, 2);
        expect(find.text('Continue to Check-In'), findsOneWidget);
      });

      testWidgets('outside radius shows panel and Retry Location, no bypass', (
        tester,
      ) async {
        final device = _FakeDeviceLocation(_position(19.0760, 72.8777));
        await tester.pumpWidget(
          gpsHarness(
            service: PermissionService(
              isWebOverride: true,
              checkPermission: () async => LocationPermission.whileInUse,
            ),
            device: device,
          ),
        );
        await settle(tester);

        expect(find.text('Outside Allowed Radius'), findsOneWidget);
        expect(find.text(AppStrings.locationRetry), findsOneWidget);
        expect(find.text('Continue to Check-In'), findsNothing);
      });

      testWidgets('verified fix navigates to the form with the same QR token', (
        tester,
      ) async {
        final device = _FakeDeviceLocation(
          _position(testLocation.latitude, testLocation.longitude),
        );
        final router = GoRouter(
          initialLocation: '/checkin/tok-abc',
          routes: [
            GoRoute(
              path: '/checkin/:sessionToken',
              builder: (context, state) {
                final token = state.pathParameters['sessionToken']!;
                final extra = state.extra;
                if (extra is Map && extra['proximity'] is ProximityResult) {
                  final p = extra['proximity'] as ProximityResult;
                  return Text('FORM $token verified=${p.isVerified}');
                }
                return Scaffold(
                  body: LocationPermissionScreen(
                    location: testLocation,
                    sessionToken: token,
                    sessionDateStr: '2026-10-30',
                    nowProvider: () => DateTime(2026, 10, 30, 11, 0),
                  ),
                );
              },
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: gpsOverrides(
              service: PermissionService(
                isWebOverride: true,
                checkPermission: () async => LocationPermission.whileInUse,
              ),
              device: device,
            ),
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await settle(tester, 12);

        expect(find.text('FORM tok-abc verified=true'), findsOneWidget);
      });

      testWidgets('remounted QR scan auto-prompts again without dialog', (
        tester,
      ) async {
        var prompts = 0;
        PermissionService service() => PermissionService(
          isWebOverride: true,
          checkPermission: () async => LocationPermission.denied,
          getCurrentPositionFn: (_) async {
            prompts++;
            throw const PermissionDeniedException('denied');
          },
        );

        await tester.pumpWidget(
          gpsHarness(service: service(), key: const ValueKey('scan-1')),
        );
        await settle(tester, 6);
        expect(find.byType(AlertDialog), findsNothing);
        expect(prompts, 1);
        expect(find.text(AppStrings.locationPermissionAllow), findsOneWidget);

        await tester.pumpWidget(
          gpsHarness(service: service(), key: const ValueKey('scan-2')),
        );
        await settle(tester, 6);
        expect(find.byType(AlertDialog), findsNothing);
        expect(prompts, 2);
        expect(find.text(AppStrings.locationPermissionAllow), findsOneWidget);
      });
    });

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
