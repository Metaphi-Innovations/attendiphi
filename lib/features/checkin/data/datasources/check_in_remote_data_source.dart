import 'dart:async';

import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/check_in_type.dart';
import '../../domain/entities/paginated_check_ins_result.dart';
import '../../domain/entities/public_device_session_attendance.dart';

/// Remote data source for check-ins (Supabase implementation:
/// `SupabaseCheckInRemoteDataSource`).
abstract class CheckInRemoteDataSource {
  Future<void> createCheckIn(
    CheckInSubmission submission, {
    bool enforceThursday = true,
    String? sessionDateYmd,
    String? claimDeviceId,
    String? claimMemberId,
    String? sessionToken,
  });
  Future<void> updateCheckIn(CheckInSubmission submission);
  Future<void> deleteCheckIn(String checkInId);
  Future<void> deleteAllCheckIns({String? locationId});
  Stream<List<CheckInSubmission>> streamCheckIns({
    String? locationId,
    String? sessionDateYmd,
    String? sessionDateFrom,
    String? sessionDateTo,
  });
  Stream<Set<String>> streamSessionCheckedInMemberIds(String sessionDateYmd);

  /// Signed URL (or data: URI for legacy base64) for on-demand photo display.
  Future<String?> resolveCheckInPhotoUrl(CheckInSubmission submission);
  Future<PaginatedCheckInsResult> getPaginatedCheckIns({
    int limit = AppConstants.dashboardPageSize,
    Object? startAfter,
    String? locationId,
  });
  Future<bool> hasIdentityCheckedIn(
    String phone,
    DateTime sessionDate, {
    CheckInType? type,
  });
  Future<CheckInSubmission?> getIdentitySubmission(
    String phone,
    DateTime sessionDate, {
    CheckInType? type,
  });
  Future<CheckInSubmission?> getDeviceSubmission(
    String deviceId,
    DateTime sessionDate,
  );

  /// Creates `deviceSessionLocks/{deviceId}_{sessionDate}` once. Fails if already claimed.
  Future<void> claimDeviceSessionLock({
    required String deviceId,
    required String sessionDateYmd,
  });

  /// Checks if a device session lock exists for `deviceSessionLocks/{deviceId}_{sessionDate}`.
  Future<bool> isDeviceSessionLocked({
    required String deviceId,
    required String sessionDateYmd,
  });

  /// Anon-safe SECURITY DEFINER lookup: prior check-in for this device + session.
  ///
  /// Used after clear-site-data when direct SELECT on locks/check_ins is denied.
  Future<PublicDeviceSessionAttendance?> getPublicDeviceSessionAttendance({
    required String deviceId,
    required String sessionDateYmd,
  });

  /// Anon-safe SECURITY DEFINER lookup: one check-in summary by id.
  ///
  /// Used by `/checkin-result?checkInId=` after refresh / paste (no GoRouter extra).
  Future<CheckInSubmission?> getPublicCheckInSummary(String checkInId);
}
