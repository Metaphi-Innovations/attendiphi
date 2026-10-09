import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/qr_checkin/domain/check_in_session_token.dart';
import 'package:qr_checkin/features/qr_checkin/domain/resolve_check_in_session.dart';

void main() {
  const secret = 'unit-test-checkin-session-secret';

  group('CheckInSessionToken', () {
    test('create + parse round-trips location, date, adminId', () {
      final token = CheckInSessionToken.create(
        locationId: 'location_x',
        sessionDate: '2026-10-08',
        adminId: 'admin_1',
        secretOverride: secret,
      );

      expect(token.startsWith('v1.'), isTrue);
      expect(token.contains('2026-10-08'), isFalse);
      expect(token.contains('location_x'), isFalse);

      final claims = CheckInSessionToken.parse(
        token,
        secretOverride: secret,
      );
      expect(claims.locationId, 'location_x');
      expect(claims.sessionDateStr, '2026-10-08');
      expect(claims.adminId, 'admin_1');
    });

    test('rejects tampered payload', () {
      final token = CheckInSessionToken.create(
        locationId: 'location_x',
        sessionDate: '2026-10-08',
        secretOverride: secret,
      );
      final parts = token.split('.');
      final tampered = '${parts[0]}.${parts[1]}reversed.${parts[2]}';

      expect(
        () => CheckInSessionToken.parse(tampered, secretOverride: secret),
        throwsA(isA<FormatException>()),
      );
      expect(
        CheckInSessionToken.tryParse(tampered, secretOverride: secret),
        isNull,
      );
    });

    test('rejects wrong signing secret', () {
      final token = CheckInSessionToken.create(
        locationId: 'location_x',
        sessionDate: '2026-10-08',
        secretOverride: secret,
      );
      expect(
        CheckInSessionToken.tryParse(
          token,
          secretOverride: 'other-secret',
        ),
        isNull,
      );
    });

    test('rejects malformed tokens', () {
      expect(CheckInSessionToken.tryParse('location_x'), isNull);
      expect(CheckInSessionToken.tryParse('v1.abc'), isNull);
      expect(CheckInSessionToken.tryParse(''), isNull);
      expect(CheckInSessionToken.tryParse(null), isNull);
    });

    test('looksLikeToken vs legacy location id', () {
      final token = CheckInSessionToken.create(
        locationId: 'location_x',
        sessionDate: '2026-10-08',
        secretOverride: secret,
      );
      expect(CheckInSessionToken.looksLikeToken(token), isTrue);
      expect(CheckInSessionToken.looksLikeLegacyLocationId(token), isFalse);
      expect(CheckInSessionToken.looksLikeLegacyLocationId('location_x'), isTrue);
      expect(CheckInSessionToken.looksLikeToken('location_x'), isFalse);
    });
  });

  group('resolveCheckInSession', () {
    test('resolves opaque path token', () {
      final token = CheckInSessionToken.create(
        locationId: 'location_x',
        sessionDate: '2026-10-08',
        secretOverride: secret,
      );
      final resolved = resolveCheckInSession(
        pathSegment: token,
        secretOverride: secret,
      );
      expect(resolved, isNotNull);
      expect(resolved!.locationId, 'location_x');
      expect(resolved.sessionDateStr, '2026-10-08');
      expect(resolved.isLegacy, isFalse);
      expect(resolved.sessionToken, token);
    });

    test('resolves legacy locationId + date query', () {
      final resolved = resolveCheckInSession(
        pathSegment: 'location_x',
        queryDate: '2026-10-08',
        queryAdminId: 'admin_9',
        secretOverride: secret,
      );
      expect(resolved, isNotNull);
      expect(resolved!.isLegacy, isTrue);
      expect(resolved.locationId, 'location_x');
      expect(resolved.sessionDateStr, '2026-10-08');
      expect(resolved.adminId, 'admin_9');
      expect(resolved.sessionToken, isNotNull);
      expect(
        CheckInSessionToken.looksLikeToken(resolved.sessionToken),
        isTrue,
      );
    });

    test('returns null for forged opaque token', () {
      expect(
        resolveCheckInSession(
          pathSegment: 'v1.notreal.signature',
          secretOverride: secret,
        ),
        isNull,
      );
    });
  });
}
