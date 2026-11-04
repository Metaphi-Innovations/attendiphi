import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../domain/default_location_x.dart';
import '../../domain/entities/location_config.dart';
import '../models/location_config_model.dart';
import 'location_remote_data_source.dart';

LocationConfigModel _modelFromConfig(LocationConfig config) {
  return LocationConfigModel(
    id: config.id,
    name: config.name,
    latitude: config.latitude,
    longitude: config.longitude,
    radiusMeters: config.radiusMeters,
    isActive: config.isActive,
    address: config.address,
  );
}

/// Env-aware `location_x` fallback when Supabase has no row yet.
LocationConfigModel locationXFallbackModel() =>
    _modelFromConfig(DefaultLocationX.current());

/// Supabase Postgres implementation of [LocationRemoteDataSource].
class SupabaseLocationRemoteDataSource implements LocationRemoteDataSource {
  SupabaseLocationRemoteDataSource({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;

  static const _pollInterval = Duration(seconds: 120);

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseBootstrap.isInitialized) {
      throw const ServerException(
        userMessage: 'Data service is not ready. Please restart the app.',
        technicalMessage: 'Supabase not initialized (locations)',
      );
    }
    return Supabase.instance.client;
  }

  LocationConfigModel _fromRow(Map<String, dynamic> row) {
    final raw = row['raw'];
    final rawMap = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return LocationConfigModel.fromMap(row['id']?.toString() ?? '', {
      'name': row['name'] ?? rawMap['name'],
      'latitude': row['latitude'] ?? rawMap['latitude'],
      'longitude': row['longitude'] ?? rawMap['longitude'],
      'radiusMeters':
          row['radius_meters'] ?? rawMap['radiusMeters'] ?? rawMap['radius'],
      'isActive': row['is_active'] ?? rawMap['isActive'] ?? true,
      'address': row['address'] ?? rawMap['address'],
    });
  }

  Future<List<LocationConfigModel>> _fetchAll() async {
    final rows = await _client.from('locations').select().order('name');
    final list = rows
        .map((r) => _fromRow(Map<String, dynamic>.from(r)))
        .toList();
    if (list.isEmpty) return [locationXFallbackModel()];
    return list;
  }

  @override
  Future<LocationConfigModel?> fetchLocation(String locationId) async {
    try {
      final row = await _client
          .from('locations')
          .select()
          .eq('id', locationId)
          .maybeSingle();
      if (row != null) {
        return _fromRow(Map<String, dynamic>.from(row));
      }
      if (locationId == DefaultLocationX.id) return locationXFallbackModel();
      return null;
    } on PostgrestException catch (e, st) {
      AppLogger.warning(
        'Supabase fetchLocation fallback for $locationId: ${e.message}',
        tag: 'SupabaseLocationRemoteDataSource',
      );
      if (locationId == DefaultLocationX.id) return locationXFallbackModel();
      throw ServerException(
        technicalMessage: 'Supabase location error: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (locationId == DefaultLocationX.id) return locationXFallbackModel();
      throw ServerException(
        technicalMessage: 'Unexpected error fetching location: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Stream<List<LocationConfigModel>> streamLocations() => resilientPollStream(
    fetch: _fetchAll,
    interval: _pollInterval,
    tag: 'SupabaseLocationRemoteDataSource',
  );

  @override
  Future<LocationConfigModel> updateRadiusMeters({
    required String locationId,
    required double radiusMeters,
  }) async {
    try {
      final row = await _client
          .from('locations')
          .update({
            'radius_meters': radiusMeters,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', locationId)
          .select()
          .maybeSingle();
      if (row == null) {
        throw const ServerException(
          userMessage:
              'Could not save venue radius. You may not have permission, '
              'or the venue was not found.',
          technicalMessage:
              'Supabase update radius returned no row (RLS or missing id)',
        );
      }
      final saved = _fromRow(Map<String, dynamic>.from(row));
      AppLogger.info(
        'Updated location $locationId radius_meters=${saved.radiusMeters}',
        tag: 'SupabaseLocationRemoteDataSource',
      );
      return saved;
    } on PostgrestException catch (e, st) {
      throw ServerException(
        userMessage: 'Could not save venue radius. Please try again.',
        technicalMessage: 'Supabase update radius: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (e is AppException) rethrow;
      throw ServerException(
        userMessage: 'Could not save venue radius. Please try again.',
        technicalMessage: 'Unexpected error updating radius: $e',
        originalError: e,
        stackTrace: st,
      );
    }
  }
}
