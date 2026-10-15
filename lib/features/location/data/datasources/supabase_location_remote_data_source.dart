import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/supabase/resilient_poll_stream.dart';
import '../models/location_config_model.dart';
import 'location_remote_data_source.dart';

/// Built-in Jade venue (same as Firestore fallback).
const _locationXFallback = LocationConfigModel(
  id: 'location_x',
  name: 'Jade Luxury Banquets, Mumbai',
  latitude: 18.9888622,
  longitude: 72.8152475,
  radiusMeters: 500.0,
  isActive: true,
  address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
);

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
    if (list.isEmpty) return const [_locationXFallback];
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
      if (locationId == 'location_x') return _locationXFallback;
      return null;
    } on PostgrestException catch (e, st) {
      AppLogger.warning(
        'Supabase fetchLocation fallback for $locationId: ${e.message}',
        tag: 'SupabaseLocationRemoteDataSource',
      );
      if (locationId == 'location_x') return _locationXFallback;
      throw ServerException(
        technicalMessage: 'Supabase location error: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    } catch (e, st) {
      if (locationId == 'location_x') return _locationXFallback;
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
}
