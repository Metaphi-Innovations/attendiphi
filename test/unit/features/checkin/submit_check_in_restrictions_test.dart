import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/features/checkin/data/datasources/notification_dispatch_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/domain/repositories/check_in_repository.dart';
import 'package:qr_checkin/features/checkin/domain/usecases/submit_check_in.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/usecases/validate_user_proximity.dart';

class MockCheckInRepository extends Mock implements CheckInRepository {}

class MockNotificationDispatchService extends Mock
    implements NotificationDispatchService {}

class FakeCheckInSubmission extends Fake implements CheckInSubmission {}

void main() {
  late MockCheckInRepository mockRepository;
  late MockNotificationDispatchService mockDispatchService;

  const testLocation = LocationConfig(
    id: 'location_x',
    name: 'Excel Plaza, Ghatkopar',
    latitude: 19.0829524,
    longitude: 72.9129274,
    radiusMeters: 500.0,
    isActive: true,
  );

  const testProximity = ProximityResult(
    distanceMeters: 45.0,
    isWithinRadius: true,
    allowedRadiusMeters: 500.0,
    userLatitude: 19.0829,
    userLongitude: 72.9129,
    gpsAccuracy: 10.0,
    isVerified: true,
  );

  setUpAll(() {
    registerFallbackValue(FakeCheckInSubmission());
    registerFallbackValue(CheckInType.member);
  });

  setUp(() {
    mockRepository = MockCheckInRepository();
    mockDispatchService = MockNotificationDispatchService();
    when(
      () => mockRepository.getIdentitySubmission(
        any(),
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => null);
    when(() => mockRepository.getDeviceSubmission(any(), any()))
        .thenAnswer((_) async => null);
    when(
      () => mockRepository.hasIdentityCheckedIn(
        any(),
        any(),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => false);
    when(
      () => mockRepository.claimDeviceSessionLock(
        deviceId: any(named: 'deviceId'),
        sessionDateYmd: any(named: 'sessionDateYmd'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockRepository.submitCheckIn(
        any(),
        enforceThursday: any(named: 'enforceThursday'),
        sessionDateYmd: any(named: 'sessionDateYmd'),
        claimDeviceId: any(named: 'claimDeviceId'),
        claimMemberId: any(named: 'claimMemberId'),
        sessionToken: any(named: 'sessionToken'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
        .thenAnswer((_) async {});
  });

  group('SubmitCheckIn location verification gate', () {
    const fabricated = ProximityResult(
      distanceMeters: 10,
      isWithinRadius: true,
      allowedRadiusMeters: 500,
      userLatitude: 19.0829524,
      userLongitude: 72.9129274,
      gpsAccuracy: 5,
    );

    for (final type in [CheckInType.member, CheckInType.substitute]) {
      test('location ON rejects unverified proximity (${type.name})', () async {
        final usecase = SubmitCheckIn(
          mockRepository,
          notificationDispatchService: mockDispatchService,
          nowProvider: () => DateTime(2026, 9, 3, 10, 0), // Thursday
        );

        await expectLater(
          usecase(
            name: 'Rahul Sharma',
            phone: '9876543210',
            type: type,
            location: testLocation,
            proximityResult: fabricated,
            photoBase64: 'abc',
            sessionDateStr: '2026-09-03',
            dateRestrictionEnabled: false,
            locationRestrictionEnabled: true,
            deviceRestrictionEnabled: false,
          ),
          throwsA(isA<CheckInSubmissionFailedException>()),
        );
        verifyNever(
          () => mockRepository.submitCheckIn(
            any(),
            enforceThursday: any(named: 'enforceThursday'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
            claimDeviceId: any(named: 'claimDeviceId'),
            claimMemberId: any(named: 'claimMemberId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        );
      });
    }

    test('location OFF accepts the unverified placeholder', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 22, 10, 0),
      );

      final submission = await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: fabricated,
        sessionDateStr: '2026-09-03',
        dateRestrictionEnabled: false,
        locationRestrictionEnabled: false,
        deviceRestrictionEnabled: false,
      );
      expect(submission.userLatitude, fabricated.userLatitude);
    });

    test('substitute photo is still required with a verified fix', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 3, 10, 0),
      );

      await expectLater(
        usecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.substitute,
          location: testLocation,
          proximityResult: testProximity,
          sessionDateStr: '2026-09-03',
          dateRestrictionEnabled: false,
          locationRestrictionEnabled: true,
          deviceRestrictionEnabled: false,
        ),
        throwsA(isA<MissingSubstitutePhotoException>()),
      );
    });
  });

  group('SubmitCheckIn restrictions toggle', () {
    test('ON rejects non-Thursday', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 22, 10, 0), // Tuesday
      );

      await expectLater(
        usecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
          deviceId: 'device-a',
          restrictionsEnabled: true,
        ),
        throwsA(isA<CheckInSubmissionFailedException>()),
      );
      verifyNever(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
        ),
      );
    });

    test('OFF allows non-Thursday and skips device lock', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 22, 10, 0), // Tuesday
      );

      final submission = await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-09-03',
        deviceId: 'device-a',
        restrictionsEnabled: false,
      );

      expect(submission.userName, 'Rahul Sharma');
      verifyNever(
        () => mockRepository.claimDeviceSessionLock(
          deviceId: any(named: 'deviceId'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
        ),
      );
      verifyNever(() => mockRepository.getDeviceSubmission(any(), any()));
      verify(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: false,
          sessionDateYmd: '2026-09-03',
          claimDeviceId: null,
          claimMemberId: any(named: 'claimMemberId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).called(1);
    });

    test('device restriction ON claims device id on submit', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 24, 10, 0), // Thursday
      );

      await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-09-24',
        deviceId: 'device-a',
        recognizedMemberId: 'emp_rahul',
        dateRestrictionEnabled: true,
        locationRestrictionEnabled: true,
        deviceRestrictionEnabled: true,
      );

      verify(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: true,
          sessionDateYmd: '2026-09-24',
          claimDeviceId: 'device-a',
          claimMemberId: 'emp_rahul',
        ),
      ).called(1);
    });

    test('device restriction OFF skips device claim (standee mode)', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 24, 10, 0), // Thursday
      );

      await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-09-24',
        deviceId: 'device-a',
        recognizedMemberId: 'emp_rahul',
        dateRestrictionEnabled: true,
        locationRestrictionEnabled: true,
        deviceRestrictionEnabled: false,
      );

      verify(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: true,
          sessionDateYmd: '2026-09-24',
          claimDeviceId: null,
          claimMemberId: 'emp_rahul',
        ),
      ).called(1);
    });

    test(
      'atomic write failure does not leave a separate device lock claim',
      () async {
        when(
          () => mockRepository.submitCheckIn(
            any(),
            enforceThursday: any(named: 'enforceThursday'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
            claimDeviceId: any(named: 'claimDeviceId'),
            claimMemberId: any(named: 'claimMemberId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).thenThrow(
          const ServerException(technicalMessage: 'Firestore write timed out'),
        );

        final usecase = SubmitCheckIn(
          mockRepository,
          notificationDispatchService: mockDispatchService,
          nowProvider: () => DateTime(2026, 9, 24, 10, 0),
        );

        await expectLater(
          usecase(
            name: 'Rahul Sharma',
            phone: '9876543210',
            type: CheckInType.member,
            location: testLocation,
            proximityResult: testProximity,
            sessionDateStr: '2026-09-24',
            deviceId: 'device-a',
            restrictionsEnabled: true,
          ),
          throwsA(isA<ServerException>()),
        );

        verifyNever(
          () => mockRepository.claimDeviceSessionLock(
            deviceId: any(named: 'deviceId'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
          ),
        );
      },
    );

    test(
      'OFF allows mismatched QR session date and stamps that session day',
      () async {
        final usecase = SubmitCheckIn(
          mockRepository,
          notificationDispatchService: mockDispatchService,
          nowProvider: () => DateTime(2026, 9, 24, 10, 30),
        );

        final submission = await usecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
          sessionDateStr: '2026-09-03',
          deviceId: 'device-a',
          restrictionsEnabled: false,
        );

        // Attendance is attributed to the QR session date (not "today").
        expect(submission.timestamp.year, 2026);
        expect(submission.timestamp.month, 9);
        expect(submission.timestamp.day, 3);
        expect(submission.timestamp.hour, 10);
        expect(submission.timestamp.minute, 30);
        verifyNever(
          () => mockRepository.claimDeviceSessionLock(
            deviceId: any(named: 'deviceId'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
          ),
        );
      },
    );

    test('OFF Oct 8 QR stamps Oct 8 even when today is earlier', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 10, 7, 14, 5), // Wednesday
      );

      final submission = await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-10-08',
        deviceId: 'device-b',
        restrictionsEnabled: false,
      );

      expect(submission.timestamp.year, 2026);
      expect(submission.timestamp.month, 10);
      expect(submission.timestamp.day, 8);
      expect(submission.timestamp.hour, 14);
    });
  });
}
