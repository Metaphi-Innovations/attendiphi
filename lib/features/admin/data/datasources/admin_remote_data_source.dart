import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/admin_user.dart';

abstract class AdminRemoteDataSource {
  Stream<List<AdminUser>> watchAdmins({String? createdBy});
  Future<List<AdminUser>> getAdmins({String? createdBy});
  Future<AdminUser?> getAdminByEmail(String email);
  Future<AdminUser?> getAdminById(String id);
  Future<AdminUser> createAdmin({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
  });
  Future<void> updateAdmin(AdminUser admin);
  Future<void> toggleAdminActive(String adminId, bool isActive);
  Future<void> deleteAdmin(String adminId);
}

class AdminRemoteDataSourceImpl implements AdminRemoteDataSource {
  AdminRemoteDataSourceImpl({required this.firestore});

  final FirebaseFirestore firestore;

  CollectionReference<Map<String, dynamic>> get _adminsCollection =>
      firestore.collection(AppConstants.adminsCollection);

  @override
  Stream<List<AdminUser>> watchAdmins({String? createdBy}) {
    Query<Map<String, dynamic>> query = _adminsCollection;
    final creator = createdBy?.trim() ?? '';
    if (creator.isNotEmpty) {
      query = query.where('createdBy', isEqualTo: creator);
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs.map(AdminUser.fromFirestore).toList();
    });
  }

  @override
  Future<List<AdminUser>> getAdmins({String? createdBy}) async {
    Query<Map<String, dynamic>> query = _adminsCollection;
    final creator = createdBy?.trim() ?? '';
    if (creator.isNotEmpty) {
      query = query.where('createdBy', isEqualTo: creator);
    }
    final snapshot = await query.get();
    return snapshot.docs.map(AdminUser.fromFirestore).toList();
  }

  @override
  Future<AdminUser?> getAdminById(String id) async {
    final trimmed = id.trim();
    if (trimmed.isEmpty) return null;
    final doc = await _adminsCollection.doc(trimmed).get();
    if (!doc.exists) return null;
    return AdminUser.fromFirestore(doc);
  }

  @override
  Future<AdminUser?> getAdminByEmail(String email) async {
    final cleanEmail = email.trim().toLowerCase();
    final snapshot = await _adminsCollection
        .where('email', isEqualTo: cleanEmail)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return AdminUser.fromFirestore(snapshot.docs.first);
  }

  @override
  Future<AdminUser> createAdmin({
    required String id,
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
  }) async {
    final _ = role;
    if (password.trim().length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
    final cleanEmail = email.trim().toLowerCase();
    final uid = id.trim();
    if (uid.isEmpty) {
      throw Exception('Admin Firebase UID is required.');
    }

    try {
      final existingDoc = await _adminsCollection.doc(uid).get();
      if (existingDoc.exists) {
        throw Exception('An Admin account already exists for this email.');
      }
    } on FirebaseException {
      // Scoped admin cannot get non-existent or other-owner doc; UID uniqueness is guaranteed by Auth.
    } catch (_) {}

    try {
      final existing = await getAdminByEmail(cleanEmail);
      if (existing != null) {
        throw Exception('An Admin account already exists for this email.');
      }
    } on FirebaseException {
      // Listing by email may be denied for scoped admins; UID uniqueness still holds.
    } catch (_) {}

    String creatorUid = (createdBy ?? '').trim();
    if (creatorUid.isEmpty) {
      try {
        creatorUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      } catch (_) {}
    }

    final finalCreatedBy = creatorUid.isNotEmpty ? creatorUid : createdBy;
    final docRef = _adminsCollection.doc(uid);
    final newAdmin = AdminUser(
      id: uid,
      uid: uid,
      name: name.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      role: AdminRole.admin,
      plainPassword: '',
      passwordHash: '',
      passwordSalt: '',
      mustResetPassword: true,
      isActive: true,
      createdAt: DateTime.now(),
      createdBy: finalCreatedBy,
    );

    // Firebase Auth stores the password. Do not persist plaintext or hashes.
    // Do not use FieldValue.delete() with set() without merge:true.
    await docRef.set({
      'uid': uid,
      'name': newAdmin.name,
      'email': newAdmin.email,
      'phone': newAdmin.phone,
      'role': AdminRole.admin.value,
      'mustResetPassword': true,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': finalCreatedBy,
      'assignedLocationIds': <String>[],
    });
    return newAdmin;
  }

  @override
  Future<void> updateAdmin(AdminUser admin) async {
    await _adminsCollection.doc(admin.id).update({
      ...admin.toMap(),
      'plainPassword': FieldValue.delete(),
    });
  }

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) async {
    await _adminsCollection.doc(adminId).update({'isActive': isActive});
  }

  @override
  Future<void> deleteAdmin(String adminId) async {
    await _adminsCollection.doc(adminId).delete();
  }
}
