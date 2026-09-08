import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/repositories/location_repository.dart';
import 'package:qr_checkin/features/location/domain/usecases/get_location_config.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_providers.dart';
import 'package:qr_checkin/features/qr_checkin/presentation/providers/qr_scanner_provider.dart';
import 'package:qr_checkin/features/qr_checkin/presentation/providers/qr_scanner_state.dart';

class MockLocationRepository extends Mock implements LocationRepository {}

void main() {
  late MockLocationRepository mockRepository;
  late ProviderContainer container;

  const testLocation = LocationConfig(
    id: 'location_x',
    name: 'Main Campus',
    latitude: 19.0760,
    longitude: 72.8777,
    radiusMeters: 500,
    isActive: true,
  );

  setUp(() {
    mockRepository = MockLocationRepository();
    container = ProviderContainer(
      overrides: [
        locationRepositoryProvider.overrideWithValue(mockRepository),
        getLocationConfigUseCaseProvider.overrideWithValue(
          GetLocationConfig(mockRepository),
        ),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  group('QrScannerNotifier', () {
    test('initial state is QrScannerInitial', () {
      final state = container.read(qrScannerProvider);
      expect(state, isA<QrScannerInitial>());
    });

    test('transitions to QrScannerSuccess on valid QR and active location', () async {
      when(() => mockRepository.getLocationConfig('location_x'))
          .thenAnswer((_) async => testLocation);

      final notifier = container.read(qrScannerProvider.notifier);
      await notifier.onQrCodeDetected('{"locationId": "location_x"}');

      final state = container.read(qrScannerProvider);
      expect(state, isA<QrScannerSuccess>());

      final successState = state as QrScannerSuccess;
      expect(successState.location.id, 'location_x');
      expect(successState.location.name, 'Main Campus');
    });

    test('transitions to QrScannerError when location does not exist in Firestore', () async {
      when(() => mockRepository.getLocationConfig('unknown_loc'))
          .thenThrow(const LocationNotFoundException());

      final notifier = container.read(qrScannerProvider.notifier);
      await notifier.onQrCodeDetected('{"locationId": "unknown_loc"}');

      final state = container.read(qrScannerProvider);
      expect(state, isA<QrScannerError>());
      final errorState = state as QrScannerError;
      expect(errorState.exception, isA<LocationNotFoundException>());
    });

    test('transitions to QrScannerError when QR payload is malformed', () async {
      final notifier = container.read(qrScannerProvider.notifier);
      await notifier.onQrCodeDetected('{"invalidKey": 123}');

      final state = container.read(qrScannerProvider);
      expect(state, isA<QrScannerError>());
      final errorState = state as QrScannerError;
      expect(errorState.exception, isA<MalformedQrPayloadException>());
    });

    test('reset() sets state back to QrScannerInitial', () async {
      final notifier = container.read(qrScannerProvider.notifier);
      await notifier.onQrCodeDetected('!invalid!');

      expect(container.read(qrScannerProvider), isA<QrScannerError>());

      notifier.reset();
      expect(container.read(qrScannerProvider), isA<QrScannerInitial>());
    });
  });
}
