import '../entities/employee.dart';

/// Contract for employee / member roster management.
abstract class EmployeeRepository {
  Stream<List<Employee>> streamEmployees();
  Future<void> addEmployee(
    String name, {
    String email = '',
    String phone = '',
    String role = 'Member',
    String designation = '',
    bool isActive = true,
    String? adminId,
  });
  Future<void> updateEmployee(
    String id,
    String name, {
    String email = '',
    String phone = '',
    String role = 'Member',
    String designation = '',
    bool isActive = true,
    String? adminId,
  });
  Future<void> toggleEmployeeStatus(String id, bool isActive);
  Future<void> deleteEmployee(String id);
  Future<void> deleteAllEmployees();
}
