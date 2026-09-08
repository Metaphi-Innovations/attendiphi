import '../../domain/entities/admin_user.dart';
import '../datasources/admin_remote_data_source.dart';
import '../datasources/email_credentials_service.dart';

abstract class AdminRepository {
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
    bool sendEmail = true,
  });
  Future<void> updateAdmin(AdminUser admin);
  Future<void> toggleAdminActive(String adminId, bool isActive);
  Future<void> deleteAdmin(String adminId);
  Future<bool> resendCredentials(AdminUser admin, String password);
}

class AdminRepositoryImpl implements AdminRepository {
  AdminRepositoryImpl({
    required this.remoteDataSource,
    required this.emailService,
  });

  final AdminRemoteDataSource remoteDataSource;
  final EmailCredentialsService emailService;

  @override
  Stream<List<AdminUser>> watchAdmins() => remoteDataSource.watchAdmins();

  @override
  Future<List<AdminUser>> getAdmins() => remoteDataSource.getAdmins();

  @override
  Future<AdminUser?> getAdminByEmail(String email) =>
      remoteDataSource.getAdminByEmail(email);

  @override
  Future<AdminUser> createAdmin({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
    bool sendEmail = true,
  }) async {
    final admin = await remoteDataSource.createAdmin(
      name: name,
      email: email,
      phone: phone,
      password: password,
      createdBy: createdBy,
      role: role,
    );

    if (sendEmail) {
      await emailService.sendAdminWelcomeEmail(
        admin: admin,
        password: password,
      );
    }

    return admin;
  }

  @override
  Future<void> updateAdmin(AdminUser admin) =>
      remoteDataSource.updateAdmin(admin);

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) =>
      remoteDataSource.toggleAdminActive(adminId, isActive);

  @override
  Future<void> deleteAdmin(String adminId) =>
      remoteDataSource.deleteAdmin(adminId);

  @override
  Future<bool> resendCredentials(AdminUser admin, String password) =>
      emailService.sendAdminWelcomeEmail(
        admin: admin,
        password: password,
      );
}
