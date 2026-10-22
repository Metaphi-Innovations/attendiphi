import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../domain/entities/check_in_restrictions_config.dart';
import 'app_config_remote_data_source.dart';

/// Supabase `app_config` implementation of [AppConfigRemoteDataSource].
///
/// Granular flags live in `raw` jsonb so older rows without those keys still
/// work via [restrictions_enabled]. Staging UI writes both.
class SupabaseAppConfigRemoteDataSource implements AppConfigRemoteDataSource {
  SupabaseAppConfigRemoteDataSource({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  static const _pollInterval = Duration(seconds: 20);

  static const _rawLocationKey = 'location_restriction_enabled';
  static const _rawDateKey = 'date_restriction_enabled';
  static const _rawDeviceKey = 'device_restriction_enabled';

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseBootstrap.isInitialized) {
      throw const ServerException(
        userMessage: 'Data service is not ready. Please restart the app.',
        technicalMessage: 'Supabase not initialized (app_config)',
      );
    }
    return Supabase.instance.client;
  }

  String get _docId => AppConstants.checkInRestrictionsDocId;

  CheckInRestrictionsConfig _fromRow(Map<String, dynamic>? row) {
    if (row == null) return CheckInRestrictionsConfig.defaults;

    final master = row['restrictions_enabled'] != false;
    final raw = _asStringKeyedMap(row['raw']);

    final location = _readBool(raw[_rawLocationKey]) ?? master;
    final date = _readBool(raw[_rawDateKey]) ?? master;
    final device = _readBool(raw[_rawDeviceKey]) ?? master;

    return CheckInRestrictionsConfig(
      locationRestrictionEnabled: location,
      dateRestrictionEnabled: date,
      deviceRestrictionEnabled: device,
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      updatedBy: (row['updated_by'] as String?)?.trim(),
      updatedByEmail: (row['updated_by_email'] as String?)?.trim(),
    );
  }

  static Map<String, dynamic> _asStringKeyedMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const {};
  }

  static bool? _readBool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      final lower = value.trim().toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  Future<CheckInRestrictionsConfig> _fetch() async {
    final row = await _client
        .from('app_config')
        .select()
        .eq('id', _docId)
        .maybeSingle();
    return _fromRow(row == null ? null : Map<String, dynamic>.from(row));
  }

  @override
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions() =>
      resilientPollStream(
        fetch: _fetch,
        interval: _pollInterval,
        tag: 'SupabaseAppConfigRemoteDataSource',
      );

  @override
  Future<void> setCheckInRestrictions({
    bool? restrictionsEnabled,
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    bool? deviceRestrictionEnabled,
    required String updatedBy,
    String? updatedByEmail,
  }) async {
    final existing = await _fetch();

    final location =
        locationRestrictionEnabled ??
        restrictionsEnabled ??
        existing.locationRestrictionEnabled;
    final date =
        dateRestrictionEnabled ??
        restrictionsEnabled ??
        existing.dateRestrictionEnabled;
    final device =
        deviceRestrictionEnabled ??
        restrictionsEnabled ??
        existing.deviceRestrictionEnabled;

    // Keep legacy column in sync for older readers / dashboards.
    final master = location || date || device;

    final previousRaw = await _fetchRawMap();
    final nextRaw = <String, dynamic>{
      ...previousRaw,
      _rawLocationKey: location,
      _rawDateKey: date,
      _rawDeviceKey: device,
    };

    await _client.from('app_config').upsert({
      'id': _docId,
      'restrictions_enabled': master,
      'raw': nextRaw,
      'updated_by': updatedBy.trim(),
      'updated_by_email': updatedByEmail?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>> _fetchRawMap() async {
    final row = await _client
        .from('app_config')
        .select('raw')
        .eq('id', _docId)
        .maybeSingle();
    if (row == null) return {};
    return _asStringKeyedMap(row['raw']);
  }
}
