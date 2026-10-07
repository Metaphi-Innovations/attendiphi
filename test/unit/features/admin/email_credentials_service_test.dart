import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/data/datasources/email_credentials_service.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/services/attendiphi_email_service.dart';

void main() {
  const admin = AdminUser(
    id: 'adm-1',
    name: 'Test Admin',
    email: 'testing@gmail.com',
    phone: '9876543210',
    role: AdminRole.admin,
  );

  test('sendAdminWelcomeEmail reports success when SMTP function succeeds',
      () async {
    var sentTo = '';
    final service = EmailCredentialsService(
      sendFn: ({
        required admin,
        required password,
        required portalUrl,
      }) async {
        sentTo = admin.email;
        expect(password, 'TempPass1!');
        return const AttendiphiEmailResult(
          success: true,
          messageId: 'msg-1',
        );
      },
    );

    final result = await service.sendAdminWelcomeEmail(
      admin: admin,
      password: 'TempPass1!',
      senderEmail: 'super@example.com',
      senderPassword: 'unused',
      idempotencyKey: 'cred-adm-1-1',
    );

    expect(result.success, isTrue);
    expect(sentTo, 'testing@gmail.com');
    expect(result.gmailMessageId, 'msg-1');
  });

  test('sendAdminWelcomeEmail does not report success when send fails',
      () async {
    final service = EmailCredentialsService(
      sendFn: ({
        required admin,
        required password,
        required portalUrl,
      }) async {
        return const AttendiphiEmailResult(
          success: false,
          userMessage: 'Network error. Check your connection and try again.',
        );
      },
    );

    final result = await service.sendAdminWelcomeEmail(
      admin: admin,
      password: 'TempPass1!',
      senderEmail: 'super@example.com',
      senderPassword: 'unused',
      idempotencyKey: 'cred-adm-1-2',
    );

    expect(result.success, isFalse);
    expect(result.userMessage, contains('Network error'));
  });

  test('sendAdminWelcomeEmail rejects unauthorized callers', () async {
    final service = EmailCredentialsService(
      sendFn: ({
        required admin,
        required password,
        required portalUrl,
      }) async {
        fail('Should not send without a sender');
      },
    );

    final result = await service.sendAdminWelcomeEmail(
      admin: admin,
      password: 'TempPass1!',
      senderEmail: '',
      senderPassword: '',
      idempotencyKey: 'cred-adm-1-3',
    );

    expect(result.success, isFalse);
    expect(result.userMessage, contains('not authorized'));
  });

  test('credentials template matches admin login mail', () {
    final body = EmailCredentialsService.generatePlainEmailBody(
      name: 'Omkar Anarse',
      email: 'omkaranarse1906@gmail.com',
      password: 'Secret1!',
      portalUrl: EmailCredentialsService.defaultPortalUrl,
    );
    expect(body, contains('Hello Omkar Anarse,'));
    expect(body, contains('Your Login Credentials:'));
    expect(
      body,
      contains('Portal URL: https://attendiphi-by-metaphi.web.app/'),
    );
    expect(body, contains('Login Email id: omkaranarse1906@gmail.com'));
    expect(body, contains('Access Role: Admin'));
    expect(body, contains('Super Admin'));
    expect(body, isNot(contains('Super Admin Team')));
    expect(EmailCredentialsService.credentialsSubject,
        'Attendiphi - Your QR Check-in Admin Login Credentials');
  });
}
