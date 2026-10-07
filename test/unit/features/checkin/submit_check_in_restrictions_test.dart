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
      ),
    ).thenAnswer((_) async {});
    when(() => mockDispatchService.dispatchAdminCheckInNotification(any()))
        .thenAnswer((_) async {});
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
        ),
      ).called(1);
    });

    test('ON still claims device session lock', () async {
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
        restrictionsEnabled: true,
      );

      verify(
        () => mockRepository.claimDeviceSessionLock(
          deviceId: 'device-a',
          sessionDateYmd: '2026-09-24',
        ),
      ).called(1);
      verify(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: true,
        ),
      ).called(1);
    });

    test('OFF allows mismatched QR session date', () async {
      final usecase = SubmitCheckIn(
        mockRepository,
        notificationDispatchService: mockDispatchService,
        nowProvider: () => DateTime(2026, 9, 24, 10, 0),
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

      expect(submission.timestamp.day, 24);
      verifyNever(
        () => mockRepository.claimDeviceSessionLock(
          deviceId: any(named: 'deviceId'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
        ),
      );
    });
  });
}
