import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
    isVerified: true,
  );

  setUpAll(() {
    registerFallbackValue(FakeCheckInSubmission());
    registerFallbackValue(CheckInType.member);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepository = MockCheckInRepository();
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
    test('initial state has empty fields and Member selected by default', () {
      final state = container.read(checkInFormProvider);
      expect(state.name, isEmpty);
      expect(state.phone, isEmpty);
      expect(state.type, CheckInType.member);
      expect(state.hasSelectedType, isTrue);
      expect(state.isMember, isTrue);
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

    test('ignores second submit while isSubmitting (H4)', () async {
      var calls = 0;
      when(
        () => mockRepository.submitCheckIn(
          any(),
          enforceThursday: any(named: 'enforceThursday'),
          sessionDateYmd: any(named: 'sessionDateYmd'),
          claimDeviceId: any(named: 'claimDeviceId'),
          claimMemberId: any(named: 'claimMemberId'),
          sessionToken: any(named: 'sessionToken'),
        ),
      ).thenAnswer((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 40));
      });

      final notifier = container.read(checkInFormProvider.notifier);
      notifier.setName('Pooja Nair');
      notifier.setPhone('9876543210');
      notifier.setType(CheckInType.member);

      final first = notifier.submit(
        location: testLocation,
        proximityResult: testProximity,
      );
      final second = await notifier.submit(
        location: testLocation,
        proximityResult: testProximity,
      );
      final firstResult = await first;

      expect(second, isFalse);
      expect(firstResult, isTrue);
      expect(calls, 1);
    });

    test(
      'defaults type to Member when submitted without explicitly setting type',
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
      },
    );

    test(
      'shared device local history does not block a different member',
      () async {
        // Freeze "today" so sessionDateStr matches Thursday restrictions.
        // (Provider uses DateTime.now() inside SubmitCheckIn via default now.)
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
          timestamp: DateTime.now(),
          memberId: 'member_first',
        );

        await deviceService.recordSubmission(
          sessionDateStr: null,
          submission: existing,
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
        ).thenAnswer((_) async {});

        notifier.setName('Second Member');
        notifier.setPhone('9876543211');
        notifier.setType(CheckInType.member);
        notifier.setRecognizedMember('member_second');

        final success = await notifier.submit(
          location: testLocation,
          proximityResult: testProximity,
        );

        expect(success, isTrue);
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
  });
}
