import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/presentation/screens/location_permission_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
            ),
          ),
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
        expect(find.text('Allowed Perimeter:'), findsOneWidget);
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
      expect(find.text('Allowed Perimeter:'), findsOneWidget);
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
      expect(find.text('Allowed Perimeter:'), findsOneWidget);
      expect(find.text('Outside Allowed Radius'), findsNothing);
    });
  });
}
