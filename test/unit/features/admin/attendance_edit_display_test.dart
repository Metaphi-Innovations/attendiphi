import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/attendance_edit_display.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';

CheckInSubmission _record({
  required DateTime timestamp,
  bool isEdited = false,
  DateTime? editedAt,
  CheckInType type = CheckInType.member,
}) {
  return CheckInSubmission(
    id: 'cin_test',
    locationId: 'loc',
    locationName: 'Venue',
    userName: 'Test Member',
    userPhone: '9876543210',
    type: type,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 0,
    distanceMeters: 0,
    timestamp: timestamp,
    isEdited: isEdited,
    editedAt: editedAt,
  );
}

void main() {
  final checkedIn = DateTime(2026, 10, 15, 8, 30);
  final editedAt = DateTime(2026, 10, 15, 18, 5);

  group('attendanceDisplayClock', () {
    test('uses original timestamp when not edited', () {
      final r = _record(timestamp: checkedIn);
      expect(attendanceDisplayClock(r), checkedIn);
    });

    test('uses editedAt when edited', () {
      final r = _record(
        timestamp: checkedIn,
        isEdited: true,
        editedAt: editedAt,
      );
      expect(attendanceDisplayClock(r), editedAt);
    });

    test('falls back to timestamp when edited but editedAt missing', () {
      final r = _record(timestamp: checkedIn, isEdited: true);
      expect(attendanceDisplayClock(r), checkedIn);
    });
  });

  group('attendanceDetailTimestampLabel', () {
    test('plain check-in shows formatted timestamp', () {
      final r = _record(timestamp: checkedIn);
      expect(attendanceDetailTimestampLabel(r), contains('2026'));
      expect(attendanceDetailTimestampLabel(r), isNot(contains('Edited')));
    });

    test('edited with editedAt shows both lines', () {
      final r = _record(
        timestamp: checkedIn,
        isEdited: true,
        editedAt: editedAt,
      );
      final label = attendanceDetailTimestampLabel(r);
      expect(label, startsWith('Checked in:'));
      expect(label, contains('Edited:'));
      expect(label, contains('(by Admin)'));
    });

    test('legacy edited without editedAt keeps original + Edited label', () {
      final r = _record(timestamp: checkedIn, isEdited: true);
      final label = attendanceDetailTimestampLabel(r);
      expect(label, endsWith('(Edited by Admin)'));
      expect(label, isNot(contains('Checked in:')));
    });

    test('not checked in is dash', () {
      final r = _record(
        timestamp: checkedIn,
        type: CheckInType.notCheckedIn,
      );
      expect(attendanceDetailTimestampLabel(r), '-');
    });
  });
}
