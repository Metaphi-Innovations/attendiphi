import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/widgets/app_button.dart';
import 'package:qr_checkin/features/checkin/presentation/screens/checkin_form_screen.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:qr_checkin/features/employee/presentation/providers/employee_providers.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/usecases/validate_user_proximity.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });
  const testLocation = LocationConfig(
    id: 'test_venue',
    name: 'Excel Plaza, Ghatkopar',
    latitude: 19.083462,
    longitude: 72.914026,
    radiusMeters: 500.0,
    address: 'EXCEL PLAZA, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400075',
  );

  const testProximity = ProximityResult(
    distanceMeters: 10.0,
    isWithinRadius: true,
    allowedRadiusMeters: 500.0,
    userLatitude: 19.083462,
    userLongitude: 72.914026,
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
  ];

  Widget createWidgetUnderTest() {
    return ProviderScope(
      overrides: [
        locationConfigFamilyProvider('test_venue').overrideWith(
          (ref) => Future.value(testLocation),
        ),
        employeesStreamProvider.overrideWith(
          (ref) => Stream.value(testEmployees),
        ),
      ],
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
    testWidgets('shows Thursday-only block notice when today is not Thursday', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            locationConfigFamilyProvider('test_venue').overrideWith(
              (ref) => Future.value(testLocation),
            ),
            employeesStreamProvider.overrideWith(
              (ref) => Stream.value(testEmployees),
            ),
          ],
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

    testWidgets('renders top Check-in Type options: Member, Substitute, Visitor', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify top 3 type options
      expect(find.text('Member'), findsWidgets);
      expect(find.text('Substitute'), findsOneWidget);
      expect(find.text('Visitor'), findsOneWidget);

      // By default Member fields are visible
      expect(find.text('Select Member Name *'), findsOneWidget);
      expect(find.text('Phone Number * (Auto-filled)'), findsOneWidget);
    });

    testWidgets('selecting a member from dropdown auto-fills name and phone number', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap on member dropdown button
      final dropdownBtn = find.byTooltip('Select member');
      expect(dropdownBtn, findsOneWidget);
      await tester.tap(dropdownBtn);
      await tester.pump(const Duration(milliseconds: 200));

      // Select Rohan Mehta
      expect(find.text('Rohan Mehta'), findsOneWidget);
      await tester.tap(find.text('Rohan Mehta'));
      await tester.pump(const Duration(milliseconds: 200));

      // Name and Phone fields should be auto-filled
      expect(find.text('Rohan Mehta'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);
    });

    testWidgets('switching to Substitute displays substitute form with member dropdown and photo card', (tester) async {
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
      expect(find.text('Face Verification Photo *'), findsOneWidget);
    });

    testWidgets('switching to Visitor displays visitor form with company, category, invited by', (tester) async {
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
    });

    testWidgets('switching tabs resets and clears fields so new tab starts empty', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Auto-fill member
      final dropdownBtn = find.byTooltip('Select member');
      await tester.tap(dropdownBtn);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.text('Rohan Mehta'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Rohan Mehta'), findsOneWidget);
      expect(find.text('9876543210'), findsOneWidget);

      // Switch to Substitute
      await tester.tap(find.text('Substitute'));
      await tester.pump(const Duration(milliseconds: 200));

      // Fields should be empty now
      expect(find.text('Rohan Mehta'), findsNothing);
      expect(find.text('9876543210'), findsNothing);
      expect(find.text('Enter your full name'), findsOneWidget);

      // Verify phone icon is present
      expect(find.byIcon(Icons.phone_rounded), findsOneWidget);
    });

    testWidgets('shows Visitor fields and submit button on Visitor tab', (tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Switch to Visitor
      await tester.tap(find.text('Visitor'));
      await tester.pump(const Duration(milliseconds: 200));

      // Visitor specific fields are present
      expect(find.text('Visitor Full Name *'), findsOneWidget);
      expect(find.text('Email Address *'), findsOneWidget);

      // Submit button is present
      expect(find.widgetWithText(AppButton, 'Check In'), findsOneWidget);
    });
  });
}
