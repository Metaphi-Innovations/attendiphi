import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/app_config.dart';
import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../admin/presentation/providers/admin_auth_provider.dart';
import '../../data/datasources/app_config_remote_data_source.dart';
import '../../data/datasources/supabase_app_config_remote_data_source.dart';
import '../../data/repositories/app_config_repository_impl.dart';
import '../../domain/entities/check_in_restrictions_config.dart';

final appConfigRemoteDataSourceProvider = Provider<AppConfigRemoteDataSource>((
  ref,
) {
  if (!SupabaseBootstrap.isInitialized) {
    throw const ServerException(
      technicalMessage: 'Supabase is not initialized (app_config)',
    );
  }
  AppLogger.info('App config data source: Supabase', tag: 'AppConfigProviders');
  return SupabaseAppConfigRemoteDataSource();
});

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepositoryImpl(ref.watch(appConfigRemoteDataSourceProvider));
});

/// Last successfully loaded or written config.
///
/// Survives [checkInRestrictionsConfigProvider] reload so Super Admin toggles
/// do not snap back to defaults (ON) while the stream is restarting.
class LastKnownCheckInRestrictions extends Notifier<CheckInRestrictionsConfig?> {
  @override
  CheckInRestrictionsConfig? build() {
    ref.keepAlive();
    return null;
  }

  void set(CheckInRestrictionsConfig? config) => state = config;
}

final lastKnownCheckInRestrictionsProvider = NotifierProvider<
    LastKnownCheckInRestrictions, CheckInRestrictionsConfig?>(
  LastKnownCheckInRestrictions.new,
);

/// Live stream of check-in restriction config. Missing doc ⇒ defaults (ON).
///
/// Polls every ~5s; keepAlive so QR + admin share one subscription.
final checkInRestrictionsConfigProvider =
    StreamProvider<CheckInRestrictionsConfig>((ref) {
      ref.keepAlive();
      final stream =
          ref.watch(appConfigRepositoryProvider).watchCheckInRestrictions();
      return stream.map((config) {
        // Keep lastKnown in sync for reload fallback (post-write invalidate).
        Future.microtask(() {
          final last = ref.read(lastKnownCheckInRestrictionsProvider);
          if (last != config) {
            ref.read(lastKnownCheckInRestrictionsProvider.notifier).set(config);
          }
        });
        return config;
      });
    });

CheckInRestrictionsConfig _resolvedRestrictions(
  AsyncValue<CheckInRestrictionsConfig> async,
  CheckInRestrictionsConfig? lastKnown,
) {
  final streamed = async.asData?.value;
  if (streamed != null) return streamed;
  return lastKnown ?? CheckInRestrictionsConfig.defaults;
}

/// True when any restriction is enabled (legacy combined).
final restrictionsEnabledProvider = Provider<bool>((ref) {
  final async = ref.watch(checkInRestrictionsConfigProvider);
  final lastKnown = ref.watch(lastKnownCheckInRestrictionsProvider);
  return _resolvedRestrictions(async, lastKnown).restrictionsEnabled;
});

/// GPS / proximity enforcement (block on deny or outside radius).
final locationRestrictionEnabledProvider = Provider<bool>((ref) {
  final async = ref.watch(checkInRestrictionsConfigProvider);
  final lastKnown = ref.watch(lastKnownCheckInRestrictionsProvider);
  return _resolvedRestrictions(async, lastKnown).locationRestrictionEnabled;
});

/// Thursday-only QR + session-day gate; OFF ⇒ everyday QR / attendance.
final dateRestrictionEnabledProvider = Provider<bool>((ref) {
  final async = ref.watch(checkInRestrictionsConfigProvider);
  final lastKnown = ref.watch(lastKnownCheckInRestrictionsProvider);
  return _resolvedRestrictions(async, lastKnown).dateRestrictionEnabled;
});

/// One device = one check-in per session day; OFF ⇒ shared venue tablets OK.
final deviceRestrictionEnabledProvider = Provider<bool>((ref) {
  final async = ref.watch(checkInRestrictionsConfigProvider);
  final lastKnown = ref.watch(lastKnownCheckInRestrictionsProvider);
  return _resolvedRestrictions(async, lastKnown).deviceRestrictionEnabled;
});

/// True once the restrictions config stream has emitted (doc or default).
final restrictionsConfigReadyProvider = Provider<bool>((ref) {
  return ref.watch(checkInRestrictionsConfigProvider).hasValue;
});

/// Granular Location / Date / Device menu for Super Admin (all environments).
final granularRestrictionsUiEnabledProvider = Provider<bool>((ref) {
  // Keep watching appConfig so tests can override environment if needed.
  ref.watch(appConfigProvider);
  return true;
});

/// Super Admin writes restriction flags.
class CheckInRestrictionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> _ensureSuperAdmin() async {
    final auth = ref.read(adminAuthProvider);
    final admin = auth.currentAdmin;
    if (admin == null || !admin.isSuperAdmin) {
      throw StateError('Only Super Admin can change check-in restrictions.');
    }
  }

  Future<void> _refreshConfig() async {
    ref.invalidate(checkInRestrictionsConfigProvider);
    await ref.read(checkInRestrictionsConfigProvider.future);
  }

  void _rememberConfig(CheckInRestrictionsConfig config) {
    ref.read(lastKnownCheckInRestrictionsProvider.notifier).set(config);
  }

  CheckInRestrictionsConfig _currentConfig() {
    return _resolvedRestrictions(
      ref.read(checkInRestrictionsConfigProvider),
      ref.read(lastKnownCheckInRestrictionsProvider),
    );
  }

  /// Production-style master toggle: sets location + date + device together.
  Future<void> setEnabled(bool enabled) async {
    await _ensureSuperAdmin();
    final auth = ref.read(adminAuthProvider);
    final admin = auth.currentAdmin!;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(appConfigRepositoryProvider)
          .setCheckInRestrictions(
            restrictionsEnabled: enabled,
            updatedBy: admin.id,
            updatedByEmail: admin.email,
          );
      // Remember before invalidate so switches do not snap to defaults (ON).
      _rememberConfig(
        CheckInRestrictionsConfig.fromLegacyMaster(enabled).copyWith(
          updatedAt: DateTime.now().toUtc(),
          updatedBy: admin.id,
          updatedByEmail: admin.email,
        ),
      );
      await _refreshConfig();
    });
  }

  /// Staging granular: update location / date / device independently.
  Future<void> setGranular({
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    bool? deviceRestrictionEnabled,
  }) async {
    await _ensureSuperAdmin();
    final auth = ref.read(adminAuthProvider);
    final admin = auth.currentAdmin!;

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref
          .read(appConfigRepositoryProvider)
          .setCheckInRestrictions(
            locationRestrictionEnabled: locationRestrictionEnabled,
            dateRestrictionEnabled: dateRestrictionEnabled,
            deviceRestrictionEnabled: deviceRestrictionEnabled,
            updatedBy: admin.id,
            updatedByEmail: admin.email,
          );
      // Remember before invalidate so the device switch does not snap back ON.
      _rememberConfig(
        _currentConfig().copyWith(
          locationRestrictionEnabled: locationRestrictionEnabled,
          dateRestrictionEnabled: dateRestrictionEnabled,
          deviceRestrictionEnabled: deviceRestrictionEnabled,
          updatedAt: DateTime.now().toUtc(),
          updatedBy: admin.id,
          updatedByEmail: admin.email,
        ),
      );
      await _refreshConfig();
    });
  }
}

final checkInRestrictionsNotifierProvider =
    AsyncNotifierProvider<CheckInRestrictionsNotifier, void>(
      CheckInRestrictionsNotifier.new,
    );
