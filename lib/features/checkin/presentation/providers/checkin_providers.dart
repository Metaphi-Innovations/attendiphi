import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/presentation/providers/location_providers.dart';
import '../../data/datasources/check_in_remote_data_source.dart';
import '../../data/datasources/notification_dispatch_service.dart';
import '../../data/repositories/check_in_repository_impl.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/repositories/check_in_repository.dart';
import '../../domain/usecases/submit_check_in.dart';

/// Provider for [NotificationDispatchService].
final notificationDispatchServiceProvider =
    Provider<NotificationDispatchService>((ref) {
  return NotificationDispatchService(ref.watch(firestoreProvider));
});

/// Provider for [CheckInRemoteDataSource].
final checkInRemoteDataSourceProvider =
    Provider<CheckInRemoteDataSource>((ref) {
  return CheckInRemoteDataSourceImpl(ref.watch(firestoreProvider));
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
final liveCheckInsStreamProvider =
    StreamProvider<List<CheckInSubmission>>((ref) {
  // Intentionally empty on QR paths — do not open unbounded checkIns here.
  return Stream.value(const <CheckInSubmission>[]);
});

/// Provider for [SubmitCheckIn] usecase.
final submitCheckInUseCaseProvider = Provider<SubmitCheckIn>((ref) {
  return SubmitCheckIn(
    ref.watch(checkInRepositoryProvider),
    notificationDispatchService: ref.watch(notificationDispatchServiceProvider),
  );
});
