import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/attendance_substitute_absent_export.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';

CheckInSubmission _record({
  required String name,
  required CheckInType type,
  String? substituteName,
}) {
  return CheckInSubmission(
    id: 'id_$name',
    locationId: 'loc',
    locationName: 'Venue',
    userName: name,
    userPhone: '9876543210',
    type: type,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 0,
    distanceMeters: 0,
    timestamp: DateTime(2026, 10, 9),
    substituteName: substituteName,
  );
}

void main() {
  group('firstAndLastName', () {
    test('keeps first and last tokens', () {
      expect(firstAndLastName('Rohan Kumar Mehta'), 'Rohan Mehta');
      expect(firstAndLastName('  Pooja  Nair '), 'Pooja Nair');
      expect(firstAndLastName('Asha'), 'Asha');
      expect(firstAndLastName(''), '');
    });
  });

  group('attendanceExportTxtFilename', () {
    test('uses yyyy-MM-dd.txt for the session date', () {
      expect(
        attendanceExportTxtFilename(DateTime(2026, 10, 9)),
        '2026-10-09.txt',
      );
    });
  });

  group('buildSubstituteAbsentAttendanceTxt', () {
    test('lists substitute attendees then absents, A–Z', () {
      final txt = buildSubstituteAbsentAttendanceTxt(
        records: [
          _record(
            name: 'Covered Member',
            type: CheckInType.substitute,
            substituteName: 'Zara Ali Khan',
          ),
          _record(
            name: 'Covered Two',
            type: CheckInType.substitute,
            substituteName: 'amit shah',
          ),
          _record(name: 'Meera Joshi Patel', type: CheckInType.absent),
          _record(name: 'Present Member', type: CheckInType.member),
          _record(name: 'Not Yet', type: CheckInType.notCheckedIn),
        ],
      );

      expect(
        txt,
        'Substitute\n'
        'amit shah\n'
        'Zara Khan\n'
        '\n'
        'Absent\n'
        'Meera Patel\n',
      );
    });

    test('writes (none) when a section is empty', () {
      final txt = buildSubstituteAbsentAttendanceTxt(records: const []);
      expect(
        txt,
        'Substitute\n'
        '(none)\n'
        '\n'
        'Absent\n'
        '(none)\n',
      );
    });
  });
}
