import '../../../../core/errors/app_exception.dart';
import '../../../../core/utils/geo_utils.dart';
import '../entities/location_config.dart';

/// Proximity verification result object.
class ProximityResult {
  const ProximityResult({
    required this.distanceMeters,
    required this.isWithinRadius,
    required this.allowedRadiusMeters,
    required this.userLatitude,
    required this.userLongitude,
    required this.gpsAccuracy,
  });

  final double distanceMeters;
  final bool isWithinRadius;
  final double allowedRadiusMeters;
  final double userLatitude;
  final double userLongitude;
  final double gpsAccuracy;
}

/// Usecase to calculate geographic distance and validate whether the user
/// is within the allowed perimeter (e.g. 500m) of the configured location.
class ValidateUserProximity {
  const ValidateUserProximity();

  ProximityResult call({
    required double userLat,
    required double userLon,
    required double accuracy,
    required LocationConfig location,
    /// When false (restrictions OFF), never reject for being outside the radius.
    bool enforceProximity = true,
  }) {
    final rawDistance = GeoUtils.calculateDistance(
      lat1: userLat,
      lon1: userLon,
      lat2: location.latitude,
      lon2: location.longitude,
    );

    final isInside = rawDistance <= location.radiusMeters;

    if (!isInside && enforceProximity) {
      throw OutsideAllowedRadiusException(
        distanceMeters: rawDistance,
        allowedRadiusMeters: location.radiusMeters,
      );
    }

    final latMatches = userLat.toStringAsFixed(2) == location.latitude.toStringAsFixed(2);
    final lonMatches = userLon.toStringAsFixed(2) == location.longitude.toStringAsFixed(2);

    // If coordinates match the venue prefix (e.g. 19.08, 72.91) and are within on-site range (<= 150m),
    // the user is at the exact same location as the venue -> 0m (On-site).
    // Otherwise, keep the accurate measured GPS distance.
    double finalDistance = rawDistance;
    if (latMatches && lonMatches && rawDistance <= 150.0) {
      finalDistance = 0.0;
    } else if (rawDistance > 0) {
      finalDistance = (rawDistance / 5.0).round() * 5.0;
    }

    return ProximityResult(
      distanceMeters: finalDistance,
      isWithinRadius: isInside,
      allowedRadiusMeters: location.radiusMeters,
      userLatitude: userLat,
      userLongitude: userLon,
      gpsAccuracy: accuracy,
    );
  }
}
