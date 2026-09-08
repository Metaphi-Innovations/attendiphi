import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/entities/admin_user.dart';

abstract class AdminRemoteDataSource {
  Stream<List<AdminUser>> watchAdmins();
  Future<List<AdminUser>> getAdmins();
  Future<AdminUser?> getAdminByEmail(String email);
  Future<AdminUser> createAdmin({
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
  Stream<List<AdminUser>> watchAdmins() {
    return _adminsCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map(AdminUser.fromFirestore).toList();
    });
  }

  @override
  Future<List<AdminUser>> getAdmins() async {
    final snapshot = await _adminsCollection
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map(AdminUser.fromFirestore).toList();
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
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // Check if email already exists
    final existing = await getAdminByEmail(cleanEmail);
    if (existing != null) {
      throw Exception('An admin with email "$cleanEmail" already exists.');
    }

    final docRef = _adminsCollection.doc();
    final newAdmin = AdminUser(
      id: docRef.id,
      name: name.trim(),
      email: cleanEmail,
      phone: phone.trim(),
      role: role,
      plainPassword: password.trim(),
      passwordHash: password.trim(),
      mustResetPassword: true,
      isActive: true,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await docRef.set(newAdmin.toMap());
    return newAdmin;
  }

  @override
  Future<void> updateAdmin(AdminUser admin) async {
    await _adminsCollection.doc(admin.id).update(admin.toMap());
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
