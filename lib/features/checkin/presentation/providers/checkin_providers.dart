import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../location/presentation/providers/location_providers.dart';
import '../../data/datasources/check_in_remote_data_source.dart';
import '../../data/datasources/notification_dispatch_service.dart';
import '../../data/repositories/check_in_repository_impl.dart';
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

/// Provider for [SubmitCheckIn] usecase.
final submitCheckInUseCaseProvider = Provider<SubmitCheckIn>((ref) {
  return SubmitCheckIn(
    ref.watch(checkInRepositoryProvider),
    notificationDispatchService: ref.watch(notificationDispatchServiceProvider),
  );
});
