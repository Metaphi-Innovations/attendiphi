import '../entities/location_config.dart';
import '../repositories/location_repository.dart';

/// Usecase to fetch and verify location configuration.
class GetLocationConfig {
  const GetLocationConfig(this._repository);

  final LocationRepository _repository;

  Future<LocationConfig> call(String locationId) {
    return _repository.getLocationConfig(locationId);
  }
}
