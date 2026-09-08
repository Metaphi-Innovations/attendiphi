import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/extensions/date_extensions.dart';
import 'package:qr_checkin/core/extensions/string_extensions.dart';

void main() {
  group('StringExtensions', () {
    test('capitalized', () {
      expect('hello'.capitalized, 'Hello');
      expect(''.capitalized, '');
      expect('world'.capitalized, 'World');
    });

    test('truncate', () {
      expect('Hello World'.truncate(5), 'Hello...');
      expect('Hi'.truncate(5), 'Hi');
    });

    test('isValidEmail', () {
      expect('admin@company.com'.isValidEmail, isTrue);
      expect('invalid-email'.isValidEmail, isFalse);
    });

    test('isBlank and isNotBlank', () {
      expect(''.isBlank, isTrue);
      expect('   '.isBlank, isTrue);
      expect('abc'.isBlank, isFalse);
      expect('abc'.isNotBlank, isTrue);
    });
  });

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
