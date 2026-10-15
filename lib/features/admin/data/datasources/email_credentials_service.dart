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
    this.sendWelcomeEmailFn,
    this.emailService,
    this.sendFn,
  });

  final Future<void> Function({
    required AdminUser admin,
    required String password,
    required String portalUrl,
  })?
  sendWelcomeEmailFn;
  final AttendiphiEmailService? emailService;
  final Future<AttendiphiEmailResult> Function({
    required AdminUser admin,
    required String password,
    required String portalUrl,
  })?
  sendFn;

  static const String defaultPortalUrl = '${AppUrl.productionOrigin}/';

  /// Production portal — welcome emails must not point at localhost.
  static String resolvePortalUrl() => '${AppUrl.productionOrigin}/';
  static const String credentialsSubject =
      'Attendiphi - Set up your admin login';

  /// Public logo used in HTML email headers (must be hosted, not a local path).
  static const String credentialsLogoUrl =
      'https://attendiphi.metaphi.in/email/attendiphi_logo.png';

  /// Deletes the admin user from Supabase Authentication.
  Future<({bool success, String userMessage})> deleteAuthAdmin({
    required String uid,
    String? email,
  }) async {
    final service = emailService ?? AttendiphiEmailService.instance;
    return service.deleteAuthAdmin(uid: uid, email: email);
  }

  /// Creates/updates Supabase Auth for an admin and links `auth_user_id`.
  Future<({bool success, String userMessage, String authUserId})>
  provisionAuthAdmin({
    required String email,
    required String password,
    String? adminId,
  }) async {
    final service = emailService ?? AttendiphiEmailService.instance;
    return service.provisionAuthAdmin(
      email: email,
      password: password,
      adminId: adminId,
    );
  }

  /// Plaintext template for tests / logs — never include passwords (P2 invite link).
  static String generatePlainEmailBody({
    required String name,
    required String email,
    required String password,
    required String portalUrl,
    String roleLabel = 'Admin',
    String? actionLink,
  }) {
    // [password] retained in signature for call-site compatibility; unused.
    final _ = password;
    final linkLine = (actionLink != null && actionLink.trim().isNotEmpty)
        ? 'Set your password: ${actionLink.trim()}\n'
        : 'Open the Set password button in the HTML email to choose a password.\n';
    return '''Hello $name,

You have been granted $roleLabel access to the Attendiphi QR Check-in portal.

$linkLine
Portal URL: $portalUrl
Login Email: $email
Access Role: $roleLabel

We never email passwords in plaintext.

Best regards,
Attendiphi Super Admin
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
    final resolvedPortal =
        portalUrl.trim().isEmpty || portalUrl == defaultPortalUrl
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
      return SendCredentialsResult(success: false, userMessage: e.userMessage);
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
