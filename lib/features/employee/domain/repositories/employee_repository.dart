import '../entities/employee.dart';

/// Contract for employee / member roster management.
abstract class EmployeeRepository {
  Stream<List<Employee>> streamEmployees();

  /// Public QR directory: id, name, phone, isActive only (no email/photos/biometrics).
  Stream<List<Employee>> streamPublicMembers();

  Future<void> addEmployee(
    String name, {
    String email = '',
    String phone = '',
    String role = 'Member',
    String designation = '',
    bool isActive = true,
    String? adminId,
    String? photoUrl,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    bool faceEnrolled = false,
    String? faceModel,
    String? faceModelVersion,
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
    String? photoUrl,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    bool? faceEnrolled,
    String? faceModel,
    String? faceModelVersion,
  });
  Future<void> toggleEmployeeStatus(String id, bool isActive);
  Future<void> deleteEmployee(String id);
  Future<void> deleteAllEmployees();
  Future<Employee?> getEmployee(String id);
}
