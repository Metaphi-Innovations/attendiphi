import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

/// QR typeahead hides members whose ids appear in the public
/// `sessionAttendance/{yyyy-MM-dd}.checkedInMemberIds` projection.
List<Employee> availableMembersForSession({
  required List<Employee> employees,
  required Set<String> checkedInMemberIds,
}) {
  return employees
      .where((emp) => !checkedInMemberIds.contains(emp.id))
      .toList();
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

  test('hides member whose id is in sessionAttendance projection', () {
    final available = availableMembersForSession(
      employees: employees,
      checkedInMemberIds: {'emp_avnish'},
    );
    expect(available.map((e) => e.id), ['emp_rohan']);
  });

  test('resets next session when projection is empty for new date', () {
    final available = availableMembersForSession(
      employees: employees,
      checkedInMemberIds: const {},
    );
    expect(available.map((e) => e.id), ['emp_avnish', 'emp_rohan']);
  });

  test(
    'substitute-for target member id is excluded like a member check-in',
    () {
      final available = availableMembersForSession(
        employees: employees,
        checkedInMemberIds: {'emp_rohan'},
      );
      expect(available.map((e) => e.id), ['emp_avnish']);
    },
  );
}
