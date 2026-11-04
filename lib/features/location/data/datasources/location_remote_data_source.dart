import '../models/location_config_model.dart';

/// Contract for fetching location data (Supabase implementation:
/// `SupabaseLocationRemoteDataSource`).
abstract class LocationRemoteDataSource {
  Future<LocationConfigModel?> fetchLocation(String locationId);
  Stream<List<LocationConfigModel>> streamLocations();

  /// Updates [radiusMeters] for [locationId] (Super Admin write).
  ///
  /// Returns the persisted row so callers can confirm the write.
  Future<LocationConfigModel> updateRadiusMeters({
    required String locationId,
    required double radiusMeters,
  });
}
