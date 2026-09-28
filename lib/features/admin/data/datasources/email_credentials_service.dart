import '../../../../app/router/app_url.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../services/attendiphi_email_service.dart';
import '../../domain/entities/admin_user.dart';

/// Outcome of a credentials email send.
class SendCredentialsResult {
  const SendCredentialsResult({
    required this.success,
    this.alreadySent = false,
    this.userMessage = '',
    this.sentFromEmail = '',
    this.gmailMessageId = '',
  });

  final bool success;
  final bool alreadySent;
  final String userMessage;
  final String sentFromEmail;
  final String gmailMessageId;
}

/// FLOW 1 — New Admin credentials via Supabase Edge Function → SMTP.
class EmailCredentialsService {
  EmailCredentialsService({
    this.auth,
    this.firestore,
    this.sendWelcomeEmailFn,
    this.emailService,
    this.sendFn,
  });

  final Object? auth;
  final Object? firestore;
  final Future<void> Function({
    required AdminUser admin,
    required String password,
    required String portalUrl,
  })? sendWelcomeEmailFn;
  final AttendiphiEmailService? emailService;
  final Future<AttendiphiEmailResult> Function({
    required AdminUser admin,
    required String password,
    required String portalUrl,
  })? sendFn;

  static const String defaultPortalUrl = '${AppUrl.productionOrigin}/';

  /// Prefer the host the Super Admin is currently using (web.app or metaphi.in).
  static String resolvePortalUrl() => '${AppUrl.portalOrigin}/';
  static const String credentialsSubject =
      'Your QR Check-in Admin Login Credentials';

  /// Deletes the admin user from Firebase Authentication.
  Future<({bool success, String userMessage})> deleteAuthAdmin({
    required String uid,
    String? email,
  }) async {
    final service = emailService ?? AttendiphiEmailService.instance;
    return service.deleteAuthAdmin(uid: uid, email: email);
  }

  static String generatePlainEmailBody({
    required String name,
    required String email,
    required String password,
    required String portalUrl,
    String roleLabel = 'Admin',
  }) {
    return '''Hello $name,

You have been granted Administrator access to the QR Check-in & Attendance Portal.

Your Login Credentials:
────────────────────────────────────
• Portal URL: $portalUrl
• Login Email (ID): $email
• Password: $password
• Access Role: $roleLabel
────────────────────────────────────

Please sign in using the Portal URL above and keep your login credentials secure.

Best regards,
Super Admin Team
''';
  }

  Future<SendCredentialsResult> sendAdminWelcomeEmail({
    required AdminUser admin,
    required String password,
    required String senderEmail,
    required String senderPassword,
    required String idempotencyKey,
    String portalUrl = defaultPortalUrl,
    void Function(String phase)? onProgress,
  }) async {
    final resolvedPortal = portalUrl.trim().isEmpty || portalUrl == defaultPortalUrl
        ? resolvePortalUrl()
        : portalUrl;
    final recipient = admin.email.trim().toLowerCase();
    if (recipient.isEmpty || !recipient.contains('@')) {
      return const SendCredentialsResult(
        success: false,
        userMessage: 'Please provide a valid recipient email address.',
      );
    }
    if (senderEmail.trim().isEmpty) {
      return const SendCredentialsResult(
        success: false,
        userMessage: 'You are not authorized to send mail.',
      );
    }

    AppLogger.info(
      'SEND MAIL START recipient: $recipient',
      tag: 'EmailCredentialsService',
    );

    try {
      onProgress?.call('sending');
      if (sendWelcomeEmailFn != null) {
        await sendWelcomeEmailFn!(
          admin: admin,
          password: password,
          portalUrl: resolvedPortal,
        );
        return const SendCredentialsResult(success: true);
      }

      final result = sendFn != null
          ? await sendFn!(
              admin: admin,
              password: password,
              portalUrl: resolvedPortal,
            )
          : await (emailService ?? AttendiphiEmailService.instance)
              .sendAdminWelcome(
              admin: admin,
              password: password,
              subject: credentialsSubject,
              portalUrl: resolvedPortal,
            );

      if (!result.success) {
        AppLogger.warning(
          'SEND MAIL FAILURE recipient: $recipient',
          tag: 'EmailCredentialsService',
        );
        return SendCredentialsResult(
          success: false,
          userMessage: result.userMessage,
        );
      }

      AppLogger.info(
        'SEND MAIL SUCCESS recipient: $recipient messageId: ${result.messageId.isEmpty ? 'none' : result.messageId}',
        tag: 'EmailCredentialsService',
      );
      return SendCredentialsResult(
        success: true,
        gmailMessageId: result.messageId,
        userMessage: result.userMessage,
      );
    } on AttendiphiEmailException catch (e) {
      AppLogger.warning(
        'SEND MAIL FAILURE recipient: $recipient code: ${e.code}',
        tag: 'EmailCredentialsService',
      );
      return SendCredentialsResult(
        success: false,
        userMessage: e.userMessage,
      );
    } catch (_) {
      AppLogger.warning(
        'SEND MAIL FAILURE recipient: $recipient',
        tag: 'EmailCredentialsService',
      );
      return const SendCredentialsResult(
        success: false,
        userMessage: 'Email could not be sent. Please try again.',
      );
    }
  }
}
