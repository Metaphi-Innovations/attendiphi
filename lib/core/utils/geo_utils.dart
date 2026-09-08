import 'package:geolocator/geolocator.dart';

/// Geographic utility functions.
///
/// Uses standard WGS-84 ellipsoidal geodesy for millimeter-accurate distance calculation.
class GeoUtils {
  GeoUtils._();

  /// Calculates the distance in meters between two GPS coordinates
  /// using the WGS-84 ellipsoid (Vincenty/Andoyer).
  ///
  /// [lat1], [lon1]: First point (e.g., user's position)
  /// [lat2], [lon2]: Second point (e.g., configured location)
  ///
  /// Returns the geodesic distance in meters.
  static double calculateDistance({
    required double lat1,
    required double lon1,
    required double lat2,
    required double lon2,
  }) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  /// Returns whether a user position is within the allowed radius
  /// of a target location.
  static bool isWithinRadius({
    required double userLat,
    required double userLon,
    required double locationLat,
    required double locationLon,
    required double radiusMeters,
  }) {
    final distance = calculateDistance(
      lat1: userLat,
      lon1: userLon,
      lat2: locationLat,
      lon2: locationLon,
    );
    return distance <= radiusMeters;
  }

  /// Formats a distance in meters for display.
  ///
  /// - Below 1000m: "145 m"
  /// - 1000m+: "1.2 km"
  static String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
