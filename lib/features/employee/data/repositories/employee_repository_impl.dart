import '../../domain/entities/employee.dart';
import '../../domain/repositories/employee_repository.dart';
import '../datasources/employee_remote_data_source.dart';

/// Implementation of [EmployeeRepository].
class EmployeeRepositoryImpl implements EmployeeRepository {
  const EmployeeRepositoryImpl(this._remoteDataSource);

  final EmployeeRemoteDataSource _remoteDataSource;

  @override
  Stream<List<Employee>> streamEmployees() {
    return _remoteDataSource.streamEmployees();
  }

  @override
  Stream<List<Employee>> streamPublicMembers() {
    return _remoteDataSource.streamPublicMembers();
  }

  @override
  Stream<List<Employee>> streamFaceVerificationCandidates() {
    return _remoteDataSource.streamFaceVerificationCandidates();
  }

  @override
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
  }) {
    return _remoteDataSource.addEmployee(
      name,
      email: email,
      phone: phone,
      role: role,
      designation: designation,
      isActive: isActive,
      adminId: adminId,
      photoUrl: photoUrl,
      faceEmbedding: faceEmbedding,
      faceTemplates: faceTemplates,
      faceEnrolled: faceEnrolled,
      faceModel: faceModel,
      faceModelVersion: faceModelVersion,
    );
  }

  @override
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
  }) {
    return _remoteDataSource.updateEmployee(
      id,
      name,
      email: email,
      phone: phone,
      role: role,
      designation: designation,
      isActive: isActive,
      adminId: adminId,
      photoUrl: photoUrl,
      faceEmbedding: faceEmbedding,
      faceTemplates: faceTemplates,
      faceEnrolled: faceEnrolled,
      faceModel: faceModel,
      faceModelVersion: faceModelVersion,
    );
  }

  @override
  Future<void> toggleEmployeeStatus(String id, bool isActive) {
    return _remoteDataSource.toggleEmployeeStatus(id, isActive);
  }

  @override
  Future<void> deleteEmployee(String id) {
    return _remoteDataSource.deleteEmployee(id);
  }

  @override
  Future<void> deleteAllEmployees() {
    return _remoteDataSource.deleteAllEmployees();
  }

  @override
  Future<Employee?> getEmployee(String id) {
    return _remoteDataSource.getEmployee(id);
  }
}
