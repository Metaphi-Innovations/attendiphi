import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  test('Employee.fromMap converts createdAt UTC to local', () {
    final employee = Employee.fromMap({
      'id': 'm1',
      'name': 'omkar',
      'createdAt': '2026-10-19T07:03:00.000Z',
    }, docId: 'm1');

    expect(employee.createdAt, isNotNull);
    expect(employee.createdAt!.isUtc, isFalse);
    expect(
      employee.createdAt,
      DateTime.parse('2026-10-19T07:03:00.000Z').toLocal(),
    );
  });
}
