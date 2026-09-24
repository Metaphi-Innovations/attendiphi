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
  Future<Employee?> getEmployee(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    try {
      final snap = await _collection.doc(trimmed).get(
        const GetOptions(source: Source.server),
      );
      if (!snap.exists || snap.data() == null) return null;
      return Employee.fromMap(snap.data()!, docId: snap.id);
    } on FirebaseException {
      final snap = await _collection.doc(trimmed).get();
      if (!snap.exists || snap.data() == null) return null;
      return Employee.fromMap(snap.data()!, docId: snap.id);
    }
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
        'faceEmbedding': faceEmbedding != null
            ? Employee.firestoreVector(faceEmbedding)
            : (faceTemplates != null && faceTemplates.isNotEmpty
                ? Employee.firestoreVector(faceTemplates.first)
                : null),
        'faceTemplates': faceTemplates != null
            ? Employee.faceTemplatesToFirestore(faceTemplates)
            : null,
        'faceRegistered': faceEnrolled,
        if (faceEnrolled) 'faceRegisteredAt': now,
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
    List<List<double>>? faceTemplates,
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

      String previousName = cleanName;
      String previousPhone = phone.trim();
      try {
        final existing = await _collection.doc(id).get();
        final existingData = existing.data();
        if (existingData != null) {
          previousName = existingData['name']?.toString() ?? previousName;
          previousPhone = existingData['phone']?.toString() ?? previousPhone;
        }
      } catch (_) {}

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
        data['faceEmbedding'] = Employee.firestoreVector(faceEmbedding);
      } else if (faceTemplates != null && faceTemplates.isNotEmpty) {
        data['faceEmbedding'] = Employee.firestoreVector(faceTemplates.first);
      }
      if (faceTemplates != null) {
        data['faceTemplates'] = Employee.faceTemplatesToFirestore(faceTemplates);
        data['faceDescriptors'] = FieldValue.delete();
      }
      if (faceEnrolled != null) {
        data['faceEnrolled'] = faceEnrolled;
        data['faceRegistered'] = faceEnrolled;
        if (faceEnrolled) {
          data['faceRegisteredAt'] = DateTime.now().toIso8601String();
        }
      }
      if (faceModel != null) {
        data['faceModel'] = faceModel;
      }
      if (faceModelVersion != null) {
        data['faceModelVersion'] = faceModelVersion;
      }

      await _collection.doc(id).update(data);
      await _syncDenormalizedCheckInIdentity(
        employeeId: id,
        oldName: previousName,
        newName: cleanName,
        oldPhone: previousPhone,
        newPhone: phone.trim(),
      );

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

  Future<void> _syncDenormalizedCheckInIdentity({
    required String employeeId,
    required String oldName,
    required String newName,
    required String oldPhone,
    required String newPhone,
  }) async {
    final nameChanged = oldName.trim() != newName.trim();
    final phoneChanged = oldPhone.trim() != newPhone.trim();
    if (!nameChanged && !phoneChanged) return;

    try {
      final checkIns = _firestore.collection(AppConstants.checkInsCollection);
      final docs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final seen = <String>{};

      Future<void> collect(Query<Map<String, dynamic>> query) async {
        final snap = await query.get();
        for (final doc in snap.docs) {
          if (seen.add(doc.id)) docs.add(doc);
        }
      }

      await collect(checkIns.where('memberId', isEqualTo: employeeId));
      if (oldName.trim().isNotEmpty) {
        await collect(checkIns.where('userName', isEqualTo: oldName.trim()));
        await collect(
          checkIns.where('substituteForMember', isEqualTo: oldName.trim()),
        );
        await collect(
          checkIns.where('invitedByMember', isEqualTo: oldName.trim()),
        );
      }

      if (docs.isEmpty) return;

      const chunkSize = 450;
      for (var i = 0; i < docs.length; i += chunkSize) {
        final batch = _firestore.batch();
        final end = (i + chunkSize < docs.length) ? i + chunkSize : docs.length;
        for (var j = i; j < end; j++) {
          final data = docs[j].data();
          final updates = <String, dynamic>{};
          if (data['memberId']?.toString() == employeeId) {
            if (nameChanged) updates['userName'] = newName.trim();
            if (phoneChanged) updates['userPhone'] = newPhone.trim();
          } else if ((data['userName']?.toString() ?? '').trim() ==
              oldName.trim()) {
            if (nameChanged) updates['userName'] = newName.trim();
            if (phoneChanged) updates['userPhone'] = newPhone.trim();
          }
          if (nameChanged &&
              (data['substituteForMember']?.toString() ?? '').trim() ==
                  oldName.trim()) {
            updates['substituteForMember'] = newName.trim();
          }
          if (nameChanged &&
              (data['invitedByMember']?.toString() ?? '').trim() ==
                  oldName.trim()) {
            updates['invitedByMember'] = newName.trim();
          }
          if (updates.isNotEmpty) {
            batch.update(docs[j].reference, updates);
          }
        }
        await batch.commit();
      }
      AppLogger.info(
        'Synced check-in identity fields for employee $employeeId',
        tag: 'EmployeeRemoteDataSource',
      );
    } catch (e, st) {
      AppLogger.warning(
        'Failed to sync denormalized check-in identity for $employeeId: $e\n$st',
        tag: 'EmployeeRemoteDataSource',
      );
    }
  }
}
