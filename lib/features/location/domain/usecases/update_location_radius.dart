import '../entities/location_config.dart';
import '../repositories/location_repository.dart';

/// Persists venue check-in radius (meters) for a location.
class UpdateLocationRadius {
  const UpdateLocationRadius(this._repository);

  final LocationRepository _repository;

  Future<LocationConfig> call({
    required String locationId,
    required double radiusMeters,
  }) {
    return _repository.updateRadiusMeters(
      locationId: locationId,
      radiusMeters: radiusMeters,
    );
  }
}
