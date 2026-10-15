import '../../domain/entities/check_in_restrictions_config.dart';

/// Reads/writes `appConfig/checkInRestrictions`.
abstract class AppConfigRemoteDataSource {
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions();
  Future<void> setCheckInRestrictions({
    required bool restrictionsEnabled,
    required String updatedBy,
    String? updatedByEmail,
  });
}
