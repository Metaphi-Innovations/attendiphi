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
    usecase = SubmitCheckIn(
      mockRepository,
      notificationDispatchService: mockDispatchService,
      nowProvider: () => DateTime(2026, 9, 3, 10, 0),
    );
  });

  group('SubmitCheckIn', () {
    test(
      'throws CheckInSubmissionFailedException when submitting on non-Thursday',
      () async {
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
      },
    );
    test(
      'submits valid Member check-in and dispatches admin notification',
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
        ).thenAnswer((_) async {});
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
        verify(
          () => mockRepository.submitCheckIn(
            any(),
            enforceThursday: any(named: 'enforceThursday'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
            claimDeviceId: any(named: 'claimDeviceId'),
            claimMemberId: any(named: 'claimMemberId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).called(1);
        verify(
          () => mockDispatchService.dispatchAdminCheckInNotification(any()),
        ).called(1);
      },
    );

    test(
      'manual member selection stores memberId without faceVerified',
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
        ).thenAnswer((_) async {});
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
        verify(
          () => mockRepository.submitCheckIn(
            any(),
            enforceThursday: any(named: 'enforceThursday'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
            claimDeviceId: any(named: 'claimDeviceId'),
            claimMemberId: any(named: 'claimMemberId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).called(1);
      },
    );

    test('does NOT dispatch admin notification if submission fails', () async {
      when(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenThrow(const ServerException(technicalMessage: 'DB write failed'));

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

      verify(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).called(1);
      verifyNever(
        () => mockDispatchService.dispatchAdminCheckInNotification(any()),
      );
    });

    test(
      'submits valid Substitute check-in with required face photo',
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
        ).thenAnswer((_) async {});
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
        verify(
          () => mockRepository.submitCheckIn(
            any(),
            enforceThursday: any(named: 'enforceThursday'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
            claimDeviceId: any(named: 'claimDeviceId'),
            claimMemberId: any(named: 'claimMemberId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).called(1);
        verify(
          () => mockDispatchService.dispatchAdminCheckInNotification(any()),
        ).called(1);
      },
    );

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
      verifyNever(
        () => mockDispatchService.dispatchAdminCheckInNotification(any()),
      );
    });

    test(
      'throws exception when phone number is invalid and does not notify',
      () async {
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
        verifyNever(
          () => mockDispatchService.dispatchAdminCheckInNotification(any()),
        );
      },
    );

    test(
      'records submission timestamp matching sessionDateStr (e.g. 2026-09-03)',
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
        ).thenAnswer((_) async {});
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
        verify(
          () => mockRepository.submitCheckIn(
            any(),
            enforceThursday: any(named: 'enforceThursday'),
            sessionDateYmd: any(named: 'sessionDateYmd'),
            claimDeviceId: any(named: 'claimDeviceId'),
            claimMemberId: any(named: 'claimMemberId'),
            sessionToken: any(named: 'sessionToken'),
          ),
        ).called(1);
      },
    );

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

      when(
        () => mockRepository.getIdentitySubmission(
          any(),
          any(),
          type: any(named: 'type'),
        ),
      ).thenAnswer((_) async => existingSubmission);

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
      verifyNever(
        () => mockDispatchService.dispatchAdminCheckInNotification(any()),
      );
    });

    test(
      'same phone Member then Substitute is allowed (typed phone uniqueness)',
      () async {
        // Probe for substitute type finds nothing even if a member used the phone.
        when(
          () => mockRepository.getIdentitySubmission(
            any(),
            any(),
            type: CheckInType.substitute,
          ),
        ).thenAnswer((_) async => null);
        when(
          () => mockDispatchService.dispatchAdminCheckInNotification(any()),
        ).thenAnswer((_) async {});

        final result = await usecase(
          name: 'Stand-in Person',
          phone: '8356011246',
          type: CheckInType.substitute,
          location: testLocation,
          proximityResult: testProximity,
          substituteForMember: 'Other Member',
          substituteForMemberId: 'emp_other',
          photoBase64: 'fake-photo',
          sessionDateStr: '2026-10-01',
          deviceRestrictionEnabled: false,
          dateRestrictionEnabled: false,
          locationRestrictionEnabled: false,
        );

        expect(result.type, CheckInType.substitute);
        expect(result.userPhone, '+918356011246');
        verify(
          () => mockRepository.getIdentitySubmission(
            any(),
            any(),
            type: CheckInType.substitute,
          ),
        ).called(1);
        verify(
          () => mockRepository.submitCheckIn(
            any(),
            enforceThursday: false,
            sessionDateYmd: '2026-10-01',
            claimDeviceId: null,
            claimMemberId: 'emp_other',
            sessionToken: any(named: 'sessionToken'),
          ),
        ).called(1);
      },
    );

    test('2026-09-24 allows shared device with a different phone', () async {
      final thursday24 = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 24, 10, 0),
      );

      // Venue standee: device restriction OFF — same tablet, many members.
      when(() => mockRepository.getDeviceSubmission(any(), any())).thenAnswer(
        (_) async => CheckInSubmission(
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
        ),
      );

      when(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
          .thenAnswer((_) async {});

      await thursday24(
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

      verifyNever(() => mockRepository.getDeviceSubmission(any(), any()));
      verify(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: true,
          sessionDateYmd: '2026-09-24',
          claimDeviceId: null,
          claimMemberId: 'emp_rahul',
          sessionToken: any(named: 'sessionToken'),
        ),
      ).called(1);
    });

    test('2026-09-24 surfaces phone duplicate from server submit', () async {
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
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenThrow(
        const DuplicateCheckInException(
          userMessage:
              'This phone number has already submitted attendance for today.',
          technicalMessage: 'submit_public_check_in duplicate_phone',
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
      verifyNever(
        () => mockDispatchService.dispatchAdminCheckInNotification(any()),
      );
    });

    test(
      '2026-09-03 rejects check-in on a non-Thursday calendar day',
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
      },
    );

    test(
      '2026-09-24 rejects check-in on a non-Thursday calendar day',
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
      },
    );
  });
}
