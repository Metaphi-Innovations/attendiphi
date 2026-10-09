import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/employee.dart';
import '../../domain/public_member_projection.dart';

/// Contract for remote operations on the Employee / User collection.
abstract class EmployeeRemoteDataSource {
  Stream<List<Employee>> streamEmployees();
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

/// Cloud Firestore implementation of [EmployeeRemoteDataSource].
class EmployeeRemoteDataSourceImpl implements EmployeeRemoteDataSource {
  EmployeeRemoteDataSourceImpl(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(AppConstants.employeesCollection);

  CollectionReference<Map<String, dynamic>> get _publicMembers =>
      _firestore.collection(AppConstants.publicMembersCollection);

  CollectionReference<Map<String, dynamic>> get _faceTemplates =>
      _firestore.collection(AppConstants.faceTemplatesCollection);

  /// Queues public QR projection on [batch] (same commit as employee write).
  /// Active → upsert; inactive → delete so anonymous clients cannot read it.
  void _queuePublicMember(
    WriteBatch batch, {
    required String id,
    required String name,
    required String phone,
    required bool isActive,
    DateTime? updatedAt,
  }) {
    final ref = _publicMembers.doc(id);
    switch (PublicMemberProjection.actionFor(isActive: isActive)) {
      case PublicMemberProjectionAction.remove:
        batch.delete(ref);
      case PublicMemberProjectionAction.upsert:
        batch.set(
          ref,
          PublicMemberProjection.toMap(
            id: id,
            name: name,
            phone: phone,
            updatedAt: updatedAt,
          ),
          SetOptions(merge: true),
        );
    }
  }

  /// Writes biometrics to locked [faceTemplates]; never on public employees.
  /// When [batch] is provided, the write is queued (caller must commit).
  Future<void> _upsertFaceTemplates({
    required String memberId,
    List<double>? faceEmbedding,
    List<List<double>>? faceTemplates,
    String? faceModel,
    String? faceModelVersion,
    WriteBatch? batch,
  }) async {
    if (faceEmbedding == null &&
        (faceTemplates == null || faceTemplates.isEmpty)) {
      return;
    }
    final embedding =
        faceEmbedding ??
        (faceTemplates != null && faceTemplates.isNotEmpty
            ? faceTemplates.first
            : null);
    final payload = <String, dynamic>{
      'memberId': memberId,
      if (embedding != null)
        'faceEmbedding': Employee.firestoreVector(embedding),
      if (faceTemplates != null)
        'faceTemplates': Employee.faceTemplatesToFirestore(faceTemplates),
      'faceModel': ?faceModel,
      'faceModelVersion': ?faceModelVersion,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (batch != null) {
      batch.set(_faceTemplates.doc(memberId), payload, SetOptions(merge: true));
      return;
    }
    await _faceTemplates.doc(memberId).set(payload, SetOptions(merge: true));
  }

  /// Public employee maps must not expose biometrics to QR clients.
  Map<String, dynamic> _publicEmployeeMap(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);
    data.remove('faceEmbedding');
    data.remove('faceTemplates');
    data.remove('faceDescriptors');
    return data;
  }

  Future<Employee> _employeeWithOptionalTemplates(
    Map<String, dynamic> publicData, {
    required String docId,
  }) async {
    var employee = Employee.fromMap(publicData, docId: docId);
    try {
      final tpl = await _faceTemplates.doc(docId).get();
      if (tpl.exists && tpl.data() != null) {
        final merged = {...publicData, ...tpl.data()!, 'id': docId};
        employee = Employee.fromMap(merged, docId: docId);
      }
    } catch (_) {
      // Unauthenticated / non-admin readers cannot load faceTemplates.
    }
    return employee;
  }

  @override
  Stream<List<Employee>> streamEmployees() {
    return _collection.snapshots().map((snapshot) {
      final employees = snapshot.docs
          .map(
            (doc) =>
                Employee.fromMap(_publicEmployeeMap(doc.data()), docId: doc.id),
          )
          .toList();

      // Sort alphabetically by name
      employees.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return employees;
    });
  }

  @override
  Stream<List<Employee>> streamPublicMembers() {
    // Rules require isActive==true; query must match. Inactive docs are
    // deleted on deactivate and cleaned by backfill — not publicly listed.
    return _publicMembers.where('isActive', isEqualTo: true).snapshots().map((
      snapshot,
    ) {
      final members = snapshot.docs
          .map(
            (doc) => Employee.fromMap({
              'name': doc.data()['name'],
              'phone': doc.data()['phone'],
              'isActive': true,
            }, docId: doc.id),
          )
          .toList();
      members.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      return members;
    });
  }

  @override
  Future<Employee?> getEmployee(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    try {
      final snap = await _collection
          .doc(trimmed)
          .get(const GetOptions(source: Source.server));
      if (!snap.exists || snap.data() == null) return null;
      return await _employeeWithOptionalTemplates(
        _publicEmployeeMap(snap.data()!),
        docId: snap.id,
      );
    } on FirebaseException {
      final snap = await _collection.doc(trimmed).get();
      if (!snap.exists || snap.data() == null) return null;
      return await _employeeWithOptionalTemplates(
        _publicEmployeeMap(snap.data()!),
        docId: snap.id,
      );
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
      final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
      final phoneDigits =
          (cleanPhone.startsWith('91') && cleanPhone.length == 12)
          ? cleanPhone.substring(2)
          : cleanPhone;
      if (phoneDigits.length != 10) {
        throw const ServerException(
          userMessage: 'Please enter a valid 10-digit phone number',
          technicalMessage:
              'Validation failed: empty or invalid employee phone',
        );
      }

      final docRef = _collection.doc();
      final nowDt = DateTime.now();
      final now = nowDt.toIso8601String();
      final batch = _firestore.batch();
      batch.set(docRef, {
        'id': docRef.id,
        'name': cleanName,
        'email': email.trim(),
        'phone': phoneDigits,
        'role': role.trim().isEmpty ? 'Member' : role.trim(),
        'designation': designation.trim(),
        'isActive': isActive,
        'adminId': adminId,
        'faceEnrolled': faceEnrolled,
        'faceModel': ?faceModel,
        'faceModelVersion': ?faceModelVersion,
        'photoUrl': ?photoUrl,
        'faceRegistered': faceEnrolled,
        if (faceEnrolled) 'faceRegisteredAt': now,
        'createdAt': now,
        'updatedAt': now,
      });
      _queuePublicMember(
        batch,
        id: docRef.id,
        name: cleanName,
        phone: phoneDigits,
        isActive: isActive,
        updatedAt: nowDt,
      );
      await _upsertFaceTemplates(
        memberId: docRef.id,
        faceEmbedding: faceEmbedding,
        faceTemplates: faceTemplates,
        faceModel: faceModel,
        faceModelVersion: faceModelVersion,
        batch: batch,
      );
      await batch.commit();

      AppLogger.info(
        'Employee added: $cleanName (${docRef.id})',
        tag: 'EmployeeRemoteDataSource',
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error adding employee: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'EmployeeRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to add employee: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
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
      final cleanPhone = phone.trim().replaceAll(RegExp(r'\D'), '');
      final phoneDigits =
          (cleanPhone.startsWith('91') && cleanPhone.length == 12)
          ? cleanPhone.substring(2)
          : cleanPhone;
      if (phoneDigits.length != 10) {
        throw const ServerException(
          userMessage: 'Please enter a valid 10-digit phone number',
          technicalMessage:
              'Validation failed: empty or invalid employee phone',
        );
      }

      String previousName = cleanName;
      String previousPhone = phoneDigits;
      try {
        final existing = await _collection.doc(id).get();
        final existingData = existing.data();
        if (existingData != null) {
          previousName = existingData['name']?.toString() ?? previousName;
          previousPhone = existingData['phone']?.toString() ?? previousPhone;
        }
      } catch (_) {}

      final nowDt = DateTime.now();
      final data = <String, dynamic>{
        'name': cleanName,
        'email': email.trim(),
        'phone': phoneDigits,
        'role': role.trim().isEmpty ? 'Member' : role.trim(),
        'designation': designation.trim(),
        'isActive': isActive,
        'updatedAt': nowDt.toIso8601String(),
      };
      if (adminId != null) {
        data['adminId'] = adminId;
      }
      if (photoUrl != null) {
        data['photoUrl'] = photoUrl;
      }
      // Strip biometrics from public employees (migrate to faceTemplates).
      data['faceEmbedding'] = FieldValue.delete();
      data['faceTemplates'] = FieldValue.delete();
      data['faceDescriptors'] = FieldValue.delete();
      if (faceEnrolled != null) {
        data['faceEnrolled'] = faceEnrolled;
        data['faceRegistered'] = faceEnrolled;
        if (faceEnrolled) {
          data['faceRegisteredAt'] = nowDt.toIso8601String();
        }
      }
      if (faceModel != null) {
        data['faceModel'] = faceModel;
      }
      if (faceModelVersion != null) {
        data['faceModelVersion'] = faceModelVersion;
      }

      final batch = _firestore.batch();
      batch.update(_collection.doc(id), data);
      _queuePublicMember(
        batch,
        id: id,
        name: cleanName,
        phone: phoneDigits,
        isActive: isActive,
        updatedAt: nowDt,
      );
      await _upsertFaceTemplates(
        memberId: id,
        faceEmbedding: faceEmbedding,
        faceTemplates: faceTemplates,
        faceModel: faceModel,
        faceModelVersion: faceModelVersion,
        batch: batch,
      );
      await batch.commit();
      // Best-effort historical check-in identity rewrite (separate from roster).
      await _syncDenormalizedCheckInIdentity(
        employeeId: id,
        oldName: previousName,
        newName: cleanName,
        oldPhone: previousPhone,
        newPhone: phone.trim(),
      );

      AppLogger.info(
        'Employee updated: $cleanName ($id)',
        tag: 'EmployeeRemoteDataSource',
      );
    } on AppException {
      rethrow;
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error updating employee: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'EmployeeRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to update employee: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> toggleEmployeeStatus(String id, bool isActive) async {
    try {
      final snap = await _collection.doc(id).get();
      final data = snap.data() ?? {};
      final nowDt = DateTime.now();
      final batch = _firestore.batch();
      batch.update(_collection.doc(id), {
        'isActive': isActive,
        'updatedAt': nowDt.toIso8601String(),
      });
      _queuePublicMember(
        batch,
        id: id,
        name: (data['name'] as String?) ?? '',
        phone: (data['phone'] as String?) ?? '',
        isActive: isActive,
        updatedAt: nowDt,
      );
      await batch.commit();
      AppLogger.info(
        'Employee status toggled: $id -> $isActive',
        tag: 'EmployeeRemoteDataSource',
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error toggling employee status: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'EmployeeRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to toggle status: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
    }
  }

  @override
  Future<void> deleteEmployee(String id) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_collection.doc(id));
      batch.delete(_faceTemplates.doc(id));
      batch.delete(_publicMembers.doc(id));
      await batch.commit();
      AppLogger.info('Employee deleted: $id', tag: 'EmployeeRemoteDataSource');
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error deleting employee: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'EmployeeRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to delete employee: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
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
          final id = docs[j].id;
          batch.delete(docs[j].reference);
          batch.delete(_publicMembers.doc(id));
          batch.delete(_faceTemplates.doc(id));
        }
        await batch.commit();
      }
      AppLogger.info(
        'Deleted all ${snapshot.docs.length} employees',
        tag: 'EmployeeRemoteDataSource',
      );
    } on FirebaseException catch (e, st) {
      AppLogger.error(
        'Firestore error deleting all employees: ${e.message}',
        error: e,
        stackTrace: st,
        tag: 'EmployeeRemoteDataSource',
      );
      throw ServerException(
        technicalMessage: 'Failed to delete all employees: ${e.message}',
        originalError: e,
        stackTrace: st,
      );
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
          final docType = (data['type']?.toString() ?? '').trim();
          final isSubstitute = docType == 'substitute';
          // Substitute docs: memberId / userName remap point at the covered
          // member, but userPhone / substitutePhone / substituteName belong to
          // the attending substitute — never overwrite those with roster edits.
          if (!isSubstitute) {
            if (data['memberId']?.toString() == employeeId) {
              if (nameChanged) updates['userName'] = newName.trim();
              if (phoneChanged) updates['userPhone'] = newPhone.trim();
            } else if ((data['userName']?.toString() ?? '').trim() ==
                oldName.trim()) {
              if (nameChanged) updates['userName'] = newName.trim();
              if (phoneChanged) updates['userPhone'] = newPhone.trim();
            }
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
