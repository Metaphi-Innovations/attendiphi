import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/employee.dart';

/// Contract for remote operations on the Employee / User collection.
abstract class EmployeeRemoteDataSource {
  Stream<List<Employee>> streamEmployees();
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
    bool? faceEnrolled,
    String? faceModel,
    String? faceModelVersion,
  });
  Future<void> toggleEmployeeStatus(String id, bool isActive);
  Future<void> deleteEmployee(String id);
  Future<void> deleteAllEmployees();
}

/// Cloud Firestore implementation of [EmployeeRemoteDataSource].
class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  EmployeeRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.employeesCollection);

  @override
  Stream<List<Employee>> streamEmployees() {
    return _collection.snapshots().map((snapshot) {
      final employees = snapshot.docs
          .map((doc) => Employee.fromMap(doc.data(), docId: doc.id))
          .toList();

      // Sort alphabetically by name
      employees.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return employees;
    });
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
    bool faceEnrolled = false,
    String? faceModel,
    String? faceModelVersion,
  }) async {
    try {
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        throw const ServerException(
          userMessage: 'Employee name cannot be empty',
          technicalMessage: 'Validation failed: empty employee name',
        );
      }

      final docRef = _collection.doc();
      final now = DateTime.now().toIso8601String();
      await docRef.set({
        'id': docRef.id,
        'name': cleanName,
        'email': email.trim(),
        'phone': phone.trim(),
        'role': role.trim().isEmpty ? 'Member' : role.trim(),
        'designation': designation.trim(),
        'isActive': isActive,
        'adminId': adminId,
        'faceEnrolled': faceEnrolled,
        'faceModel': ?faceModel,
        'faceModelVersion': ?faceModelVersion,
        'photoUrl': ?photoUrl,
        'faceEmbedding': ?faceEmbedding,
        'createdAt': now,
        'updatedAt': now,
      });

      AppLogger.info('Employee added: $cleanName (${docRef.id})', tag: 'EmployeeRemoteDataSource');
    } on AppException {
      rethrow;
    } on FirebaseException catch (e, st) {
      AppLogger.error('Firestore error adding employee: ${e.message}', error: e, stackTrace: st, tag: 'EmployeeRemoteDataSource');
      throw ServerException(technicalMessage: 'Failed to add employee: ${e.message}', originalError: e, stackTrace: st);
    }
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
    bool? faceEnrolled,
    String? faceModel,
    String? faceModelVersion,
  }) async {
    try {
      final cleanName = name.trim();
      if (cleanName.isEmpty) {
        throw const ServerException(
          userMessage: 'Employee name cannot be empty',
          technicalMessage: 'Validation failed: empty employee name',
        );
      }

      final data = <String, dynamic>{
        'name': cleanName,
        'email': email.trim(),
        'phone': phone.trim(),
        'role': role.trim().isEmpty ? 'Member' : role.trim(),
        'designation': designation.trim(),
        'isActive': isActive,
        'updatedAt': DateTime.now().toIso8601String(),
      };
      if (adminId != null) {
        data['adminId'] = adminId;
      }
      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }
      if (faceEmbedding != null) {
        data['faceEmbedding'] = faceEmbedding;
      }
      if (faceEnrolled != null) {
        data['faceEnrolled'] = faceEnrolled;
      }
      if (faceModel != null) {
        data['faceModel'] = faceModel;
      }
      if (faceModelVersion != null) {
        data['faceModelVersion'] = faceModelVersion;
      }

      await _collection.doc(id).update(data);

      AppLogger.info('Employee updated: $cleanName ($id)', tag: 'EmployeeRemoteDataSource');
    } on AppException {
      rethrow;
    } on FirebaseException catch (e, st) {
      AppLogger.error('Firestore error updating employee: ${e.message}', error: e, stackTrace: st, tag: 'EmployeeRemoteDataSource');
      throw ServerException(technicalMessage: 'Failed to update employee: ${e.message}', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<void> toggleEmployeeStatus(String id, bool isActive) async {
    try {
      await _collection.doc(id).update({
        'isActive': isActive,
        'updatedAt': DateTime.now().toIso8601String(),
      });
      AppLogger.info('Employee status toggled: $id -> $isActive', tag: 'EmployeeRemoteDataSource');
    } on FirebaseException catch (e, st) {
      AppLogger.error('Firestore error toggling employee status: ${e.message}', error: e, stackTrace: st, tag: 'EmployeeRemoteDataSource');
      throw ServerException(technicalMessage: 'Failed to toggle status: ${e.message}', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<void> deleteEmployee(String id) async {
    try {
      await _collection.doc(id).delete();
      AppLogger.info('Employee deleted: $id', tag: 'EmployeeRemoteDataSource');
    } on FirebaseException catch (e, st) {
      AppLogger.error('Firestore error deleting employee: ${e.message}', error: e, stackTrace: st, tag: 'EmployeeRemoteDataSource');
      throw ServerException(technicalMessage: 'Failed to delete employee: ${e.message}', originalError: e, stackTrace: st);
    }
  }

  @override
  Future<void> deleteAllEmployees() async {
    try {
      final snapshot = await _collection.get();
      if (snapshot.docs.isEmpty) return;

      const chunkSize = 450;
      final docs = snapshot.docs;
      for (var i = 0; i < docs.length; i += chunkSize) {
        final batch = _firestore.batch();
        final end = (i + chunkSize < docs.length) ? i + chunkSize : docs.length;
        for (var j = i; j < end; j++) {
          batch.delete(docs[j].reference);
        }
        await batch.commit();
      }
      AppLogger.info('Deleted all ${snapshot.docs.length} employees', tag: 'EmployeeRemoteDataSource');
    } on FirebaseException catch (e, st) {
      AppLogger.error('Firestore error deleting all employees: ${e.message}', error: e, stackTrace: st, tag: 'EmployeeRemoteDataSource');
      throw ServerException(technicalMessage: 'Failed to delete all employees: ${e.message}', originalError: e, stackTrace: st);
    }
  }
}
