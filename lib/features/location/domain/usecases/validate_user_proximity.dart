import '../../../../core/errors/app_exception.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/geo_utils.dart';
import '../entities/location_config.dart';
import '../venue_radius.dart';

/// Proximity verification result object.
class ProximityResult {
  const ProximityResult({
    required this.distanceMeters,
    required this.isWithinRadius,
    required this.allowedRadiusMeters,
    required this.userLatitude,
    required this.userLongitude,
    required this.gpsAccuracy,
    this.isVerified = false,
  });

  final double distanceMeters;
  final bool isWithinRadius;
  final double allowedRadiusMeters;
  final double userLatitude;
  final double userLongitude;
  final double gpsAccuracy;

  /// True only when built from a real device fix that is inside the radius
  /// with usable accuracy. Placeholder results (restriction OFF bypass) keep
  /// the default `false` and must not satisfy an enforced location check.
  final bool isVerified;
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

    // An uncertainty circle wider than the venue radius cannot prove presence
    // either way unless even its nearest edge is outside. Treat that as
    // inconclusive (retry for a better fix) rather than widening the radius.
    final accuracyConclusive = accuracy <= location.radiusMeters;

    if (enforceProximity) {
      if (!accuracyConclusive &&
          rawDistance - accuracy <= location.radiusMeters) {
        throw LocationAccuracyTooLowException(
          accuracy: accuracy,
          technicalMessage:
              'Accuracy ${accuracy.toStringAsFixed(0)}m exceeds venue radius '
              '${location.radiusMeters.toStringAsFixed(0)}m '
              '(distance ${rawDistance.toStringAsFixed(0)}m).',
        );
      }
      if (!isInside) {
        throw OutsideAllowedRadiusException(
          distanceMeters: rawDistance,
          allowedRadiusMeters: location.radiusMeters,
          userMessage: AppStrings.locationOutsideAllowedRadius(
            distanceMeters: rawDistance,
            allowedLabel: VenueRadius.formatFriendly(location.radiusMeters),
          ),
        );
      }
    }

    final latMatches =
        userLat.toStringAsFixed(2) == location.latitude.toStringAsFixed(2);
    final lonMatches =
        userLon.toStringAsFixed(2) == location.longitude.toStringAsFixed(2);

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
      isVerified: isInside && accuracyConclusive,
    );
  }
}
