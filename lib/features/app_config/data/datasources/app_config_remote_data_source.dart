import '../../domain/entities/check_in_restrictions_config.dart';

/// Reads/writes `appConfig/checkInRestrictions`.
abstract class AppConfigRemoteDataSource {
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions();

  /// Persists restriction flags.
  ///
  /// Prefer granular [locationRestrictionEnabled] / [dateRestrictionEnabled].
  /// If only [restrictionsEnabled] is passed, both granular flags are set to
  /// that value (production master toggle).
  Future<void> setCheckInRestrictions({
    bool? restrictionsEnabled,
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    required String updatedBy,
    String? updatedByEmail,
  });
}
