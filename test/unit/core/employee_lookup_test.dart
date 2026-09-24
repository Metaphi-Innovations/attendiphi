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
  const rohan = Employee(
    id: 'emp_1',
    name: 'Rohan Mehta',
    phone: '9876543210',
  );
  const pooja = Employee(
    id: 'emp_2',
    name: 'Pooja Nair',
    phone: '9876543211',
    isActive: false,
  );

  final employees = [rohan, pooja];

  test('resolves renamed member by id even when check-in still has old name', () {
    final record = _checkIn(name: 'Old Name', memberId: 'emp_1');
    expect(EmployeeLookup.forCheckIn(employees, record)?.name, 'Rohan Mehta');
  });

  test('resolves member by phone when names differ', () {
    final record = _checkIn(name: 'Rohan M', phone: '+91 9876543210');
    expect(EmployeeLookup.forCheckIn(employees, record)?.id, 'emp_1');
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

  test('scoped list can hide inactive members', () {
    final active = EmployeeLookup.scoped(
      employees: employees,
      activeOnly: true,
    );
    expect(active.map((e) => e.id), ['emp_1']);
  });

  test('cache-busts http photo urls with version stamp', () {
    final url = ImageUtils.cacheBustedUrl(
      'https://cdn.example.com/photo.jpg',
      version: DateTime.fromMillisecondsSinceEpoch(123),
    );
    expect(url, contains('v=123'));
    expect(url, startsWith('https://cdn.example.com/photo.jpg'));
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

    expect(EmployeeLookup.bySubmittedMemberId(roster, record)?.id, 'member_omkar');
    expect(
      EmployeeLookup.successDisplayName(submission: record, employees: roster),
      'Omkar Anarse',
    );
    expect(
      EmployeeLookup.successDisplayName(submission: record, employees: roster),
      isNot('Omkaarr'),
    );
  });

  test('success display keeps the exact submitted member among similar names', () {
    const memberB = Employee(id: 'member_b', name: 'Omkar A');
    const memberC = Employee(id: 'member_c', name: 'Omkar Anarse');
    final roster = [memberB, memberC];
    final recordB = _checkIn(name: 'wrong cache', memberId: 'member_b');
    final recordC = _checkIn(name: 'wrong cache', memberId: 'member_c');

    expect(
      EmployeeLookup.successDisplayName(submission: recordB, employees: roster),
      'Omkar A',
    );
    expect(
      EmployeeLookup.successDisplayName(submission: recordC, employees: roster),
      'Omkar Anarse',
    );
  });

  test('success display falls back to submission userName when memberId is missing', () {
    final record = _checkIn(name: 'Visitor Name');
    expect(
      EmployeeLookup.successDisplayName(submission: record, employees: employees),
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
