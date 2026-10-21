import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/image_utils.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/employee/domain/employee_lookup.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

CheckInSubmission _checkIn({
  required String name,
  String phone = '9876543210',
  CheckInType type = CheckInType.member,
  String? memberId,
  String? substituteForMember,
}) {
  return CheckInSubmission(
    id: 'c1',
    locationId: 'loc',
    locationName: 'Venue',
    userName: name,
    userPhone: phone,
    type: type,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 0,
    distanceMeters: 0,
    timestamp: DateTime(2026, 9, 3),
    memberId: memberId,
    substituteForMember: substituteForMember,
  );
}

void main() {
  const rohan = Employee(id: 'emp_1', name: 'Rohan Mehta', phone: '9876543210');
  const pooja = Employee(
    id: 'emp_2',
    name: 'Pooja Nair',
    phone: '9876543211',
    isActive: false,
  );

  final employees = [rohan, pooja];

  test(
    'resolves renamed member by id even when check-in still has old name',
    () {
      final record = _checkIn(name: 'Old Name', memberId: 'emp_1');
      expect(EmployeeLookup.forCheckIn(employees, record)?.name, 'Rohan Mehta');
    },
  );

  test('resolves member by phone when names differ', () {
    final record = _checkIn(name: 'Rohan M', phone: '+91 9876543210');
    expect(EmployeeLookup.forCheckIn(employees, record)?.id, 'emp_1');
  });

  test(
    'memberId check-in does not attach to another roster member with same phone',
    () {
      const rinku = Employee(
        id: 'emp_rinku',
        name: 'Rinku Saroj',
        phone: '9876543215',
      );
      const nupun = Employee(
        id: 'emp_nupun',
        name: 'Nupun Sawant',
        phone: '9876543215',
      );
      final record = _checkIn(
        name: 'Rinku Saroj',
        phone: '9876543215',
        memberId: 'emp_rinku',
      );

      expect(EmployeeLookup.forCheckIn([rinku], record)?.id, 'emp_rinku');
      expect(EmployeeLookup.forCheckIn([nupun], record), isNull);
      expect(EmployeeLookup.forCheckIn([nupun, rinku], record)?.id, 'emp_rinku');
    },
  );

  test('legacy check-in without memberId still matches by phone', () {
    const rinku = Employee(
      id: 'emp_rinku',
      name: 'Rinku Saroj',
      phone: '9876543215',
    );
    final record = _checkIn(name: 'Someone', phone: '9876543215');
    expect(EmployeeLookup.forCheckIn([rinku], record)?.id, 'emp_rinku');
  });

  test('resolves substitute target by current member name', () {
    final record = _checkIn(
      name: 'Temp Sub',
      phone: '9000000000',
      type: CheckInType.substitute,
      substituteForMember: 'Rohan Mehta',
    );
    expect(EmployeeLookup.forCheckIn(employees, record)?.id, 'emp_1');
  });

  test('resolves substitute target by memberId before name', () {
    final record = _checkIn(
      name: 'Temp Sub',
      phone: '9000000000',
      type: CheckInType.substitute,
      memberId: 'emp_1',
      substituteForMember: 'Pooja Nair',
    );
    expect(EmployeeLookup.forCheckIn(employees, record)?.id, 'emp_1');
  });

  test('scoped list can hide inactive members', () {
    final active = EmployeeLookup.scoped(
      employees: employees,
      activeOnly: true,
    );
    expect(active.map((e) => e.id), ['emp_1']);
  });

  test('QR typeahead roster excludes inactive when activeOnly is true', () {
    // Matches check-in form: EmployeeLookup.scoped(..., activeOnly: true).
    final typeahead = EmployeeLookup.scoped(
      employees: employees,
      activeOnly: true,
    );
    expect(typeahead, hasLength(1));
    expect(typeahead.single.id, 'emp_1');
    expect(typeahead.any((e) => e.id == 'emp_2'), isFalse);
  });

  test('scoped without activeOnly keeps inactive for admin-style lists', () {
    final all = EmployeeLookup.scoped(employees: employees, activeOnly: false);
    expect(all.map((e) => e.id), ['emp_1', 'emp_2']);
  });

  test('cache-busts http photo urls with version stamp', () {
    final url = ImageUtils.cacheBustedUrl(
      'https://cdn.example.com/photo.jpg',
      version: DateTime.fromMillisecondsSinceEpoch(123),
    );
    expect(url, contains('v=123'));
    expect(url, startsWith('https://cdn.example.com/photo.jpg'));
  });

  test('cache-bust without version stays stable across calls', () {
    final a = ImageUtils.cacheBustedUrl('https://cdn.example.com/photo.jpg');
    final b = ImageUtils.cacheBustedUrl('https://cdn.example.com/photo.jpg');
    expect(a, b);
    expect(a, contains('v=0'));
  });

  test('success display uses submitted memberId, not a similar name', () {
    const omkar = Employee(
      id: 'member_omkar',
      name: 'Omkar Anarse',
      phone: '8356011246',
    );
    const omkaarr = Employee(
      id: 'member_omkaarr',
      name: 'Omkaarr',
      phone: '9000000001',
    );
    final roster = [omkaarr, omkar];
    final record = _checkIn(
      name: 'Omkaarr',
      phone: '9000000001',
      memberId: 'member_omkar',
    );

    expect(
      EmployeeLookup.bySubmittedMemberId(roster, record)?.id,
      'member_omkar',
    );
    expect(
      EmployeeLookup.successDisplayName(submission: record, employees: roster),
      'Omkar Anarse',
    );
    expect(
      EmployeeLookup.successDisplayName(submission: record, employees: roster),
      isNot('Omkaarr'),
    );
  });

  test(
    'success display keeps the exact submitted member among similar names',
    () {
      const memberB = Employee(id: 'member_b', name: 'Omkar A');
      const memberC = Employee(id: 'member_c', name: 'Omkar Anarse');
      final roster = [memberB, memberC];
      final recordB = _checkIn(name: 'wrong cache', memberId: 'member_b');
      final recordC = _checkIn(name: 'wrong cache', memberId: 'member_c');

      expect(
        EmployeeLookup.successDisplayName(
          submission: recordB,
          employees: roster,
        ),
        'Omkar A',
      );
      expect(
        EmployeeLookup.successDisplayName(
          submission: recordC,
          employees: roster,
        ),
        'Omkar Anarse',
      );
    },
  );

  test('success display falls back to submission userName when memberId is missing', () {
    final record = _checkIn(name: 'Visitor Name');
    expect(
      EmployeeLookup.successDisplayName(
        submission: record,
        employees: employees,
      ),
      'Visitor Name',
    );
  });

  test('success display ignores stale userName and same-phone members', () {
    const omkar = Employee(
      id: 'member_omkar',
      name: 'Omkar Anarse',
      phone: '8356011246',
    );
    const duplicatePhone = Employee(
      id: 'member_omkar_inactive',
      name: 'omkar',
      phone: '8356011246',
      isActive: false,
    );
    final record = _checkIn(
      name: 'omkaaarr',
      phone: '8356011246',
      memberId: 'member_omkar',
    );

    expect(
      EmployeeLookup.successDisplayName(
        submission: record,
        employees: [duplicatePhone, omkar],
        authoritativeMember: omkar,
      ),
      'Omkar Anarse',
    );
    expect(
      EmployeeLookup.successDisplayName(
        submission: record,
        employees: const [],
        memberId: 'member_omkar',
      ),
      'omkaaarr',
    );
  });
}
