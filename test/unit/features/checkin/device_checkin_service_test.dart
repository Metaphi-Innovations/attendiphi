import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/cookie_helper.dart';
import 'package:qr_checkin/core/utils/cookie_helper_stub.dart' as cookie_stub;
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late DeviceCheckInService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    cookie_stub.clearWebCookieMemoryForTests();
  });

  test('getOrCreateDeviceId returns a persistent UUID across calls', () async {
    final prefs = await SharedPreferences.getInstance();
    service = DeviceCheckInService(prefs);

    final id1 = await service.getOrCreateDeviceId();
    expect(id1, isNotEmpty);

    final id2 = await service.getOrCreateDeviceId();
    expect(id2, equals(id1));
  });

  test(
    'hasCheckedInForSession returns false when no submission exists',
    () async {
      final prefs = await SharedPreferences.getInstance();
      service = DeviceCheckInService(prefs);

      final checkedIn = await service.hasCheckedInForSession(
        sessionDateStr: '2026-09-24',
        locationId: 'location_x',
      );
      expect(checkedIn, isFalse);
    },
  );

  test(
    'recordSubmission saves submission and hasCheckedInForSession returns true',
    () async {
      final prefs = await SharedPreferences.getInstance();
      service = DeviceCheckInService(prefs);

      final submission = CheckInSubmission(
        id: 'sub-123',
        locationId: 'location_x',
        locationName: 'Excel Plaza, Ghatkopar',
        userName: 'Omkar Anarse',
        userPhone: '+919876543210',
        type: CheckInType.member,
        userLatitude: 19.0834,
        userLongitude: 72.9140,
        gpsAccuracy: 4.5,
        distanceMeters: 12.0,
        timestamp: DateTime(2026, 9, 24, 10, 30),
        adminId: 'adm-1',
        memberId: 'emp_omkar',
      );

      await service.recordSubmission(
        sessionDateStr: '2026-09-24',
        submission: submission,
      );

      final checkedIn = await service.hasCheckedInForSession(
        sessionDateStr: '2026-09-24',
        locationId: 'location_x',
      );
      expect(checkedIn, isTrue);

      final loaded = await service.getSubmissionForSession(
        sessionDateStr: '2026-09-24',
        locationId: 'location_x',
      );
      expect(loaded, isNotNull);
      expect(loaded!.id, equals('sub-123'));
      expect(loaded.userName, equals('Omkar Anarse'));
      expect(loaded.memberId, equals('emp_omkar'));

      final last = await service.getLastSubmission();
      expect(last, isNotNull);
      expect(last!.userName, equals('Omkar Anarse'));
    },
  );

  test('submissions for different session dates are isolated', () async {
    final prefs = await SharedPreferences.getInstance();
    service = DeviceCheckInService(prefs);

    final submission = CheckInSubmission(
      id: 'sub-sep24',
      locationId: 'location_x',
      locationName: 'Excel Plaza, Ghatkopar',
      userName: 'Omkar Anarse',
      userPhone: '+919876543210',
      type: CheckInType.member,
      userLatitude: 19.0834,
      userLongitude: 72.9140,
      gpsAccuracy: 4.5,
      distanceMeters: 12.0,
      timestamp: DateTime(2026, 9, 24, 10, 30),
    );

    await service.recordSubmission(
      sessionDateStr: '2026-09-24',
      submission: submission,
    );

    expect(
      await service.hasCheckedInForSession(
        sessionDateStr: '2026-09-24',
        locationId: 'location_x',
      ),
      isTrue,
    );

    expect(
      await service.hasCheckedInForSession(
        sessionDateStr: '2026-10-01',
        locationId: 'location_x',
      ),
      isFalse,
    );
  });

  test('cookie lock-only marker "1" is not treated as checked-in', () async {
    final prefs = await SharedPreferences.getInstance();
    service = DeviceCheckInService(prefs);
    final key = service.getSessionKey(
      sessionDateStr: '2026-10-08',
      locationId: 'location_x',
    );

    // Orphan device-lock cookie from the old false-positive path.
    CookieHelper.setCookie(key, '1');

    expect(
      await service.getSubmissionForSession(
        sessionDateStr: '2026-10-08',
        locationId: 'location_x',
        probeServer: false,
      ),
      isNull,
    );
    expect(
      await service.hasCheckedInForSession(
        sessionDateStr: '2026-10-08',
        locationId: 'location_x',
        probeServer: false,
      ),
      isFalse,
    );
    // Stale marker should be cleared so a fresh check-in can proceed.
    expect(CookieHelper.hasCookie(key), isFalse);
  });

  test(
    'bare check-in id cookie without prefs JSON is not checked-in',
    () async {
      final prefs = await SharedPreferences.getInstance();
      service = DeviceCheckInService(prefs);
      final key = service.getSessionKey(
        sessionDateStr: '2026-10-08',
        locationId: 'location_x',
      );
      CookieHelper.setCookie(key, 'sub-uuid-only');

      expect(
        await service.hasCheckedInForSession(
          sessionDateStr: '2026-10-08',
          locationId: 'location_x',
          probeServer: false,
        ),
        isFalse,
      );
    },
  );
}
