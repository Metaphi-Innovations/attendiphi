import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/features/qr_checkin/domain/usecases/parse_qr_code.dart';

void main() {
  late ParseQrCode usecase;

  setUp(() {
    usecase = const ParseQrCode();
  });

  group('ParseQrCode - JSON format', () {
    test('parses standard valid JSON payload with locationId', () {
      const raw = '{"locationId": "location_x"}';
      final payload = usecase(raw);

      expect(payload.locationId, 'location_x');
      expect(payload.rawPayload, raw);
    });

    test('parses JSON with timestamp and extra metadata', () {
      const raw = '{"locationId": "mumbai_hq", "timestamp": "2026-08-26T10:00:00Z"}';
      final payload = usecase(raw);

      expect(payload.locationId, 'mumbai_hq');
      expect(payload.timestamp, isNotNull);
      expect(payload.timestamp?.year, 2026);
    });

    test('throws MalformedQrPayloadException when locationId is missing in JSON', () {
      const raw = '{"name": "Invalid Location"}';
      expect(
        () => usecase(raw),
        throwsA(isA<MalformedQrPayloadException>()),
      );
    });

    test('throws MalformedQrPayloadException for empty locationId string in JSON', () {
      const raw = '{"locationId": "   "}';
      expect(
        () => usecase(raw),
        throwsA(isA<MalformedQrPayloadException>()),
      );
    });
  });

  group('ParseQrCode - URI format', () {
    test('parses deep link URI query parameter', () {
      const raw = 'https://app.metaphi.com/checkin?locationId=branch_42';
      final payload = usecase(raw);

      expect(payload.locationId, 'branch_42');
    });

    test('parses path URL check-in standee without a hash', () {
      const raw =
          'https://attendiphi.metaphi.in/checkin-permission?date=2026-09-03&locationId=location_x';
      final payload = usecase(raw);

      expect(payload.locationId, 'location_x');
      expect(payload.sessionDateStr, '2026-09-03');
    });

    test('parses legacy hash URL check-in standee', () {
      const raw =
          'https://attendiphi-by-metaphi.web.app/#/checkin-permission?date=2026-09-03&locationId=location_x';
      final payload = usecase(raw);

      expect(payload.locationId, 'location_x');
      expect(payload.sessionDateStr, '2026-09-03');
    });
  });

  group('ParseQrCode - Plaintext ID fallback', () {
    test('parses valid alphanumeric identifier', () {
      const raw = 'location_x';
      final payload = usecase(raw);

      expect(payload.locationId, 'location_x');
    });

    test('parses ID with hyphens and underscores', () {
      const raw = 'DELHI-NORTH-01';
      final payload = usecase(raw);

      expect(payload.locationId, 'DELHI-NORTH-01');
    });
  });

  group('ParseQrCode - Invalid inputs', () {
    test('throws InvalidQrCodeException for null or empty string', () {
      expect(() => usecase(null), throwsA(isA<InvalidQrCodeException>()));
      expect(() => usecase(''), throwsA(isA<InvalidQrCodeException>()));
      expect(() => usecase('   '), throwsA(isA<InvalidQrCodeException>()));
    });

    test('throws InvalidQrCodeException for special characters or binary garbage', () {
      expect(
        () => usecase('!@#%^&*()'),
        throwsA(isA<InvalidQrCodeException>()),
      );
    });
  });
}
