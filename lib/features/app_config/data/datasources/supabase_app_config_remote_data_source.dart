import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../domain/entities/check_in_restrictions_config.dart';
import 'app_config_remote_data_source.dart';

/// Supabase `app_config` implementation of [AppConfigRemoteDataSource].
class SupabaseAppConfigRemoteDataSource implements AppConfigRemoteDataSource {
  SupabaseAppConfigRemoteDataSource({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  static const _pollInterval = Duration(seconds: 60);

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
    return CheckInRestrictionsConfig(
      restrictionsEnabled: row['restrictions_enabled'] != false,
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? ''),
      updatedBy: (row['updated_by'] as String?)?.trim(),
      updatedByEmail: (row['updated_by_email'] as String?)?.trim(),
    );
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
    required bool restrictionsEnabled,
    required String updatedBy,
    String? updatedByEmail,
  }) async {
    await _client.from('app_config').upsert({
      'id': _docId,
      'restrictions_enabled': restrictionsEnabled,
      'updated_by': updatedBy.trim(),
      'updated_by_email': updatedByEmail?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }
}
