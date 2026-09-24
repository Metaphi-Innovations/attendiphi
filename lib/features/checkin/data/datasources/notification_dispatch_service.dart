import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/check_in_submission.dart';

/// Writes a Firestore `admin_notifications` document after check-in.
///
/// Server-side FCM multicast requires Cloud Functions / Admin SDK and is not
/// used on the Spark plan. Signed-in admin clients still see live check-ins
/// via Firestore listeners and local notifications.
class NotificationDispatchService {
  NotificationDispatchService(this._firestore);

  final FirebaseFirestore _firestore;

  /// Dispatches an admin notification trigger for a new check-in submission.
  Future<void> dispatchAdminCheckInNotification(
    CheckInSubmission submission,
  ) async {
    try {
      const title = 'New Attendance Submission';
      final body =
          '${submission.userName} (${submission.type.name}) has submitted the attendance form.';

      final notificationDoc = {
        'title': title,
        'body': body,
        'submissionId': submission.id,
        'locationId': submission.locationId,
        'locationName': submission.locationName,
        'userName': submission.userName,
        'userPhone': submission.userPhone,
        'checkInType': submission.type.name,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'targetRole': 'admin',
        'data': {
          'submissionId': submission.id,
          'locationId': submission.locationId,
          'locationName': submission.locationName,
          'type': submission.type.name,
          'userName': submission.userName,
          'userPhone': submission.userPhone,
          'timestamp': submission.timestamp.toIso8601String(),
        },
      };

      await _firestore
          .collection(AppConstants.adminNotificationsCollection)
          .doc(submission.id)
          .set(notificationDoc);

      AppLogger.info(
        'Admin notification trigger dispatched for check-in ${submission.id} (${submission.userName})',
        tag: 'NotificationDispatchService',
      );
    } catch (e, st) {
      // Notification dispatch failure should be logged and not crash the UI flow,
      // as the check-in data has already been safely persisted.
      AppLogger.error(
        'Failed to dispatch admin notification trigger: $e',
        error: e,
        stackTrace: st,
        tag: 'NotificationDispatchService',
      );
    }
  }
}
