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
  late SubmitCheckIn usecase;

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
  );

  setUpAll(() {
    registerFallbackValue(FakeCheckInSubmission());
  });

  setUp(() {
    mockRepository = MockCheckInRepository();
    mockDispatchService = MockNotificationDispatchService();
    when(() => mockRepository.getIdentitySubmission(any(), any()))
        .thenAnswer((_) async => null);
    when(() => mockRepository.getDeviceSubmission(any(), any()))
        .thenAnswer((_) async => null);
    when(() => mockRepository.hasIdentityCheckedIn(any(), any()))
        .thenAnswer((_) async => false);
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
      ),
    ).thenAnswer((_) async {});
    usecase = SubmitCheckIn(
      mockRepository,
      notificationDispatchService: mockDispatchService,
      nowProvider: () => DateTime(2026, 9, 3, 10, 0),
    );
  });

  group('SubmitCheckIn', () {
    test('throws CheckInSubmissionFailedException when submitting on non-Thursday', () async {
      final nonThursdayUsecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 9, 10, 0), // Wednesday
      );

      await expectLater(
        nonThursdayUsecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
        ),
        throwsA(isA<CheckInSubmissionFailedException>()),
      );

      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
    });
    test('submits valid Member check-in and dispatches admin notification', () async {
      when(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ))
          .thenAnswer((_) async {});
      when(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
          .thenAnswer((_) async {});

      final submission = await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: testProximity,
      );

      expect(submission.userName, 'Rahul Sharma');
      expect(submission.userPhone, '+919876543210');
      expect(submission.type, CheckInType.member);
      expect(submission.locationId, 'location_x');
      verify(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        )).called(1);
      verify(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
          .called(1);
    });

    test('manual member selection stores memberId without faceVerified', () async {
      when(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ))
          .thenAnswer((_) async {});
      when(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
          .thenAnswer((_) async {});

      final submission = await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: testProximity,
        recognizedMemberId: 'emp_rahul',
      );

      expect(submission.memberId, 'emp_rahul');
      expect(submission.verificationMethod, 'manual');
      expect(submission.faceVerified, isFalse);
      verify(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        )).called(1);
    });

    test('does NOT dispatch admin notification if submission fails', () async {
      when(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ))
          .thenThrow(const ServerException(technicalMessage: 'DB write failed'));

      await expectLater(
        usecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
        ),
        throwsA(isA<ServerException>()),
      );

      verify(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        )).called(1);
      verifyNever(() => mockDispatchService.dispatchAdminCheckInNotification(any()));
    });

    test('submits valid Substitute check-in with required face photo', () async {
      when(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ))
          .thenAnswer((_) async {});
      when(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
          .thenAnswer((_) async {});

      final submission = await usecase(
        name: 'Amit Patel',
        phone: '9876543211',
        type: CheckInType.substitute,
        location: testLocation,
        proximityResult: testProximity,
        photoBase64: 'fake_base64_photo_string',
        substituteForMember: 'Rahul Sharma',
        substituteForMemberId: 'emp_rahul',
      );

      expect(submission.type, CheckInType.substitute);
      expect(submission.photoBase64, 'fake_base64_photo_string');
      expect(submission.userName, 'Amit Patel');
      expect(submission.substituteName, 'Amit Patel');
      expect(submission.substituteForMember, 'Rahul Sharma');
      expect(submission.memberId, 'emp_rahul');
      verify(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        )).called(1);
      verify(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
          .called(1);
    });

    test('throws MissingSubstitutePhotoException when substitute has no photo and does not notify', () async {
      expect(
        () => usecase(
          name: 'Amit Patel',
          phone: '9876543211',
          type: CheckInType.substitute,
          location: testLocation,
          proximityResult: testProximity,
          photoBase64: null,
        ),
        throwsA(isA<MissingSubstitutePhotoException>()),
      );
      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
      verifyNever(() => mockDispatchService.dispatchAdminCheckInNotification(any()));
    });

    test('throws exception when phone number is invalid and does not notify', () async {
      expect(
        () => usecase(
          name: 'Rahul Sharma',
          phone: '123', // invalid
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
        ),
        throwsA(isA<AppException>()),
      );
      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
      verifyNever(() => mockDispatchService.dispatchAdminCheckInNotification(any()));
    });

    test('records submission timestamp matching sessionDateStr (e.g. 2026-09-03)', () async {
      when(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ))
          .thenAnswer((_) async {});
      when(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
          .thenAnswer((_) async {});

      final submission = await usecase(
        name: 'Rahul Sharma',
        phone: '9876543210',
        type: CheckInType.member,
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-09-03',
      );

      expect(submission.timestamp.year, 2026);
      expect(submission.timestamp.month, 9);
      expect(submission.timestamp.day, 3);
      verify(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        )).called(1);
    });

    test('throws DuplicateCheckInException when phone has already checked in on session date', () async {
      final existingSubmission = CheckInSubmission(
        id: 'existing-id',
        locationId: testLocation.id,
        locationName: testLocation.name,
        userName: 'Rahul Sharma',
        userPhone: '+919876543210',
        type: CheckInType.member,
        userLatitude: 19.0829,
        userLongitude: 72.9129,
        gpsAccuracy: 10.0,
        distanceMeters: 45.0,
        timestamp: DateTime(2026, 9, 8, 10, 0),
      );

      when(() => mockRepository.getIdentitySubmission(any(), any()))
          .thenAnswer((_) async => existingSubmission);

      await expectLater(
        usecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
        ),
        throwsA(isA<DuplicateCheckInException>()),
      );

      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
      verifyNever(() => mockDispatchService.dispatchAdminCheckInNotification(any()));
    });

    test('2026-09-03 rejects same device second check-in', () async {
      final existingDevice = CheckInSubmission(
        id: 'device-existing',
        locationId: testLocation.id,
        locationName: testLocation.name,
        userName: 'Prior Guest',
        userPhone: '+919999999999',
        type: CheckInType.member,
        userLatitude: 19.0829,
        userLongitude: 72.9129,
        gpsAccuracy: 10.0,
        distanceMeters: 45.0,
        timestamp: DateTime(2026, 9, 3, 9, 0),
        deviceId: 'device-a',
      );

      when(() => mockRepository.getDeviceSubmission(any(), any()))
          .thenAnswer((_) async => existingDevice);

      await expectLater(
        usecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
          sessionDateStr: '2026-09-03',
          deviceId: 'device-a',
        ),
        throwsA(isA<DuplicateCheckInException>()),
      );

      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
    });

    test('2026-09-24 rejects same device second check-in', () async {
      final thursday24 = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 24, 10, 0),
      );

      final existingDevice = CheckInSubmission(
        id: 'device-existing',
        locationId: testLocation.id,
        locationName: testLocation.name,
        userName: 'Prior Guest',
        userPhone: '+919999999999',
        type: CheckInType.member,
        userLatitude: 19.0829,
        userLongitude: 72.9129,
        gpsAccuracy: 10.0,
        distanceMeters: 45.0,
        timestamp: DateTime(2026, 9, 24, 9, 0),
        deviceId: 'device-a',
      );

      when(() => mockRepository.getDeviceSubmission(any(), any()))
          .thenAnswer((_) async => existingDevice);

      await expectLater(
        thursday24(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
          sessionDateStr: '2026-09-24',
          deviceId: 'device-a',
        ),
        throwsA(isA<DuplicateCheckInException>()),
      );

      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
    });

    test('2026-09-24 rejects when atomic device lock already claimed', () async {
      final thursday24 = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 24, 10, 0),
      );

      when(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ),
      ).thenThrow(
        const DuplicateCheckInException(
          userMessage:
              'This device has already recorded attendance for today.',
          technicalMessage: 'deviceSessionLocks already-exists',
        ),
      );

      await expectLater(
        thursday24(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
          sessionDateStr: '2026-09-24',
          deviceId: 'device-a',
        ),
        throwsA(isA<DuplicateCheckInException>()),
      );

      verifyNever(
        () => mockRepository.claimDeviceSessionLock(
          deviceId: any(named: 'deviceId'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
        ),
      );
      verifyNever(() => mockDispatchService.dispatchAdminCheckInNotification(any()));
    });

    test('2026-09-03 rejects check-in on a non-Thursday calendar day',
        () async {
      final tuesdayUsecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 22, 15, 0), // Tuesday
      );

      await expectLater(
        tuesdayUsecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
          sessionDateStr: '2026-09-03',
          deviceId: 'device-a',
        ),
        throwsA(isA<CheckInSubmissionFailedException>()),
      );
      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
    });

    test('2026-09-24 rejects check-in on a non-Thursday calendar day',
        () async {
      final tuesdayUsecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 22, 15, 0), // Tuesday
      );

      await expectLater(
        tuesdayUsecase(
          name: 'Rahul Sharma',
          phone: '9876543210',
          type: CheckInType.member,
          location: testLocation,
          proximityResult: testProximity,
          sessionDateStr: '2026-09-24',
          deviceId: 'device-a',
        ),
        throwsA(isA<CheckInSubmissionFailedException>()),
      );
      verifyNever(() => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
        ));
    });
  });
}
