import '../models/location_config_model.dart';

/// Contract for fetching location data (Supabase implementation:
/// `SupabaseLocationRemoteDataSource`).
abstract class LocationRemoteDataSource {
  Future<LocationConfigModel?> fetchLocation(String locationId);
  Stream<List<LocationConfigModel>> streamLocations();
}
