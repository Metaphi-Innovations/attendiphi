import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/venue_radius.dart';
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

  @override
  Future<LocationConfig> updateRadiusMeters({
    required String locationId,
    required double radiusMeters,
  }) {
    if (radiusMeters <= 0 || radiusMeters > VenueRadius.maxMeters) {
      throw const ServerException(
        userMessage: 'Enter a valid radius greater than 0 (max 100 km).',
        technicalMessage: 'Invalid venue radiusMeters',
      );
    }
    return _remoteDataSource.updateRadiusMeters(
      locationId: locationId,
      radiusMeters: radiusMeters,
    );
  }
}
