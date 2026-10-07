import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../admin/presentation/providers/admin_auth_provider.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../data/datasources/app_config_remote_data_source.dart';
import '../../data/repositories/app_config_repository_impl.dart';
import '../../domain/entities/check_in_restrictions_config.dart';

final appConfigRemoteDataSourceProvider =
    Provider<AppConfigRemoteDataSource>((ref) {
  return AppConfigRemoteDataSourceImpl(ref.watch(firestoreProvider));
});

final appConfigRepositoryProvider = Provider<AppConfigRepository>((ref) {
  return AppConfigRepositoryImpl(ref.watch(appConfigRemoteDataSourceProvider));
});

/// Live stream of check-in restriction config. Missing doc ⇒ defaults (ON).
final checkInRestrictionsConfigProvider =
    StreamProvider<CheckInRestrictionsConfig>((ref) {
  ref.keepAlive();
  return ref.watch(appConfigRepositoryProvider).watchCheckInRestrictions();
});

/// Convenience: whether production check-in restrictions are enforced.
///
/// Prefer [checkInRestrictionsConfigProvider] on QR screens so UI can wait
/// until Firestore has answered (missing doc ⇒ ON). Do not treat "loading"
/// as ON for gate screens — that wrongly blocks past/upcoming QRs while
/// Super Admin has already turned restrictions OFF.
final restrictionsEnabledProvider = Provider<bool>((ref) {
  final async = ref.watch(checkInRestrictionsConfigProvider);
  return async.maybeWhen(
    data: (config) => config.restrictionsEnabled,
    orElse: () => true,
  );
});

/// True once the restrictions config stream has emitted (doc or default).
final restrictionsConfigReadyProvider = Provider<bool>((ref) {
  return ref.watch(checkInRestrictionsConfigProvider).hasValue;
});

/// Super Admin writes the master toggle.
class CheckInRestrictionsNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> setEnabled(bool enabled) async {
    final auth = ref.read(adminAuthProvider);
    final admin = auth.currentAdmin;
    if (admin == null || !admin.isSuperAdmin) {
      throw StateError('Only Super Admin can change check-in restrictions.');
    }

    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(appConfigRepositoryProvider).setCheckInRestrictions(
            restrictionsEnabled: enabled,
            updatedBy: admin.id,
            updatedByEmail: admin.email,
          );
    });
  }
}

final checkInRestrictionsNotifierProvider =
    AsyncNotifierProvider<CheckInRestrictionsNotifier, void>(
  CheckInRestrictionsNotifier.new,
);
