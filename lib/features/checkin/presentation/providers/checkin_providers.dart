import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../data/datasources/check_in_remote_data_source.dart';
import '../../data/datasources/notification_dispatch_service.dart';
import '../../data/datasources/supabase_check_in_remote_data_source.dart';
import '../../data/datasources/supabase_notification_dispatch_service.dart';
import '../../data/repositories/check_in_repository_impl.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../../domain/usecases/submit_check_in.dart';

void _requireSupabase(String feature) {
  if (!SupabaseBootstrap.isInitialized) {
    throw ServerException(
      technicalMessage: 'Supabase is not initialized ($feature)',
    );
  }
}

/// Provider for [NotificationDispatchService].
final notificationDispatchServiceProvider =
    Provider<NotificationDispatchService>((ref) {
      _requireSupabase('notification dispatch');
      AppLogger.info(
        'Notification dispatch: Supabase',
        tag: 'CheckInProviders',
      );
      return SupabaseNotificationDispatchService();
    });

/// Provider for check-in remote data (Postgres `check_ins` + session locks).
final checkInRemoteDataSourceProvider = Provider<CheckInRemoteDataSource>((
  ref,
) {
  _requireSupabase('check-in data');
  AppLogger.info('Check-in data source: Supabase', tag: 'CheckInProviders');
  return SupabaseCheckInRemoteDataSource();
});

/// Provider for [CheckInRepository].
final checkInRepositoryProvider = Provider<CheckInRepository>((ref) {
  return CheckInRepositoryImpl(ref.watch(checkInRemoteDataSourceProvider));
});

/// Checked-in member IDs for a QR session day (public projection — no checkIns).
final sessionCheckedInMemberIdsProvider =
    StreamProvider.family<Set<String>, String>((ref, sessionDateYmd) {
      final date = sessionDateYmd.trim();
      if (date.length != 10) {
        return Stream.value(const <String>{});
      }
      return ref
          .watch(checkInRepositoryProvider)
          .streamSessionCheckedInMemberIds(date);
    });

/// @Deprecated Use [sessionCheckedInMemberIdsProvider] on QR. Kept as an alias
/// of the admin [checkInsStreamProvider] only for legacy test overrides.
@Deprecated('Use sessionCheckedInMemberIdsProvider on QR check-in')
final liveCheckInsStreamProvider = StreamProvider<List<CheckInSubmission>>((
  ref,
) {
  return Stream.value(const <CheckInSubmission>[]);
});

/// Provider for [SubmitCheckIn] usecase.
final submitCheckInUseCaseProvider = Provider<SubmitCheckIn>((ref) {
  return SubmitCheckIn(
    ref.watch(checkInRepositoryProvider),
    notificationDispatchService: ref.watch(notificationDispatchServiceProvider),
  );
});
