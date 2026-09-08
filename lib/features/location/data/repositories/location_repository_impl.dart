import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/repositories/location_repository.dart';
import '../datasources/location_remote_data_source.dart';

/// Implementation of [LocationRepository] that validates business rules
/// (exists, isActive) and maps exceptions.
class LocationRepositoryImpl implements LocationRepository {
  const LocationRepositoryImpl(this._remoteDataSource);

  final LocationRemoteDataSource _remoteDataSource;

  @override
  Future<LocationConfig> getLocationConfig(String locationId) async {
    final location = await _remoteDataSource.fetchLocation(locationId);

    if (location == null) {
      throw const LocationNotFoundException();
    }

    if (!location.isActive) {
      throw const LocationInactiveException();
    }

    return location;
  }

  @override
  Stream<List<LocationConfig>> getLocations() {
    return _remoteDataSource.streamLocations();
  }
}
