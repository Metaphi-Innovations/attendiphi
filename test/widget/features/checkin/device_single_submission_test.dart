import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/theme/app_theme.dart';
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/presentation/screens/checkin_result_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Device Single Submission & Re-Scan Tests', () {
    testWidgets('CheckInResultScreen displays recorded attendee details and synced status', (tester) async {
      final now = DateTime.now();
      final submission = CheckInSubmission(
        id: 'sub-test-01',
        locationId: 'location_x',
        locationName: 'Excel Plaza, Ghatkopar',
        userName: 'Omkar Anarse',
        userPhone: '+918356011246',
        type: CheckInType.member,
        userLatitude: 19.0834,
        userLongitude: 72.9140,
        gpsAccuracy: 4.0,
        distanceMeters: 10.0,
        timestamp: now,
      );

      await tester.pumpWidget(
        ProviderScope(
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
      expect(find.textContaining('Your attendance has been recorded'), findsOneWidget);
      // Verify "Add Another Check-in" button is completely removed
      expect(find.textContaining('Add Another Check-in'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CheckInResultScreen auto-loads last submission from device storage if null extra is passed', (tester) async {
      final now = DateTime.now();
      final submission = CheckInSubmission(
        id: 'sub-cached-01',
        locationId: 'location_x',
        locationName: 'Excel Plaza, Ghatkopar',
        userName: 'Rahul Sharma',
        userPhone: '+919876543210',
        type: CheckInType.visitor,
        userLatitude: 19.0834,
        userLongitude: 72.9140,
        gpsAccuracy: 3.5,
        distanceMeters: 8.0,
        timestamp: now,
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
    });
  });
}
