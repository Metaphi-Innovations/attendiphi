import '../../domain/entities/check_in_submission.dart';

/// Writes an admin notification after check-in (Supabase implementation:
/// `SupabaseNotificationDispatchService`).
abstract class NotificationDispatchService {
  Future<void> dispatchAdminCheckInNotification(CheckInSubmission submission);
}
