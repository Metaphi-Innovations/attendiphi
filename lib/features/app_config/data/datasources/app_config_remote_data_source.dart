import '../../domain/entities/check_in_restrictions_config.dart';

/// Reads/writes `appConfig/checkInRestrictions`.
abstract class AppConfigRemoteDataSource {
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions();

  /// Persists restriction flags.
  ///
  /// Prefer granular [locationRestrictionEnabled] /
  /// [dateRestrictionEnabled] / [deviceRestrictionEnabled].
  /// If only [restrictionsEnabled] is passed, all granular flags are set to
  /// that value (production master toggle).
  Future<void> setCheckInRestrictions({
    bool? restrictionsEnabled,
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    bool? deviceRestrictionEnabled,
    required String updatedBy,
    String? updatedByEmail,
  });
}
