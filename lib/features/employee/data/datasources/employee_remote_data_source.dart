import '../../domain/entities/employee.dart';

/// Contract for remote operations on the Employee / User collection.
abstract class EmployeeRemoteDataSource {
  Stream<List<Employee>> streamEmployees();
  Stream<List<Employee>> streamPublicMembers();

  /// One-shot public QR directory (no Realtime) — more reliable on mobile Safari.
  Future<List<Employee>> getPublicMembers();

  /// Active members with SFace templates for Face check-in (public QR safe).
  Stream<List<Employee>> streamFaceVerificationCandidates();

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
