import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/cookie_helper.dart';
import 'package:qr_checkin/core/utils/cookie_helper_stub.dart' as cookie_stub;
import 'package:qr_checkin/features/checkin/data/datasources/check_in_remote_data_source.dart';
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/domain/entities/public_device_session_attendance.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeCheckInRemote extends Fake implements CheckInRemoteDataSource {
  _FakeCheckInRemote({this.publicAttendance});

  PublicDeviceSessionAttendance? publicAttendance;
  int publicCalls = 0;

  @override
  Future<PublicDeviceSessionAttendance?> getPublicDeviceSessionAttendance({
    required String deviceId,
    required String sessionDateYmd,
  }) async {
    publicCalls++;
    return publicAttendance;
  }

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

  test('session date keys normalize timestamps to yyyy-MM-dd', () {
    service = DeviceCheckInService();
    expect(
      service.getSessionKey(
        sessionDateStr: '2026-10-30T12:00:00.000',
        locationId: 'location_x',
      ),
      service.getSessionKey(
        sessionDateStr: '2026-10-30',
        locationId: 'location_x',
      ),
    );
  });

  test('recordSubmission JSON is recoverable from cookie when prefs empty', () async {
    final prefs = await SharedPreferences.getInstance();
    service = DeviceCheckInService(prefs);

    final submission = CheckInSubmission(
      id: 'sub-cookie',
      locationId: 'location_x',
      locationName: 'Metaphi',
      userName: 'Demo Member',
      userPhone: '+919876543210',
      type: CheckInType.member,
      userLatitude: 19.08,
      userLongitude: 72.91,
      gpsAccuracy: 20,
      distanceMeters: 10,
      timestamp: DateTime(2026, 10, 30, 11, 0),
      memberId: 'mem_1',
    );

    await service.recordSubmission(
      sessionDateStr: '2026-10-30',
      submission: submission,
    );

    // Simulate prefs miss (new SharedPreferences mock) while cookie/localStorage remains.
    SharedPreferences.setMockInitialValues({});
    final prefs2 = await SharedPreferences.getInstance();
    final service2 = DeviceCheckInService(prefs2);

    final loaded = await service2.getSubmissionForSession(
      sessionDateStr: '2026-10-30',
      locationId: 'location_x',
      probeServer: false,
    );
    expect(loaded, isNotNull);
    expect(loaded!.id, 'sub-cookie');
    expect(loaded.userName, 'Demo Member');
  });

  test('resolveSessionAttendance found from local session', () async {
    final prefs = await SharedPreferences.getInstance();
    service = DeviceCheckInService(prefs);

    final submission = CheckInSubmission(
      id: 'sub-resolve',
      locationId: 'location_x',
      locationName: 'Metaphi',
      userName: 'Asha',
      userPhone: '+919876543211',
      type: CheckInType.member,
      userLatitude: 19.08,
      userLongitude: 72.91,
      gpsAccuracy: 15,
      distanceMeters: 5,
      timestamp: DateTime(2026, 10, 30, 9, 0),
    );

    await service.recordSubmission(
      sessionDateStr: '2026-10-30',
      submission: submission,
    );

    final attendance = await service.resolveSessionAttendance(
      sessionDateStr: '2026-10-30',
      locationId: 'location_x',
      probeServer: false,
    );
    expect(attendance.alreadyCheckedIn, isTrue);
    expect(attendance.submission?.id, 'sub-resolve');
  });

  test(
    'resolveSessionAttendance empty prefs + remote locked submission → alreadyCheckedIn',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final prior = CheckInSubmission(
        id: 'sub-remote',
        locationId: 'location_x',
        locationName: 'Metaphi',
        userName: 'First Member',
        userPhone: '+919876543210',
        type: CheckInType.member,
        userLatitude: 19.08,
        userLongitude: 72.91,
        gpsAccuracy: 12,
        distanceMeters: 8,
        timestamp: DateTime(2026, 10, 30, 10, 0),
        memberId: 'mem_1',
        deviceId: 'fp_abc',
      );
      final remote = _FakeCheckInRemote(
        publicAttendance: PublicDeviceSessionAttendance(
          locked: true,
          submission: prior,
          checkInId: prior.id,
        ),
      );
      service = DeviceCheckInService(prefs, remote);

      final attendance = await service.resolveSessionAttendance(
        sessionDateStr: '2026-10-30',
        locationId: 'location_x',
      );

      expect(attendance.alreadyCheckedIn, isTrue);
      expect(attendance.submission?.userName, 'First Member');
      expect(attendance.submission?.id, 'sub-remote');
      expect(remote.publicCalls, 1);

      // RPC hit is cached locally for the next gate.
      final cached = await service.getSubmissionForSession(
        sessionDateStr: '2026-10-30',
        locationId: 'location_x',
        probeServer: false,
      );
      expect(cached?.id, 'sub-remote');
    },
  );

  test(
    'resolveSessionAttendance empty prefs + remote locked without payload → claimed',
    () async {
      final prefs = await SharedPreferences.getInstance();
      final remote = _FakeCheckInRemote(
        publicAttendance: const PublicDeviceSessionAttendance(
          locked: true,
          checkInId: 'sub-only-id',
        ),
      );
      service = DeviceCheckInService(prefs, remote);

      final attendance = await service.resolveSessionAttendance(
        sessionDateStr: '2026-10-30',
        locationId: 'location_x',
      );

      expect(attendance.alreadyCheckedIn, isTrue);
      expect(attendance.submission, isNull);
      expect(attendance.claimedWithoutPayload, isTrue);
    },
  );
}
