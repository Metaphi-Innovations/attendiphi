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
  });
}
