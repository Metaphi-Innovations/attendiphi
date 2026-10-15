import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/check_in_submission.dart';
import 'notification_dispatch_service.dart';

/// Writes `admin_notifications` in Supabase (same role as Firestore dispatch).
class SupabaseNotificationDispatchService
    implements NotificationDispatchService {
  SupabaseNotificationDispatchService({SupabaseClient? client})
    : _clientOverride = client;

  final SupabaseClient? _clientOverride;
  static const _uuid = Uuid();

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseBootstrap.isInitialized) {
      throw StateError('Supabase not initialized (notifications)');
    }
    return Supabase.instance.client;
  }

  @override
  Future<void> dispatchAdminCheckInNotification(
    CheckInSubmission submission,
  ) async {
    try {
      const title = 'New Attendance Submission';
      final body =
          '${submission.userName} (${submission.type.name}) has submitted the attendance form.';
      final id = submission.id.trim().isNotEmpty
          ? submission.id.trim()
          : _uuid.v4();

      // Insert-only under P0 RLS (anon cannot SELECT/UPDATE notifications).
      await _client.from('admin_notifications').insert({
        'id': id,
        'title': title,
        'body': body,
        'submission_id': submission.id,
        'location_id': submission.locationId,
        'location_name': submission.locationName,
        'user_name': submission.userName,
        'user_phone': submission.userPhone,
        'check_in_type': submission.type.name,
        'status': 'pending',
        'target_role': 'admin',
        'timestamp': DateTime.now().toUtc().toIso8601String(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'data': {
          'submissionId': submission.id,
          'locationId': submission.locationId,
          'locationName': submission.locationName,
          'type': submission.type.name,
          'userName': submission.userName,
          'userPhone': submission.userPhone,
          'timestamp': submission.timestamp.toIso8601String(),
        },
      });

      AppLogger.info(
        'Admin notification (Supabase) for check-in ${submission.id}',
        tag: 'SupabaseNotificationDispatch',
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to dispatch admin notification (Supabase): $e',
        error: e,
        stackTrace: st,
        tag: 'SupabaseNotificationDispatch',
      );
    }
  }
}
