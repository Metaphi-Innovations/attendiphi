import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/logger/app_logger.dart';
import '../../domain/entities/admin_user.dart';

/// Service responsible for dispatching welcome emails with credentials to newly created Admins.
class EmailCredentialsService {
  EmailCredentialsService({required this.firestore});

  final FirebaseFirestore firestore;

  static const String defaultPortalUrl =
      'https://attendiphi-by-metaphi.web.app/';

  String generatePlainEmailBody({
    required AdminUser admin,
    required String password,
    String portalUrl = defaultPortalUrl,
  }) {
    return '''
Hello ${admin.name},

You have been granted Administrator access to the QR Check-in & Attendance Portal.

Your Login Credentials:
────────────────────────────────────────
• Portal URL: $portalUrl
• Login Email (ID): ${admin.email}
• Password: $password
• Access Role: ${admin.role.label}
────────────────────────────────────────

Please sign in using the Portal URL above and keep your login credentials secure.

Best regards,
Super Admin Team
''';
  }

  String generateHtmlEmailBody({
    required AdminUser admin,
    required String password,
    String portalUrl = defaultPortalUrl,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; margin: 0; padding: 24px; color: #1e293b; }
    .container { max-width: 560px; margin: 0 auto; background: #ffffff; border-radius: 16px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 6px -1px rgba(0,0,0,0.05); }
    .header { background: #4f46e5; padding: 28px 24px; text-align: center; color: #ffffff; }
    .header h1 { margin: 0; font-size: 20px; font-weight: 700; letter-spacing: -0.5px; }
    .content { padding: 28px 24px; }
    .greeting { font-size: 16px; font-weight: 600; margin-bottom: 12px; }
    .intro { font-size: 14px; color: #475569; line-height: 1.6; margin-bottom: 20px; }
    .card { background: #f1f5f9; border-radius: 12px; padding: 18px; border: 1px solid #cbd5e1; margin-bottom: 24px; }
    .row { display: flex; justify-content: space-between; padding: 6px 0; border-bottom: 1px solid #e2e8f0; font-size: 13.5px; }
    .row:last-child { border-bottom: none; }
    .label { color: #64748b; font-weight: 600; }
    .value { font-weight: 700; color: #0f172a; font-family: monospace; }
    .cta-btn { display: block; text-align: center; background: #4f46e5; color: #ffffff !important; text-decoration: none; font-weight: 700; font-size: 14px; padding: 12px 24px; border-radius: 10px; margin: 20px 0; }
    .footer { font-size: 12px; color: #94a3b8; text-align: center; padding: 16px 24px 24px; }
  </style>
</head>
<body>
  <div class="container">
    <div class="header">
      <h1>QR Check-in & Attendance Portal</h1>
    </div>
    <div class="content">
      <div class="greeting">Hello ${admin.name},</div>
      <div class="intro">You have been designated as an <strong>${admin.role.label}</strong>. Your login credentials have been generated below:</div>
      <div class="card">
        <div class="row"><span class="label">Login Portal:</span><span class="value"><a href="$portalUrl">$portalUrl</a></span></div>
        <div class="row"><span class="label">Admin Email (ID):</span><span class="value">${admin.email}</span></div>
        <div class="row"><span class="label">Password:</span><span class="value">$password</span></div>
        <div class="row"><span class="label">Access Role:</span><span class="value">${admin.role.label}</span></div>
      </div>
      <a href="$portalUrl" class="cta-btn">Sign In to Admin Portal &rarr;</a>
      <div class="intro" style="font-size: 12.5px; color: #64748b;">
        Please keep these credentials safe and change your password upon your first sign in.
      </div>
    </div>
    <div class="footer">
      Sent securely by Super Admin Portal &bull; QR Check-in System
    </div>
  </div>
</body>
</html>
''';
  }

  /// Dispatches login credentials to the admin's email.
  Future<bool> sendAdminWelcomeEmail({
    required AdminUser admin,
    required String password,
    String portalUrl = defaultPortalUrl,
  }) async {
    try {
      const subject =
          'Welcome to QR Check-in Portal — Your Admin Login Credentials';
      final plainText = generatePlainEmailBody(
        admin: admin,
        password: password,
        portalUrl: portalUrl,
      );
      final htmlContent = generateHtmlEmailBody(
        admin: admin,
        password: password,
        portalUrl: portalUrl,
      );

      final emailPayload = {
        'to': admin.email,
        'recipientName': admin.name,
        'subject': subject,
        'portalUrl': portalUrl,
        'credentials': {
          'email': admin.email,
          'password': password,
          'role': admin.role.label,
        },
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'bodyText': plainText,
        'html': htmlContent,
      };

      bool queueRecorded = false;

      // 1. Record email dispatch in Firestore audit queue
      try {
        await firestore.collection('admin_mail_dispatch').add(emailPayload);
        queueRecorded = true;
      } catch (e) {
        AppLogger.warning(
          'Could not write to admin_mail_dispatch: $e',
          tag: 'EmailCredentialsService',
        );
      }

      // 2. Also record in standard 'mail' collection (Firebase Trigger Email extension compatible)
      try {
        await firestore.collection('mail').add({
          'to': [admin.email],
          'message': {
            'subject': subject,
            'text': plainText,
            'html': htmlContent,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
        queueRecorded = true;
      } catch (e) {
        AppLogger.warning(
          'Could not write to mail collection: $e',
          tag: 'EmailCredentialsService',
        );
      }

      if (queueRecorded) {
        AppLogger.info(
          'Successfully dispatched welcome email with credentials to ${admin.email}',
          tag: 'EmailCredentialsService',
        );
        return true;
      }
      return false;
    } catch (e) {
      AppLogger.error(
        'Failed to dispatch credentials email to ${admin.email}: $e',
        tag: 'EmailCredentialsService',
      );
      return false;
    }
  }

  /// Generates the direct Gmail Web compose URL with pre-filled ID and password.
  Uri getGmailComposeUri({
    required AdminUser admin,
    required String password,
    String portalUrl = defaultPortalUrl,
  }) {
    const subject = 'Your QR Check-in Admin Login Credentials';
    final body = generatePlainEmailBody(
      admin: admin,
      password: password,
      portalUrl: portalUrl,
    );

    return Uri.parse(
      'https://mail.google.com/mail/?view=cm&fs=1'
      '&to=${Uri.encodeComponent(admin.email)}'
      '&su=${Uri.encodeComponent(subject)}'
      '&body=${Uri.encodeComponent(body)}',
    );
  }

  /// Opens Gmail Web Compose in a new browser window/tab.
  Future<bool> openInGmail({
    required AdminUser admin,
    required String password,
    String portalUrl = defaultPortalUrl,
  }) async {
    final uri = getGmailComposeUri(
      admin: admin,
      password: password,
      portalUrl: portalUrl,
    );
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      AppLogger.warning('Could not launch Gmail URL: $e',
          tag: 'EmailCredentialsService');
      // Fallback to mailto
      final mailtoUri = Uri(
        scheme: 'mailto',
        path: admin.email,
        queryParameters: {
          'subject': 'Your QR Check-in Admin Login Credentials',
          'body': generatePlainEmailBody(
            admin: admin,
            password: password,
            portalUrl: portalUrl,
          ),
        },
      );
      return await launchUrl(mailtoUri, mode: LaunchMode.externalApplication);
    }
  }
}

