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
  }) =>
      throw UnimplementedError();

  @override
  Future<AdminUser?> getAdminByEmail(String email) => throw UnimplementedError();

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
  test('deleteAdmin deletes both Auth user and Firestore record when successful',
      () async {
    final fakeRemote = FakeRemoteDataSource();
    final fakeEmailService = FakeEmailCredentialsService(
      authDeleteResult: (success: true, userMessage: 'Deleted from Auth'),
    );

    final repo = AdminRepositoryImpl(
      remoteDataSource: fakeRemote,
      emailService: fakeEmailService,
    );

    await repo.deleteAdmin('test-uid-123', email: 'admin@test.com');

    expect(fakeEmailService.capturedUid, 'test-uid-123');
    expect(fakeEmailService.capturedEmail, 'admin@test.com');
    expect(fakeRemote.deletedId, 'test-uid-123');
  });

  test('deleteAdmin aborts and does not delete Firestore if Auth deletion fails',
      () async {
    final fakeRemote = FakeRemoteDataSource();
    final fakeEmailService = FakeEmailCredentialsService(
      authDeleteResult: (
        success: false,
        userMessage: 'Permission denied in Firebase Auth',
      ),
    );

    final repo = AdminRepositoryImpl(
      remoteDataSource: fakeRemote,
      emailService: fakeEmailService,
    );

    expect(
      () => repo.deleteAdmin('test-uid-123', email: 'admin@test.com'),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Permission denied in Firebase Auth'),
        ),
      ),
    );

    // Firestore record was NOT deleted
    expect(fakeRemote.deletedId, isNull);
  });
}
