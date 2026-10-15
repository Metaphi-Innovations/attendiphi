import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'local_notification_service.dart';
import 'notification_service.dart';

/// Provider for [NotificationService] (local notifications only — no FCM).
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = LocalNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream provider for notification tapped events.
final notificationTappedStreamProvider =
    StreamProvider.autoDispose<NotificationPayload>((ref) {
      final service = ref.watch(notificationServiceProvider);
      return service.onNotificationTapped;
    });

/// Device id used for session locks / admin device rows (local UUID).
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getDeviceToken();
});
