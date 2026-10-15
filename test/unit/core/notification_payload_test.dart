import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/notifications/notification_service.dart';

void main() {
  group('NotificationPayload', () {
    test('serializes and deserializes correctly', () {
      final now = DateTime.now();
      final payload = NotificationPayload(
        title: 'New Attendance Submission',
        body: 'Omkar (Member) checked in at Excel Plaza',
        submissionId: 'sub-12345',
        userName: 'Omkar',
        locationId: 'loc-001',
        locationName: 'Excel Plaza',
        checkInType: 'member',
        timestamp: now,
        data: {'extraKey': 'extraValue'},
      );

      final map = payload.toMap();
      expect(map['title'], equals('New Attendance Submission'));
      expect(map['submissionId'], equals('sub-12345'));
      expect(map['userName'], equals('Omkar'));
      expect(map['locationName'], equals('Excel Plaza'));

      final reconstructed = NotificationPayload.fromMap(map);
      expect(reconstructed.title, equals('New Attendance Submission'));
      expect(reconstructed.submissionId, equals('sub-12345'));
      expect(reconstructed.userName, equals('Omkar'));
      expect(reconstructed.locationName, equals('Excel Plaza'));
    });

    test('handles default fallbacks for missing fields', () {
      final payload = NotificationPayload.fromMap({});
      expect(payload.title, equals('New Attendance Submission'));
      expect(
        payload.body,
        equals('A new user has submitted the attendance form.'),
      );
      expect(payload.submissionId, isEmpty);
    });
  });
}
