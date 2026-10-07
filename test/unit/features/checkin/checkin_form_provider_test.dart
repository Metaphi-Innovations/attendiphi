import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/checkin/data/datasources/device_checkin_service.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/domain/repositories/check_in_repository.dart';
import 'package:qr_checkin/features/checkin/domain/usecases/submit_check_in.dart';
import 'package:qr_checkin/features/checkin/presentation/providers/checkin_form_provider.dart';
import 'package:qr_checkin/features/checkin/presentation/providers/checkin_providers.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/usecases/validate_user_proximity.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockCheckInRepository extends Mock implements CheckInRepository {}
class FakeCheckInSubmission extends Fake implements CheckInSubmission {}

void main() {
  late MockCheckInRepository mockRepository;
  late ProviderContainer container;

  const testLocation = LocationConfig(
    id: 'location_x',
    name: 'Excel Plaza, Ghatkopar',
    latitude: 19.0829524,
    longitude: 72.9129274,
    radiusMeters: 500.0,
    isActive: true,
  );

  const testProximity = ProximityResult(
    distanceMeters: 30.0,
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
    SharedPreferences.setMockInitialValues({});
    mockRepository = MockCheckInRepository();
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
    container = ProviderContainer(
      overrides: [
        checkInRepositoryProvider.overrideWithValue(mockRepository),
        restrictionsEnabledProvider.overrideWithValue(true),
        submitCheckInUseCaseProvider.overrideWithValue(
          SubmitCheckIn(
            mockRepository,
            nowProvider: () => DateTime(2026, 9, 3, 10, 0),
          ),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('CheckInFormNotifier', () {
    test('initial state has empty fields and unselected attendance type', () {
      final state = container.read(checkInFormProvider);
      expect(state.name, isEmpty);
      expect(state.phone, isEmpty);
      expect(state.type, isNull);
      expect(state.hasSelectedType, isFalse);
      expect(state.isSubmitting, isFalse);
    });

    test('updates name, phone, and type correctly', () {
      final notifier = container.read(checkInFormProvider.notifier);
      notifier.setName('Pooja Nair');
      notifier.setPhone('9876543210');
      notifier.setType(CheckInType.substitute);

      final state = container.read(checkInFormProvider);
      expect(state.name, 'Pooja Nair');
      expect(state.phone, '9876543210');
      expect(state.type, CheckInType.substitute);
      expect(state.isSubstitute, isTrue);
    });

    test('submits successfully for Member and updates state', () async {
      when(() => mockRepository.submitCheckIn(any(), enforceThursday: any(named: 'enforceThursday')))
          .thenAnswer((_) async {});

      final notifier = container.read(checkInFormProvider.notifier);
      notifier.setName('Pooja Nair');
      notifier.setPhone('9876543210');
      notifier.setType(CheckInType.member);

      final success = await notifier.submit(
        location: testLocation,
        proximityResult: testProximity,
      );

      expect(success, isTrue);
      final state = container.read(checkInFormProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.submissionResult, isNotNull);
      expect(state.submissionResult?.userName, 'Pooja Nair');
    });

    test('defaults type to Member when submitted without explicitly setting type', () async {
      when(() => mockRepository.submitCheckIn(any(), enforceThursday: any(named: 'enforceThursday')))
          .thenAnswer((_) async {});

      final notifier = container.read(checkInFormProvider.notifier);
      notifier.setName('Rohan Mehta');
      notifier.setPhone('9876543211');
      // Do NOT set type - verify it auto-defaults to Member

      final success = await notifier.submit(
        location: testLocation,
        proximityResult: testProximity,
      );

      expect(success, isTrue);
      final state = container.read(checkInFormProvider);
      expect(state.type, CheckInType.member);
      expect(state.submissionResult?.userName, 'Rohan Mehta');
    });

    test('blocks re-submission on same device for production session dates', () async {
      final notifier = container.read(checkInFormProvider.notifier);
      final deviceService = container.read(deviceCheckInServiceProvider);

      final existing = CheckInSubmission(
        id: 'sub-existing-01',
        locationId: 'location_x',
        locationName: 'Excel Plaza, Ghatkopar',
        userName: 'Pooja Nair',
        userPhone: '+919876543210',
        type: CheckInType.member,
        userLatitude: 19.0829,
        userLongitude: 72.9129,
        gpsAccuracy: 10.0,
        distanceMeters: 30.0,
        timestamp: DateTime(2026, 9, 24, 10, 0),
      );

      await deviceService.recordSubmission(
        sessionDateStr: '2026-09-24',
        submission: existing,
      );

      notifier.setName('Pooja Nair');
      notifier.setPhone('9876543210');
      notifier.setType(CheckInType.member);

      final success = await notifier.submit(
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-09-24',
      );

      expect(success, isFalse);
      final state = container.read(checkInFormProvider);
      expect(state.error, isA<DuplicateCheckInException>());
      expect(state.submissionResult?.id, 'sub-existing-01');
      verifyNever(() => mockRepository.submitCheckIn(any(), enforceThursday: any(named: 'enforceThursday')));
    });

    test('2026-09-03 rejects second face check-in on the same device', () async {
      final notifier = container.read(checkInFormProvider.notifier);
      final deviceService = container.read(deviceCheckInServiceProvider);

      final existing = CheckInSubmission(
        id: 'sub-omkaarr',
        locationId: 'location_x',
        locationName: 'Excel Plaza, Ghatkopar',
        userName: 'Omkaarr',
        userPhone: '+918356011246',
        type: CheckInType.member,
        userLatitude: 19.0829,
        userLongitude: 72.9129,
        gpsAccuracy: 10.0,
        distanceMeters: 30.0,
        timestamp: DateTime(2026, 9, 3, 10, 0),
        memberId: 'member_omkaarr',
      );

      await deviceService.recordSubmission(
        sessionDateStr: '2026-09-03',
        submission: existing,
      );

      notifier.setName('Omkar Anarse');
      notifier.setPhone('8356011246');
      notifier.setType(CheckInType.member);
      notifier.setRecognizedMember('member_omkar');

      final success = await notifier.submit(
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-09-03',
      );

      expect(success, isFalse);
      final state = container.read(checkInFormProvider);
      expect(state.error, isA<DuplicateCheckInException>());
      expect(state.submissionResult?.id, 'sub-omkaarr');
      verifyNever(() => mockRepository.submitCheckIn(any(), enforceThursday: any(named: 'enforceThursday')));
    });

    test('2026-09-24 rejects second face check-in on the same device', () async {
      final notifier = container.read(checkInFormProvider.notifier);
      final deviceService = container.read(deviceCheckInServiceProvider);

      final existing = CheckInSubmission(
        id: 'sub-first',
        locationId: 'location_x',
        locationName: 'Excel Plaza, Ghatkopar',
        userName: 'First Member',
        userPhone: '+919876543210',
        type: CheckInType.member,
        userLatitude: 19.0829,
        userLongitude: 72.9129,
        gpsAccuracy: 10.0,
        distanceMeters: 30.0,
        timestamp: DateTime(2026, 9, 24, 10, 0),
        memberId: 'member_first',
      );

      await deviceService.recordSubmission(
        sessionDateStr: '2026-09-24',
        submission: existing,
      );

      notifier.setName('Second Member');
      notifier.setPhone('9876543211');
      notifier.setType(CheckInType.member);
      notifier.setRecognizedMember('member_second');

      final success = await notifier.submit(
        location: testLocation,
        proximityResult: testProximity,
        sessionDateStr: '2026-09-24',
      );

      expect(success, isFalse);
      final state = container.read(checkInFormProvider);
      expect(state.error, isA<DuplicateCheckInException>());
      expect(state.submissionResult?.id, 'sub-first');
      verifyNever(() => mockRepository.submitCheckIn(any(), enforceThursday: any(named: 'enforceThursday')));
    });
  });
}
