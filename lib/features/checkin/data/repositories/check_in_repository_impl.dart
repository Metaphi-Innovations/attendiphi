import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/paginated_check_ins_result.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../datasources/check_in_remote_data_source.dart';

/// Implementation of [CheckInRepository].
class CheckInRepositoryImpl implements CheckInRepository {
  const CheckInRepositoryImpl(this._remoteDataSource);

  final CheckInRemoteDataSource _remoteDataSource;

  @override
  Future<void> submitCheckIn(
    CheckInSubmission submission, {
    bool enforceThursday = true,
  }) {
    return _remoteDataSource.createCheckIn(
      submission,
      enforceThursday: enforceThursday,
    );
  }

  @override
  Future<void> updateCheckIn(CheckInSubmission submission) {
    return _remoteDataSource.updateCheckIn(submission);
  }

  @override
  Future<void> deleteCheckIn(String checkInId) {
    return _remoteDataSource.deleteCheckIn(checkInId);
  }

  @override
  Future<void> deleteAllCheckIns({String? locationId}) {
    return _remoteDataSource.deleteAllCheckIns(locationId: locationId);
  }

  @override
  Future<bool> hasIdentityCheckedIn(String phone, DateTime sessionDate) {
    return _remoteDataSource.hasIdentityCheckedIn(phone, sessionDate);
  }

  @override
  Future<CheckInSubmission?> getIdentitySubmission(String phone, DateTime sessionDate) {
    return _remoteDataSource.getIdentitySubmission(phone, sessionDate);
  }

  @override
  Future<CheckInSubmission?> getDeviceSubmission(String deviceId, DateTime sessionDate) {
    return _remoteDataSource.getDeviceSubmission(deviceId, sessionDate);
  }

  @override
  Future<void> claimDeviceSessionLock({
    required String deviceId,
    required String sessionDateYmd,
  }) {
    return _remoteDataSource.claimDeviceSessionLock(
      deviceId: deviceId,
      sessionDateYmd: sessionDateYmd,
    );
  }

  @override
  Future<bool> isDeviceSessionLocked({
    required String deviceId,
    required String sessionDateYmd,
  }) {
    return _remoteDataSource.isDeviceSessionLocked(
      deviceId: deviceId,
      sessionDateYmd: sessionDateYmd,
    );
  }

  @override
  Stream<List<CheckInSubmission>> streamCheckIns({String? locationId}) {
    return _remoteDataSource.streamCheckIns(locationId: locationId);
  }

  @override
  Future<PaginatedCheckInsResult> getPaginatedCheckIns({
    int limit = AppConstants.dashboardPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? locationId,
  }) {
    return _remoteDataSource.getPaginatedCheckIns(
      limit: limit,
      startAfter: startAfter,
      locationId: locationId,
    );
  }
}
