import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/router/app_url.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_auth_email.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_password_reset_service.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_remote_data_source.dart';
import 'package:qr_checkin/features/admin/data/datasources/email_credentials_service.dart';
import 'package:qr_checkin/features/admin/data/repositories/admin_repository.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/services/attendiphi_email_service.dart';

class _FakeRemoteDataSource implements AdminRemoteDataSource {
  AdminUser? created;

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
    created = AdminUser(
      id: id,
      uid: id,
      name: name,
      email: email,
      phone: phone,
      role: AdminRole.admin,
    );
    return created!;
  }

  @override
  Future<void> deleteAdmin(String adminId) => throw UnimplementedError();

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

void main() {
  test('createAdmin provisions Auth and never sends a password-reset email',
      () async {
    var provisionCalls = 0;
    final remote = _FakeRemoteDataSource();
    final repo = AdminRepositoryImpl(
      remoteDataSource: remote,
      emailService: EmailCredentialsService(
        sendFn: ({
          required admin,
          required password,
          required portalUrl,
        }) async {
          fail('createAdmin must not send credentials mail');
        },
      ),
      provisionAuthUserFn: (email, {password}) async {
        provisionCalls += 1;
        expect(email, 'newadmin@example.com');
        expect(password, 'TempPass1!');
        return 'uid-new';
      },
    );

    final admin = await repo.createAdmin(
      name: 'New Admin',
      email: 'newadmin@example.com',
      phone: '9876543210',
      password: 'TempPass1!',
    );

    expect(admin.email, 'newadmin@example.com');
    expect(admin.id, 'uid-new');
    expect(admin.role, AdminRole.admin);
    expect(provisionCalls, 1);
  });

  test('sendCredentials sends via Attendiphi email service', () async {
    var sent = false;
    final repo = AdminRepositoryImpl(
      remoteDataSource: _FakeRemoteDataSource(),
      emailService: EmailCredentialsService(
        sendFn: ({
          required admin,
          required password,
          required portalUrl,
        }) async {
          sent = true;
          expect(admin.email, 'newadmin@example.com');
          expect(password, 'TempPass1!');
          return const AttendiphiEmailResult(
            success: true,
            messageId: 'msg-22',
          );
        },
      ),
      provisionAuthUserFn: (email, {password}) async {
        fail('sendCredentials must not provision Auth');
      },
    );

    final result = await repo.sendCredentials(
      admin: const AdminUser(
        id: 'adm-new',
        name: 'New Admin',
        email: 'newadmin@example.com',
        phone: '9876543210',
      ),
      password: 'TempPass1!',
      senderEmail: 'super@example.com',
      senderPassword: 'x',
      idempotencyKey: 'k1',
    );

    expect(result.success, isTrue);
    expect(sent, isTrue);
    expect(result.gmailMessageId, 'msg-22');
  });

  test('forgot password request can use an injected email sender', () async {
    final resetEmails = <String>[];
    final service = AdminPasswordResetService(
      sendPasswordResetEmailFn: (email) async {
        resetEmails.add(email);
      },
    );

    final result = await service.requestReset(email: 'existing@example.com');

    expect(result.accepted, isTrue);
    expect(resetEmails, ['existing@example.com']);
  });

  test('Attendiphi reset landing URL is the branded admin-reset-password page',
      () {
    const firebaseLink =
        'https://qr-checkin-dev.firebaseapp.com/__/auth/action?mode=resetPassword&oobCode=abc&apiKey=public';
    final body = AppUrl.flutterResetUrlFromFirebaseOobLink(firebaseLink);
    expect(body.contains('/admin-reset-password'), isTrue);
    expect(body.contains('oobCode=abc'), isTrue);
    expect(body.contains('/__/auth/action'), isFalse);
  });

  test('new admin Auth provision uses a secondary app name', () {
    expect(
      AdminAuthEmailClient.secondaryAppName,
      'attendiphiAdminProvision',
    );
  });
}
