import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../data/datasources/location_device_data_source.dart';
import '../../data/datasources/location_remote_data_source.dart';
import '../../data/datasources/supabase_location_remote_data_source.dart';
import '../../data/repositories/location_repository_impl.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/repositories/location_repository.dart';
import '../../domain/usecases/get_current_position.dart';
import '../../domain/usecases/get_location_config.dart';
import '../../domain/usecases/validate_user_proximity.dart';

/// Provider for [LocationRemoteDataSource] (Postgres `locations`).
final locationRemoteDataSourceProvider = Provider<LocationRemoteDataSource>((
  ref,
) {
  if (!SupabaseBootstrap.isInitialized) {
    throw const ServerException(
      technicalMessage: 'Supabase is not initialized (locations)',
    );
  }
  AppLogger.info('Location data source: Supabase', tag: 'LocationProviders');
  return SupabaseLocationRemoteDataSource();
});

/// Provider for [LocationRepository].
final locationRepositoryProvider = Provider<LocationRepository>((ref) {
  return LocationRepositoryImpl(ref.watch(locationRemoteDataSourceProvider));
});

/// Provider for [GetLocationConfig] usecase.
final getLocationConfigUseCaseProvider = Provider<GetLocationConfig>((ref) {
  return GetLocationConfig(ref.watch(locationRepositoryProvider));
});

/// Provider for [LocationDeviceDataSource].
final locationDeviceDataSourceProvider = Provider<LocationDeviceDataSource>((
  ref,
) {
  return LocationDeviceDataSourceImpl();
});

/// Provider for [GetCurrentPosition] usecase.
final getCurrentPositionUseCaseProvider = Provider<GetCurrentPosition>((ref) {
  return GetCurrentPosition(ref.watch(locationDeviceDataSourceProvider));
});

/// Provider for [ValidateUserProximity] usecase.
final validateUserProximityUseCaseProvider = Provider<ValidateUserProximity>((
  ref,
) {
  return const ValidateUserProximity();
});

/// Family provider to fetch a single location configuration by ID.
final locationConfigFamilyProvider =
    FutureProvider.family<LocationConfig, String>((ref, locationId) async {
      final useCase = ref.watch(getLocationConfigUseCaseProvider);
      return useCase(locationId);
    });
