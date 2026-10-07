import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/data/datasources/email_credentials_service.dart';
import 'package:qr_checkin/features/admin/data/repositories/admin_repository.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/screens/admin_management_screen.dart';

class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({this.result, this.delay});

  SendCredentialsResult? result;
  Duration? delay;
  int sendCalls = 0;

  @override
  Future<AdminUser> createAdmin({
    required String name,
    required String email,
    required String phone,
    required String password,
    String? createdBy,
    AdminRole role = AdminRole.admin,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteAdmin(String adminId, {String? email}) =>
      throw UnimplementedError();

  @override
  Future<AdminUser?> getAdminByEmail(String email) =>
      throw UnimplementedError();

  @override
  Future<List<AdminUser>> getAdmins({String? createdBy}) =>
      throw UnimplementedError();

  @override
  Future<AdminUser?> getAdminById(String id) => throw UnimplementedError();

  @override
  Future<SendCredentialsResult> sendCredentials({
    required AdminUser admin,
    required String password,
    required String senderEmail,
    required String senderPassword,
    required String idempotencyKey,
    void Function(String phase)? onProgress,
  }) async {
    sendCalls += 1;
    if (delay != null) {
      await Future<void>.delayed(delay!);
    }
    return result ??
        const SendCredentialsResult(
          success: false,
          userMessage: 'Failed to send mail. Please try again.',
        );
  }

  @override
  Future<void> toggleAdminActive(String adminId, bool isActive) =>
      throw UnimplementedError();

  @override
  Future<void> updateAdmin(AdminUser admin) => throw UnimplementedError();

  @override
  Stream<List<AdminUser>> watchAdmins({String? createdBy}) =>
      throw UnimplementedError();
}

class _FakeAuthNotifier extends AdminAuthNotifier {
  @override
  AdminAuthState build() {
    return const AdminAuthState(
      isAuthenticated: true,
      currentAdmin: AdminUser(
        id: 'adm-sender',
        name: 'Sender',
        email: 'sender@example.com',
        phone: '9876543210',
        role: AdminRole.admin,
      ),
      sessionPassword: 'SenderPass1!',
    );
  }
}

void main() {
  const admin = AdminUser(
    id: 'adm-new',
    name: 'test',
    email: 'attendiphi.metaphi@gmail.com',
    phone: '9876543213',
    role: AdminRole.admin,
  );

  Future<void> pumpDialog(
    WidgetTester tester, {
    required _FakeAdminRepository repo,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminRepositoryProvider.overrideWithValue(repo),
          adminAuthProvider.overrideWith(_FakeAuthNotifier.new),
        ],
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const AdminCredentialsMailDialog(
                          admin: admin,
                          password: 'TempPass1!',
                        ),
                      );
                    },
                    child: const Text('Open dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pump();
  }

  testWidgets('shows only Copy Credentials and Send Mail', (tester) async {
    await pumpDialog(tester, repo: _FakeAdminRepository());

    expect(find.text('Admin Created Successfully!'), findsOneWidget);
    expect(find.text('Copy Credentials'), findsOneWidget);
    expect(find.text('Send Mail'), findsOneWidget);
    expect(find.text('Done'), findsNothing);
    expect(find.text('Open in Gmail'), findsNothing);

    final copyDx = tester.getTopLeft(find.text('Copy Credentials')).dx;
    final sendDx = tester.getTopLeft(find.text('Send Mail')).dx;
    expect(copyDx, lessThan(sendDx));
  });

  testWidgets('copy credentials shows in-modal feedback and stays open',
      (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') return null;
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await pumpDialog(tester, repo: _FakeAdminRepository());
    await tester.tap(find.text('Copy Credentials'));
    await tester.pump();

    expect(find.text('✓ Credentials copied'), findsOneWidget);
    expect(find.text('Admin Created Successfully!'), findsOneWidget);
    expect(find.text('Send Mail'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('send mail shows loading then dismisses the popup',
      (tester) async {
    final repo = _FakeAdminRepository(
      result: const SendCredentialsResult(success: true),
      delay: const Duration(milliseconds: 80),
    );
    await pumpDialog(tester, repo: repo);

    await tester.tap(find.text('Send Mail'));
    await tester.pump();
    expect(find.text('Sending...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    expect(repo.sendCalls, 1);
    expect(find.text('Admin Created Successfully!'), findsNothing);
    expect(find.text('Send Mail'), findsNothing);
    expect(find.text('Open dialog'), findsOneWidget);
  });

  testWidgets('failed send keeps modal open and allows retry', (tester) async {
    final repo = _FakeAdminRepository(
      result: const SendCredentialsResult(success: false),
    );
    await pumpDialog(tester, repo: repo);

    await tester.tap(find.text('Send Mail'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Email could not be sent'), findsOneWidget);
    expect(find.textContaining('Please try again'), findsOneWidget);
    expect(find.textContaining('Email sent successfully to'), findsNothing);
    expect(find.text('Admin Created Successfully!'), findsOneWidget);
    expect(find.text('Send Mail'), findsOneWidget);

    repo.result = const SendCredentialsResult(success: true);
    await tester.tap(find.text('Send Mail'));
    await tester.pump();
    await tester.pump();
    expect(repo.sendCalls, 2);
    expect(find.text('Admin Created Successfully!'), findsNothing);
  });

  testWidgets('cannot start a second send while the first is in flight',
      (tester) async {
    final repo = _FakeAdminRepository(
      result: const SendCredentialsResult(success: true),
      delay: const Duration(milliseconds: 200),
    );
    await pumpDialog(tester, repo: repo);

    await tester.tap(find.text('Send Mail'));
    await tester.pump();
    await tester.tap(find.text('Sending...'));
    await tester.pump();
    expect(repo.sendCalls, 1);

    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Admin Created Successfully!'), findsNothing);
  });
}
