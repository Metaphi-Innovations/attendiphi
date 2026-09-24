import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_auth_email.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_remote_data_source.dart';
import 'package:qr_checkin/features/admin/data/datasources/email_credentials_service.dart';
import 'package:qr_checkin/features/admin/data/repositories/admin_repository.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';

class _RecordingRemote implements AdminRemoteDataSource {
  AdminUser? created;
  Map<String, dynamic>? lastCreateFields;
  AdminUser? existingByEmail;
  AdminUser? existingById;
  bool throwOnCreate = false;

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
    if (throwOnCreate) throw Exception('firestore write failed');
    created = AdminUser(
      id: id,
      uid: id,
      name: name,
      email: email,
      phone: phone,
      role: AdminRole.admin,
      createdBy: createdBy,
      passwordHash: '',
      passwordSalt: '',
      plainPassword: '',
    );
    lastCreateFields = {
      'id': id,
      'password': password,
      'passwordHash': created!.passwordHash,
      'plainPassword': created!.plainPassword,
    };
    return created!;
  }

  @override
  Future<void> deleteAdmin(String adminId) => throw UnimplementedError();

  @override
  Future<AdminUser?> getAdminByEmail(String email) async =>
      existingByEmail?.email == email.trim().toLowerCase()
          ? existingByEmail
          : null;

  @override
  Future<AdminUser?> getAdminById(String id) async =>
      existingById?.id == id ? existingById : null;

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
  test('HTTP provision uses signUp only and never signInWithPassword', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        '{"localId":"uid-http-1","idToken":"t","email":"a@example.com"}',
        200,
      );
    });

    final uid = await AdminAuthEmailClient.provisionAuthUser(
      'a@example.com',
      password: 'TempPass1!',
      httpClient: client,
      apiKey: 'fake-key',
    );

    expect(uid, 'uid-http-1');
    expect(paths, ['/v1/accounts:signUp']);
    expect(paths.any((p) => p.contains('signInWithPassword')), isFalse);
  });

  test('HTTP provision throws email-already-in-use without signing in', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        '{"error":{"message":"EMAIL_EXISTS"}}',
        400,
      );
    });

    await expectLater(
      () => AdminAuthEmailClient.provisionAuthUser(
        'exists@example.com',
        password: 'TempPass1!',
        httpClient: client,
        apiKey: 'fake-key',
      ),
      throwsA(
        isA<FirebaseAuthException>().having(
          (e) => e.code,
          'code',
          'email-already-in-use',
        ),
      ),
    );
    expect(paths, ['/v1/accounts:signUp']);
    expect(paths.any((p) => p.contains('signInWithPassword')), isFalse);
  });

  test('createAdmin stores Firestore doc at Auth UID without password fields',
      () async {
    final remote = _RecordingRemote();
    final repo = AdminRepositoryImpl(
      remoteDataSource: remote,
      emailService: EmailCredentialsService(
        sendFn: ({
          required admin,
          required password,
          required portalUrl,
        }) async {
          fail('create must not email');
        },
      ),
      provisionAuthUserFn: (email, {password}) async => 'uid-created-1',
    );

    final admin = await repo.createAdmin(
      name: 'New Admin',
      email: 'new@example.com',
      phone: '9876543210',
      password: 'TempPass1!',
      createdBy: 'uid-super',
    );

    expect(admin.id, 'uid-created-1');
    expect(admin.uid, 'uid-created-1');
    expect(admin.passwordHash, isEmpty);
    expect(admin.plainPassword, isEmpty);
    expect(remote.lastCreateFields?['id'], 'uid-created-1');
  });

  test('existing Firestore admin email is rejected without provisioning',
      () async {
    final remote = _RecordingRemote()
      ..existingByEmail = const AdminUser(
        id: 'uid-old',
        name: 'Old',
        email: 'dup@example.com',
        phone: '9876543210',
      );
    var provisionCalls = 0;
    final repo = AdminRepositoryImpl(
      remoteDataSource: remote,
      emailService: EmailCredentialsService(
        sendFn: ({
          required admin,
          required password,
          required portalUrl,
        }) async {
          fail('no mail');
        },
      ),
      provisionAuthUserFn: (email, {password}) async {
        provisionCalls += 1;
        return 'should-not-run';
      },
    );

    await expectLater(
      () => repo.createAdmin(
        name: 'Dup',
        email: 'dup@example.com',
        phone: '9876543210',
        password: 'TempPass1!',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('already exists'),
        ),
      ),
    );
    expect(provisionCalls, 0);
    expect(remote.created, isNull);
  });

  test('orphaned Auth user is not auto-granted an Admin profile', () async {
    final remote = _RecordingRemote();
    final repo = AdminRepositoryImpl(
      remoteDataSource: remote,
      emailService: EmailCredentialsService(
        sendFn: ({
          required admin,
          required password,
          required portalUrl,
        }) async {
          fail('no mail');
        },
      ),
      provisionAuthUserFn: (email, {password}) async {
        throw FirebaseAuthException(code: 'email-already-in-use');
      },
    );

    await expectLater(
      () => repo.createAdmin(
        name: 'Orphan',
        email: 'orphan@example.com',
        phone: '9876543210',
        password: 'TempPass1!',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('orphaned'),
        ),
      ),
    );
    expect(remote.created, isNull);
  });

  test('email-already-in-use with existing admin reports duplicate', () async {
    final remote = _RecordingRemote()
      ..existingByEmail = const AdminUser(
        id: 'uid-exist',
        name: 'Exist',
        email: 'exist@example.com',
        phone: '9876543210',
      );
    final repo = AdminRepositoryImpl(
      remoteDataSource: remote,
      emailService: EmailCredentialsService(
        sendFn: ({
          required admin,
          required password,
          required portalUrl,
        }) async {
          fail('no mail');
        },
      ),
      provisionAuthUserFn: (email, {password}) async {
        throw FirebaseAuthException(code: 'email-already-in-use');
      },
    );

    await expectLater(
      () => repo.createAdmin(
        name: 'Exist',
        email: 'exist@example.com',
        phone: '9876543210',
        password: 'TempPass1!',
      ),
      throwsA(
        isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('already exists'),
        ),
      ),
    );
    expect(remote.created, isNull);
  });

  test('orphaned Auth error message points to Authentication Users cleanup',
      () async {
    final remote = _RecordingRemote();
    final repo = AdminRepositoryImpl(
      remoteDataSource: remote,
      emailService: EmailCredentialsService(
        sendFn: ({
          required admin,
          required password,
          required portalUrl,
        }) async {
          fail('no mail');
        },
      ),
      provisionAuthUserFn: (email, {password}) async {
        throw FirebaseAuthException(code: 'email-already-in-use');
      },
    );

    try {
      await repo.createAdmin(
        name: 'Orphan',
        email: 'orphan@example.com',
        phone: '9876543210',
        password: 'TempPass1!',
      );
      fail('expected throw');
    } catch (e) {
      final message = AdminAuthEmailClient.publicCreateError(e);
      expect(message, contains('Authentication → Users'));
      expect(message, contains('orphan@example.com'));
    }
  });

  test('secondary app name is used for provisioning', () {
    expect(AdminAuthEmailClient.secondaryAppName, 'attendiphiAdminProvision');
  });
}
