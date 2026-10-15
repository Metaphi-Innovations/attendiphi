import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/attendance_substitute_absent_export.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';

CheckInSubmission _record({
  required String name,
  required CheckInType type,
  String? substituteName,
  String? substituteForMember,
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
    substituteForMember: substituteForMember,
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
    test('lists substitute with covered member then absents, A–Z', () {
      final txt = buildSubstituteAbsentAttendanceTxt(
        records: [
          _record(
            name: 'Covered Member One',
            type: CheckInType.substitute,
            substituteName: 'Zara Ali Khan',
            substituteForMember: 'Covered Member One',
          ),
          _record(
            name: 'Covered Two',
            type: CheckInType.substitute,
            substituteName: 'amit shah',
            substituteForMember: 'Covered Two',
          ),
          _record(name: 'Meera Joshi Patel', type: CheckInType.absent),
          _record(name: 'Present Member', type: CheckInType.member),
          _record(name: 'Not Yet', type: CheckInType.notCheckedIn),
        ],
      );

      expect(
        txt,
        'Substitute\n'
        'amit shah (for Covered Two)\n'
        'Zara Khan (for Covered One)\n'
        '\n'
        'Absent\n'
        'Meera Patel\n',
      );
    });

    test('falls back to userName for member when substituteForMember is empty',
        () {
      final txt = buildSubstituteAbsentAttendanceTxt(
        records: [
          _record(
            name: 'Rohan Mehta',
            type: CheckInType.substitute,
            substituteName: 'Pooja Nair',
          ),
        ],
      );

      expect(
        txt,
        'Substitute\n'
        'Pooja Nair (for Rohan Mehta)\n'
        '\n'
        'Absent\n'
        '(none)\n',
      );
    });

    test('omits member clause when covered name is missing', () {
      final txt = buildSubstituteAbsentAttendanceTxt(
        records: [
          _record(
            name: '',
            type: CheckInType.substitute,
            substituteName: 'Solo Sub',
          ),
        ],
      );

      expect(
        txt,
        'Substitute\n'
        'Solo Sub\n'
        '\n'
        'Absent\n'
        '(none)\n',
      );
    });

    test('dedupes identical substitute+member lines', () {
      final txt = buildSubstituteAbsentAttendanceTxt(
        records: [
          _record(
            name: 'Member A',
            type: CheckInType.substitute,
            substituteName: 'Sub One',
            substituteForMember: 'Member A',
          ),
          _record(
            name: 'Member A',
            type: CheckInType.substitute,
            substituteName: 'Sub One',
            substituteForMember: 'Member A',
          ),
        ],
      );

      expect(
        txt,
        'Substitute\n'
        'Sub One (for Member A)\n'
        '\n'
        'Absent\n'
        '(none)\n',
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
