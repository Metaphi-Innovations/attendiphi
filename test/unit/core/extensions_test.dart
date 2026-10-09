import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/extensions/date_extensions.dart';

void main() {
  group('DateExtensions', () {
    test('formattedDate and formattedTime format properly', () {
      final date = DateTime(2026, 8, 26, 13, 30);
      expect(date.formattedDate, isNotEmpty);
      expect(date.formattedTime, isNotEmpty);
      expect(date.formattedDateTime, contains('2026'));
      expect(date.formattedDateShort, '26/08/2026');
    });

    test('timeAgo calculates relative times', () {
      final now = DateTime.now();
      expect(now.subtract(const Duration(seconds: 10)).timeAgo, 'just now');
      expect(now.subtract(const Duration(minutes: 5)).timeAgo, '5 mins ago');
      expect(now.subtract(const Duration(hours: 2)).timeAgo, '2 hrs ago');
    });
  });
}
