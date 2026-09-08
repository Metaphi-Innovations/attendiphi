import '../entities/location_config.dart';

/// Contract for fetching and validating check-in locations.
abstract class LocationRepository {
  /// Retrieves the configuration for a given [locationId].
  ///
  /// Throws:
  /// - [LocationNotFoundException] if the location does not exist.
  /// - [LocationInactiveException] if the location is deactivated.
  /// - [ServerException] on Firestore connection failure.
  Future<LocationConfig> getLocationConfig(String locationId);

  /// Streams all active locations for admin management or UI listings.
  Stream<List<LocationConfig>> getLocations();
}
