import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_dashboard_provider.dart';

void main() {
  group('defaultAttendanceSessionDate', () {
    test('returns today when today is Thursday', () {
      final thursday = DateTime(2026, 10, 8); // Thursday
      expect(
        defaultAttendanceSessionDate(thursday, restrictionsEnabled: true),
        DateTime(2026, 10, 8),
      );
      expect(
        defaultAttendanceSessionDate(thursday, restrictionsEnabled: false),
        DateTime(2026, 10, 8),
      );
    });

    test('restrictions ON uses previous Thursday mid-week', () {
      final wednesday = DateTime(2026, 10, 7); // Wednesday
      expect(
        defaultAttendanceSessionDate(wednesday, restrictionsEnabled: true),
        DateTime(2026, 10, 1),
      );
    });

    test('restrictions OFF uses next Thursday mid-week', () {
      final wednesday = DateTime(2026, 10, 7); // Wednesday
      expect(
        defaultAttendanceSessionDate(wednesday, restrictionsEnabled: false),
        DateTime(2026, 10, 8),
      );
    });

    test('restrictions ON keeps previous Thursday on Friday', () {
      final friday = DateTime(2026, 10, 9);
      expect(
        defaultAttendanceSessionDate(friday, restrictionsEnabled: true),
        DateTime(2026, 10, 8),
      );
    });

    test('restrictions OFF jumps to next Thursday on Friday', () {
      final friday = DateTime(2026, 10, 9);
      expect(
        defaultAttendanceSessionDate(friday, restrictionsEnabled: false),
        DateTime(2026, 10, 15),
      );
    });
  });
}
