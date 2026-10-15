import 'dart:async';

/// Payload structure representing an admin attendance notification.
class NotificationPayload {
  const NotificationPayload({
    required this.title,
    required this.body,
    required this.submissionId,
    this.userName,
    this.locationId,
    this.locationName,
    this.checkInType,
    this.timestamp,
    this.data = const {},
  });

  final String title;
  final String body;
  final String submissionId;
  final String? userName;
  final String? locationId;
  final String? locationName;
  final String? checkInType;
  final DateTime? timestamp;
  final Map<String, dynamic> data;

  factory NotificationPayload.fromMap(Map<String, dynamic> map) {
    return NotificationPayload(
      title: map['title'] as String? ?? 'New Attendance Submission',
      body:
          map['body'] as String? ??
          'A new user has submitted the attendance form.',
      submissionId:
          map['submissionId'] as String? ?? map['id'] as String? ?? '',
      userName: map['userName'] as String?,
      locationId: map['locationId'] as String?,
      locationName: map['locationName'] as String?,
      checkInType: map['checkInType'] as String? ?? map['type'] as String?,
      timestamp: map['timestamp'] != null
          ? (map['timestamp'] is String
                ? DateTime.tryParse(map['timestamp'] as String)
                : null)
          : null,
      data: map,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'submissionId': submissionId,
      if (userName != null) 'userName': userName,
      if (locationId != null) 'locationId': locationId,
      if (locationName != null) 'locationName': locationName,
      if (checkInType != null) 'checkInType': checkInType,
      if (timestamp != null) 'timestamp': timestamp!.toIso8601String(),
      ...data,
    };
  }
}

/// Abstract contract for device notification services.
abstract class NotificationService {
  /// Initializes push notification channels, permissions, and listeners.
  Future<void> initialize();

  /// Requests notification permissions from user on mobile.
  Future<bool> requestPermissions();

  /// Retrieves the current FCM registration token.
  Future<String?> getDeviceToken();

  /// Stream of FCM token refresh events.
  Stream<String> get onTokenRefresh;

  /// Shows a local foreground notification banner.
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  });

  /// Stream of notification tap events for deep-linking navigation.
  Stream<NotificationPayload> get onNotificationTapped;

  /// Cleans up resources/streams if necessary.
  void dispose();
}
