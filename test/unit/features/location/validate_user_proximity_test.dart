import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/usecases/validate_user_proximity.dart';

void main() {
  late ValidateUserProximity usecase;

  const excelPlaza = LocationConfig(
    id: 'location_x',
    name: 'Excel Plaza, Ghatkopar',
    latitude: 19.0829524,
    longitude: 72.9129274,
    radiusMeters: 500.0,
    isActive: true,
  );

  setUp(() {
    usecase = const ValidateUserProximity();
  });

  group('ValidateUserProximity', () {
    test('succeeds when user GPS is right at venue (0m away)', () {
      final result = usecase(
        userLat: 19.0829524,
        userLon: 72.9129274,
        accuracy: 5.0,
        location: excelPlaza,
      );

      expect(result.isWithinRadius, isTrue);
      expect(result.distanceMeters, closeTo(0.0, 0.1));
    });

    test('succeeds when user GPS is ~200m away (inside 500m radius)', () {
      // Offset by ~0.0018 degrees latitude (~200m north)
      final result = usecase(
        userLat: 19.08475,
        userLon: 72.9129274,
        accuracy: 10.0,
        location: excelPlaza,
      );

      expect(result.isWithinRadius, isTrue);
      expect(result.distanceMeters, lessThanOrEqualTo(500.0));
    });

    test('throws OutsideAllowedRadiusException when user is > 500m away (e.g. 2km away)', () {
      // Offset by ~0.02 degrees latitude (~2.2km away)
      expect(
        () => usecase(
          userLat: 19.10295,
          userLon: 72.9129274,
          accuracy: 10.0,
          location: excelPlaza,
        ),
        throwsA(isA<OutsideAllowedRadiusException>()),
      );
    });

    test('does not throw when outside radius if enforceProximity is false', () {
      final result = usecase(
        userLat: 19.10295,
        userLon: 72.9129274,
        accuracy: 10.0,
        location: excelPlaza,
        enforceProximity: false,
      );

      expect(result.isWithinRadius, isFalse);
      expect(result.distanceMeters, greaterThan(500.0));
      expect(result.userLatitude, 19.10295);
      expect(result.userLongitude, 72.9129274);
      expect(result.isVerified, isFalse);
    });

    test('real fix inside the radius is verified', () {
      final result = usecase(
        userLat: 19.08475,
        userLon: 72.9129274,
        accuracy: 30,
        location: excelPlaza,
      );
      expect(result.isVerified, isTrue);
    });

    test('accuracy wider than the radius is inconclusive when enforced', () {
      expect(
        () => usecase(
          userLat: 19.0829524,
          userLon: 72.9129274,
          accuracy: 600,
          location: excelPlaza,
        ),
        throwsA(isA<LocationAccuracyTooLowException>()),
      );
    });

    test('coarse fix whose nearest edge is still outside → outside radius', () {
      // ~2.2 km away with ±600 m: even the closest point is > 500 m.
      expect(
        () => usecase(
          userLat: 19.10295,
          userLon: 72.9129274,
          accuracy: 600,
          location: excelPlaza,
        ),
        throwsA(isA<OutsideAllowedRadiusException>()),
      );
    });

    test('coarse fix under restrictions OFF is recorded but not verified', () {
      final result = usecase(
        userLat: 19.0829524,
        userLon: 72.9129274,
        accuracy: 600,
        location: excelPlaza,
        enforceProximity: false,
      );
      expect(result.isWithinRadius, isTrue);
      expect(result.isVerified, isFalse);
    });

    test('radius stays at the configured 500 m', () {
      // ~520 m north: just outside, accuracy fine.
      expect(
        () => usecase(
          userLat: 19.0876324,
          userLon: 72.9129274,
          accuracy: 10,
          location: excelPlaza,
        ),
        throwsA(isA<OutsideAllowedRadiusException>()),
      );
    });

    test('custom 700 m radius: inside succeeds, outside throws', () {
      const venue700 = LocationConfig(
        id: 'location_x',
        name: 'Excel Plaza',
        latitude: 19.0829524,
        longitude: 72.9129274,
        radiusMeters: 700,
      );

      // ~200 m north — inside 700 m.
      final inside = usecase(
        userLat: 19.08475,
        userLon: 72.9129274,
        accuracy: 10,
        location: venue700,
      );
      expect(inside.isWithinRadius, isTrue);
      expect(inside.allowedRadiusMeters, 700);

      // ~2.2 km away — outside 700 m.
      expect(
        () => usecase(
          userLat: 19.10295,
          userLon: 72.9129274,
          accuracy: 10,
          location: venue700,
        ),
        throwsA(
          isA<OutsideAllowedRadiusException>()
              .having(
                (e) => e.allowedRadiusMeters,
                'allowedRadiusMeters',
                700,
              )
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('700 m'),
              ),
        ),
      );
    });

    test('custom 30 km radius: far point inside, farther point outside', () {
      const venue30km = LocationConfig(
        id: 'location_x',
        name: 'Excel Plaza',
        latitude: 19.0829524,
        longitude: 72.9129274,
        radiusMeters: 30000,
      );

      // ~2.2 km away — inside 30 km.
      final inside = usecase(
        userLat: 19.10295,
        userLon: 72.9129274,
        accuracy: 20,
        location: venue30km,
      );
      expect(inside.isWithinRadius, isTrue);
      expect(inside.allowedRadiusMeters, 30000);

      // ~40 km north — outside 30 km (~0.36 deg lat).
      expect(
        () => usecase(
          userLat: 19.44295,
          userLon: 72.9129274,
          accuracy: 50,
          location: venue30km,
        ),
        throwsA(
          isA<OutsideAllowedRadiusException>()
              .having(
                (e) => e.allowedRadiusMeters,
                'allowedRadiusMeters',
                30000,
              )
              .having(
                (e) => e.userMessage,
                'userMessage',
                contains('30 km'),
              ),
        ),
      );
    });

    test('enforceProximity false still bypasses custom large radius', () {
      const venue30km = LocationConfig(
        id: 'location_x',
        name: 'Excel Plaza',
        latitude: 19.0829524,
        longitude: 72.9129274,
        radiusMeters: 30000,
      );

      final result = usecase(
        userLat: 19.44295,
        userLon: 72.9129274,
        accuracy: 50,
        location: venue30km,
        enforceProximity: false,
      );
      expect(result.isWithinRadius, isFalse);
      expect(result.isVerified, isFalse);
    });
  });
}
