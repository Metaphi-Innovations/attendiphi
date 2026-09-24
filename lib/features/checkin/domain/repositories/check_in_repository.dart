import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../entities/check_in_submission.dart';
import '../entities/paginated_check_ins_result.dart';

/// Contract for recording, streaming, and paginating check-in submissions.
abstract class CheckInRepository {
  /// Submits an attendance check-in record to Firestore.
  Future<void> submitCheckIn(CheckInSubmission submission);

  /// Updates an existing check-in record in Firestore.
  Future<void> updateCheckIn(CheckInSubmission submission);

  /// Deletes a check-in record from Firestore by ID.
  Future<void> deleteCheckIn(String checkInId);

  /// Deletes all check-in records from Firestore.
  Future<void> deleteAllCheckIns({String? locationId});

  /// Checks if a specific identity (phone) has already checked in on a given date.
  Future<bool> hasIdentityCheckedIn(String phone, DateTime sessionDate);

  /// Retrieves the existing submission for a specific identity (phone) on a given date if present.
  Future<CheckInSubmission?> getIdentitySubmission(String phone, DateTime sessionDate);

  /// Retrieves the existing submission for a specific deviceId on a given date if present.
  Future<CheckInSubmission?> getDeviceSubmission(String deviceId, DateTime sessionDate);

  /// Atomically claims one-device-one-check-in for [deviceId] on [sessionDateYmd].
  /// Throws [DuplicateCheckInException] if the lock already exists.
  Future<void> claimDeviceSessionLock({
    required String deviceId,
    required String sessionDateYmd,
  });

  /// Streams check-ins for the admin dashboard.
  Stream<List<CheckInSubmission>> streamCheckIns({String? locationId});

  /// Fetches a paginated cursor page of check-ins from Firestore.
  Future<PaginatedCheckInsResult> getPaginatedCheckIns({
    int limit = AppConstants.dashboardPageSize,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    String? locationId,
  });
}
