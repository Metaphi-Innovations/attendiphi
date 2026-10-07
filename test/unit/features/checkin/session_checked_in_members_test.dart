import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/employee/domain/employee_lookup.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

/// Mirrors check-in form session filtering for unit coverage.
Set<String> checkedInMemberIdsForSession({
  required List<Employee> employees,
  required List<CheckInSubmission> checkIns,
  required DateTime sessionDay,
}) {
  final ids = <String>{};
  for (final sub in checkIns) {
    if (sub.type.isVisitor) continue;
    final local = sub.timestamp.toLocal();
    final sameDay = local.year == sessionDay.year &&
        local.month == sessionDay.month &&
        local.day == sessionDay.day;
    if (!sameDay) continue;
    final matched = EmployeeLookup.forCheckIn(employees, sub);
    if (matched != null) ids.add(matched.id);
  }
  return ids;
}

CheckInSubmission _sub({
  required String id,
  required String name,
  required String phone,
  required DateTime timestamp,
  CheckInType type = CheckInType.member,
  String? memberId,
  String? substituteFor,
}) {
  return CheckInSubmission(
    id: id,
    locationId: 'loc',
    locationName: 'Venue',
    userName: name,
    userPhone: phone,
    type: type,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 5,
    distanceMeters: 0,
    timestamp: timestamp,
    memberId: memberId,
    substituteForMember: substituteFor,
  );
}

void main() {
  const employees = [
    Employee(
      id: 'emp_avnish',
      name: 'Avnish Mehta',
      phone: '9702454242',
      email: 'a@example.com',
    ),
    Employee(
      id: 'emp_rohan',
      name: 'Rohan Mehta',
      phone: '9876543210',
      email: 'r@example.com',
    ),
  ];

  final sessionDay = DateTime(2026, 10, 8);

  test('hides member who checked in on session day', () {
    final ids = checkedInMemberIdsForSession(
      employees: employees,
      checkIns: [
        _sub(
          id: 'c1',
          name: 'Avnish Mehta',
          phone: '9702454242',
          timestamp: DateTime(2026, 10, 8, 11, 30),
          memberId: 'emp_avnish',
        ),
      ],
      sessionDay: sessionDay,
    );
    expect(ids, {'emp_avnish'});
    final available =
        employees.where((e) => !ids.contains(e.id)).map((e) => e.name);
    expect(available, ['Rohan Mehta']);
  });

  test('resets on next Thursday — prior week check-in does not hide name', () {
    final ids = checkedInMemberIdsForSession(
      employees: employees,
      checkIns: [
        _sub(
          id: 'c1',
          name: 'Avnish Mehta',
          phone: '9702454242',
          timestamp: DateTime(2026, 10, 8, 11, 30),
          memberId: 'emp_avnish',
        ),
      ],
      sessionDay: DateTime(2026, 10, 15),
    );
    expect(ids, isEmpty);
  });

  test('substitute check-in removes the target member for that session', () {
    final ids = checkedInMemberIdsForSession(
      employees: employees,
      checkIns: [
        _sub(
          id: 'c2',
          name: 'Someone Else',
          phone: '9000000000',
          timestamp: DateTime(2026, 10, 8, 12),
          type: CheckInType.substitute,
          substituteFor: 'Avnish Mehta',
        ),
      ],
      sessionDay: sessionDay,
    );
    expect(ids, {'emp_avnish'});
  });
}
