import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/geo_utils.dart';

void main() {
  group('GeoUtils - calculateDistance', () {
    test('calculates 0 distance for identical coordinates', () {
      final distance = GeoUtils.calculateDistance(
        lat1: 19.0760,
        lon1: 72.8777,
        lat2: 19.0760,
        lon2: 72.8777,
      );
      expect(distance, closeTo(0.0, 0.001));
    });

    test('calculates accurate distance between two Mumbai coordinates', () {
      // Point A: Chhatrapati Shivaji Terminus (18.9400, 72.8354)
      // Point B: Gateway of India (18.9220, 72.8347)
      // Actual distance ~ 2.0 km
      final distance = GeoUtils.calculateDistance(
        lat1: 18.9400,
        lon1: 72.8354,
        lat2: 18.9220,
        lon2: 72.8347,
      );
      expect(distance, closeTo(2000, 100)); // Within 100m tolerance of ~2000m
    });

    test('calculates distance within 500m threshold accurately', () {
      // Base location: (19.0760, 72.8777)
      // Offset by ~0.002 degrees latitude (~222m north)
      final distance = GeoUtils.calculateDistance(
        lat1: 19.0760,
        lon1: 72.8777,
        lat2: 19.0780,
        lon2: 72.8777,
      );
      expect(distance, closeTo(222, 10));
    });
  });

  group('GeoUtils - isWithinRadius', () {
    const baseLat = 19.0760;
    const baseLon = 72.8777;
    const radiusMeters = 500.0;

    test('returns true when user is within 500m radius', () {
      // Point ~222m away
      final isInside = GeoUtils.isWithinRadius(
        userLat: 19.0780,
        userLon: 72.8777,
        locationLat: baseLat,
        locationLon: baseLon,
        radiusMeters: radiusMeters,
      );
      expect(isInside, isTrue);
    });

    test('returns false when user is beyond 500m radius', () {
      // Point ~1.1km away
      final isInside = GeoUtils.isWithinRadius(
        userLat: 19.0860,
        userLon: 72.8777,
        locationLat: baseLat,
        locationLon: baseLon,
        radiusMeters: radiusMeters,
      );
      expect(isInside, isFalse);
    });
  });

  group('GeoUtils - formatDistance', () {
    test('formats meters when less than 1000m', () {
      expect(GeoUtils.formatDistance(145.2), '145 m');
      expect(GeoUtils.formatDistance(499.8), '500 m');
    });

    test('formats kilometers when 1000m or more', () {
      expect(GeoUtils.formatDistance(1200), '1.2 km');
      expect(GeoUtils.formatDistance(5000), '5.0 km');
    });
  });
}
