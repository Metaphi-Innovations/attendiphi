import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_dashboard_provider.dart';

void main() {
  group('defaultAttendanceSessionDate', () {
    test('returns today when today is Thursday', () {
      final thursday = DateTime(2026, 10, 8); // Thursday
      expect(
        defaultAttendanceSessionDate(
          thursday,
          dateRestrictionEnabled: true,
        ),
        DateTime(2026, 10, 8),
      );
      expect(
        defaultAttendanceSessionDate(
          thursday,
          dateRestrictionEnabled: false,
        ),
        DateTime(2026, 10, 8),
      );
    });

    test('date restriction ON uses previous Thursday mid-week', () {
      final wednesday = DateTime(2026, 10, 7); // Wednesday
      expect(
        defaultAttendanceSessionDate(
          wednesday,
          dateRestrictionEnabled: true,
        ),
        DateTime(2026, 10, 1),
      );
    });

    test('date restriction OFF uses today mid-week', () {
      final wednesday = DateTime(2026, 10, 7); // Wednesday
      expect(
        defaultAttendanceSessionDate(
          wednesday,
          dateRestrictionEnabled: false,
        ),
        DateTime(2026, 10, 7),
      );
    });

    test('date restriction ON keeps previous Thursday on Friday', () {
      final friday = DateTime(2026, 10, 9);
      expect(
        defaultAttendanceSessionDate(friday, dateRestrictionEnabled: true),
        DateTime(2026, 10, 8),
      );
    });

    test('date restriction OFF uses today on Friday', () {
      final friday = DateTime(2026, 10, 9);
      expect(
        defaultAttendanceSessionDate(friday, dateRestrictionEnabled: false),
        DateTime(2026, 10, 9),
      );
    });
  });
}
