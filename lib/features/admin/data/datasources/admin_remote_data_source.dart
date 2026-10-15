import '../../domain/entities/admin_user.dart';

/// Contract for admin profile persistence (Supabase implementation:
/// `SupabaseAdminRemoteDataSource`).

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
