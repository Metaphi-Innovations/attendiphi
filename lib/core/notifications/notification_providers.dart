import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_notification_service.dart';
import 'notification_service.dart';

/// Provider for [NotificationService] instance.
final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = FirebaseNotificationService();
  ref.onDispose(service.dispose);
  return service;
});

/// Stream provider for notification tapped events.
final notificationTappedStreamProvider =
    StreamProvider.autoDispose<NotificationPayload>((ref) {
  final service = ref.watch(notificationServiceProvider);
  return service.onNotificationTapped;
});

/// Future provider for current FCM Device Token.
final fcmTokenProvider = FutureProvider<String?>((ref) async {
  final service = ref.watch(notificationServiceProvider);
  return service.getDeviceToken();
});
