import '../../domain/entities/check_in_restrictions_config.dart';
import '../datasources/app_config_remote_data_source.dart';

abstract class AppConfigRepository {
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions();

  Future<void> setCheckInRestrictions({
    bool? restrictionsEnabled,
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    bool? deviceRestrictionEnabled,
    required String updatedBy,
    String? updatedByEmail,
  });
}

class AppConfigRepositoryImpl implements AppConfigRepository {
  AppConfigRepositoryImpl(this._remote);

  final AppConfigRemoteDataSource _remote;

  @override
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions() {
    return _remote.watchCheckInRestrictions();
  }

  @override
  Future<void> setCheckInRestrictions({
    bool? restrictionsEnabled,
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    bool? deviceRestrictionEnabled,
    required String updatedBy,
    String? updatedByEmail,
  }) {
    return _remote.setCheckInRestrictions(
      restrictionsEnabled: restrictionsEnabled,
      locationRestrictionEnabled: locationRestrictionEnabled,
      dateRestrictionEnabled: dateRestrictionEnabled,
      deviceRestrictionEnabled: deviceRestrictionEnabled,
      updatedBy: updatedBy,
      updatedByEmail: updatedByEmail,
    );
  }
}
