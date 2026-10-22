import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/checkin/domain/session_member_typeahead.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  const employees = [
    Employee(id: 'a', name: 'Ada', phone: '9000000001', isActive: true),
    Employee(id: 'b', name: 'Bob', phone: '9000000002', isActive: true),
    Employee(id: 'c', name: 'Cara', phone: '9000000003', isActive: false),
  ];

  test('does not say all checked in when roster failed to load', () {
    final result = buildSessionMemberTypeahead(
      allEmployees: const [],
      checkedInMemberIds: const {},
    );
    expect(result.filteredEmployees, isEmpty);
    expect(result.emptyMessage, contains('No members available'));
    expect(result.emptyMessage, isNot(contains('already checked in')));
  });

  test('says all checked in only when every active member is excluded', () {
    final result = buildSessionMemberTypeahead(
      allEmployees: employees,
      checkedInMemberIds: {'a', 'b'},
      sessionDateYmd: '2026-10-22',
    );
    expect(result.availableEmployees, isEmpty);
    expect(
      result.emptyMessage,
      'All members have already checked in for this session (2026-10-22)',
    );
  });

  test('keeps unchecked members visible when only some are checked in', () {
    final result = buildSessionMemberTypeahead(
      allEmployees: employees,
      checkedInMemberIds: {'a'},
    );
    expect(result.filteredEmployees.map((e) => e.id), ['b']);
    expect(result.emptyMessage, isNull);
  });

  test('query miss uses no-matching message', () {
    final result = buildSessionMemberTypeahead(
      allEmployees: employees,
      checkedInMemberIds: const {},
      query: 'zzz',
    );
    expect(result.emptyMessage, 'No matching members found');
  });

  test('N members and K checked-in leaves N-K names', () {
    final roster = List<Employee>.generate(
      10,
      (i) => Employee(
        id: 'm$i',
        name: 'Member $i',
        phone: '90000000${i.toString().padLeft(2, '0')}',
        isActive: true,
      ),
    );
    final checked = {'m0', 'm1', 'm2'};
    final result = buildSessionMemberTypeahead(
      allEmployees: roster,
      checkedInMemberIds: checked,
    );
    expect(result.filteredEmployees, hasLength(7));
    expect(
      result.filteredEmployees.every((e) => !checked.contains(e.id)),
      isTrue,
    );
    expect(result.emptyMessage, isNull);
  });
}
