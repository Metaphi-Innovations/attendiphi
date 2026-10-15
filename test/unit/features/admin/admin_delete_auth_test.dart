import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_remote_data_source.dart';
import 'package:qr_checkin/features/admin/data/datasources/email_credentials_service.dart';
import 'package:qr_checkin/features/admin/data/repositories/admin_repository.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';

class FakeRemoteDataSource implements AdminRemoteDataSource {
  String? deletedId;

  @override
  Future<void> deleteAdmin(String adminId) async {
    deletedId = adminId;
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
  }) => throw UnimplementedError();

  @override
  Future<AdminUser?> getAdminByEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<AdminUser?> getAdminById(String id) => throw UnimplementedError();

  @override
  Future<List<AdminUser>> getAdmins({String? createdBy}) =>
      throw UnimplementedError();

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) =>
      throw UnimplementedError();

  @override
  Future<void> updateAdmin(AdminUser admin) => throw UnimplementedError();

  @override
  Stream<List<AdminUser>> watchAdmins({String? createdBy}) =>
      throw UnimplementedError();
}

class FakeEmailCredentialsService extends EmailCredentialsService {
  FakeEmailCredentialsService({required this.authDeleteResult});

  final ({bool success, String userMessage}) authDeleteResult;
  String? capturedUid;
  String? capturedEmail;

  @override
  Future<({bool success, String userMessage})> deleteAuthAdmin({
    required String uid,
    String? email,
  }) async {
    capturedUid = uid;
    capturedEmail = email;
    return authDeleteResult;
  }
}

void main() {
  test(
    'deleteAdmin deletes both Auth user and Postgres row when successful',
    () async {
      final fakeRemote = FakeRemoteDataSource();
      final fakeEmailService = FakeEmailCredentialsService(
        authDeleteResult: (success: true, userMessage: 'Deleted from Auth'),
      );

      final repo = AdminRepositoryImpl(
        remoteDataSource: fakeRemote,
        emailService: fakeEmailService,
      );

      await repo.deleteAdmin(
        'legacy-profile-id',
        email: 'admin@test.com',
        authUserId: '11111111-1111-4111-8111-111111111111',
      );

      expect(
        fakeEmailService.capturedUid,
        '11111111-1111-4111-8111-111111111111',
      );
      expect(fakeEmailService.capturedEmail, 'admin@test.com');
      expect(fakeRemote.deletedId, 'legacy-profile-id');
    },
  );

  test(
    'deleteAdmin aborts and does not delete Postgres if Auth deletion fails',
    () async {
      final fakeRemote = FakeRemoteDataSource();
      final fakeEmailService = FakeEmailCredentialsService(
        authDeleteResult: (
          success: false,
          userMessage: 'Permission denied in Supabase Auth',
        ),
      );

      final repo = AdminRepositoryImpl(
        remoteDataSource: fakeRemote,
        emailService: fakeEmailService,
      );

      expect(
        () => repo.deleteAdmin(
          'legacy-profile-id',
          email: 'admin@test.com',
          authUserId: '11111111-1111-4111-8111-111111111111',
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Permission denied in Supabase Auth'),
          ),
        ),
      );

      expect(fakeRemote.deletedId, isNull);
    },
  );
}
