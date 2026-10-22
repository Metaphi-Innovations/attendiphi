import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_remote_data_source.dart';
import 'package:qr_checkin/features/admin/data/datasources/email_credentials_service.dart';
import 'package:qr_checkin/features/admin/data/repositories/admin_repository.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';

class _FakeRemote implements AdminRemoteDataSource {
  AdminUser? lastCreated;

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
    lastCreated = AdminUser(
      id: id,
      uid: id,
      name: name,
      email: email,
      phone: phone,
      role: AdminRole.admin,
      createdBy: createdBy,
    );
    return lastCreated!;
  }

  @override
  Future<void> deleteAdmin(String adminId, {String? email}) =>
      throw UnimplementedError();

  @override
  Future<AdminUser?> getAdminByEmail(String email) async => null;

  @override
  Future<AdminUser?> getAdminById(String id) async => null;

  @override
  Future<List<AdminUser>> getAdmins({String? createdBy}) async => [];

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) =>
      throw UnimplementedError();

  @override
  Future<void> updateAdmin(AdminUser admin) => throw UnimplementedError();

  @override
  Stream<List<AdminUser>> watchAdmins({String? createdBy}) =>
      const Stream.empty();
}

class _FakeEmailService extends EmailCredentialsService {
  _FakeEmailService()
      : super(
          sendFn:
              ({required admin, required password, required portalUrl}) async {
                fail('create must not email');
              },
        );

  @override
  Future<({bool success, String userMessage, String authUserId})>
  provisionAuthAdmin({
    required String email,
    required String password,
    String? adminId,
  }) async {
    return (
      success: true,
      userMessage: '',
      authUserId: '11111111-1111-4111-8111-111111111111',
    );
  }
}

void main() {
  test(
    'createAdmin cannot persist a Super Admin role from the client',
    () async {
      final remote = _FakeRemote();
      final repo = AdminRepositoryImpl(
        remoteDataSource: remote,
        emailService: _FakeEmailService(),
      );

      final admin = await repo.createAdmin(
        name: 'Attempted Super',
        email: 'admin@example.com',
        phone: '9876543210',
        password: 'TempPass1!',
        role: AdminRole.superAdmin,
        createdBy: 'uid-creator',
      );

      expect(admin.role, AdminRole.admin);
      expect(admin.isSuperAdmin, isFalse);
      expect(remote.lastCreated?.role, AdminRole.admin);
    },
  );
}
