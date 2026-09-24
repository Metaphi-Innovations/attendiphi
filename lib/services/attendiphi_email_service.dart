import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../app/router/app_url.dart';
import '../core/config/supabase_email_config.dart';
import '../core/config/supabase_email_config_stub.dart'
    if (dart.library.html) '../core/config/supabase_email_config_web.dart';
import '../core/logger/app_logger.dart';
import '../features/admin/data/datasources/admin_auth_email.dart';
import '../features/admin/domain/entities/admin_user.dart';
import '../firebase_options.dart';

class AttendiphiEmailResult {
  const AttendiphiEmailResult({
    required this.success,
    this.userMessage = '',
    this.messageId = '',
    this.statusCode = 0,
  });

  final bool success;
  final String userMessage;
  final String messageId;
  final int statusCode;
}

class AttendiphiEmailException implements Exception {
  AttendiphiEmailException(this.userMessage, {this.code = 'send_failed'});

  final String userMessage;
  final String code;

  @override
  String toString() => 'AttendiphiEmailException($code)';
}

/// Sends Attendiphi transactional email through the Supabase Edge Function.
///
/// Auth uses a Firebase ID token. SMTP credentials never leave the Edge Function.
class AttendiphiEmailService {
  AttendiphiEmailService({
    FirebaseAuth? auth,
    http.Client? httpClient,
    Future<String> Function()? idTokenFn,
    Future<BrowserSupabaseConfig> Function()? readBrowserConfigFn,
  }) : this._(
          auth,
          httpClient ?? http.Client(),
          idTokenFn,
          readBrowserConfigFn ?? readBrowserSupabaseConfig,
        );

  AttendiphiEmailService._(
    this._auth,
    this._http,
    this._idTokenFn,
    this._readBrowserConfig,
  );

  static final AttendiphiEmailService instance = AttendiphiEmailService();

  final FirebaseAuth? _auth;
  final http.Client _http;
  final Future<String> Function()? _idTokenFn;
  final Future<BrowserSupabaseConfig> Function() _readBrowserConfig;

  FirebaseAuth get _firebaseAuth => _auth ?? FirebaseAuth.instance;

  /// Unauthenticated Forgot Password. Does not send a Firebase ID token.
  Future<AttendiphiEmailResult> requestPasswordReset({
    required String email,
  }) async {
    final recipient = email.trim().toLowerCase();
    if (recipient.isEmpty || !recipient.contains('@')) {
      return const AttendiphiEmailResult(
        success: false,
        userMessage: 'Please enter a valid email address.',
      );
    }

    late final Uri endpoint;
    late final String anonKey;
    try {
      final resolved = await _resolveEndpoint();
      endpoint = resolved.endpoint;
      anonKey = resolved.anonKey;
    } on AttendiphiEmailException catch (e) {
      return AttendiphiEmailResult(success: false, userMessage: e.userMessage);
    }

    AppLogger.info(
      'PASSWORD RESET REQUEST START',
      tag: 'AttendiphiEmail',
    );

    try {
      final response = await _http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'apikey': anonKey,
              'Authorization': 'Bearer $anonKey',
            },
            body: jsonEncode({
              'type': 'password_reset',
              'emailType': 'password_reset',
              'email': recipient,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info(
          'PASSWORD RESET REQUEST ACCEPTED status: ${response.statusCode}',
          tag: 'AttendiphiEmail',
        );
        return AttendiphiEmailResult(
          success: true,
          statusCode: response.statusCode,
          userMessage:
              'If an account exists for this email, a password reset link has been sent.',
        );
      }

      AppLogger.warning(
        'PASSWORD RESET REQUEST FAILURE status: ${response.statusCode}',
        tag: 'AttendiphiEmail',
      );
      if (response.statusCode == 429) {
        return const AttendiphiEmailResult(
          success: false,
          statusCode: 429,
          userMessage: 'Too many attempts. Please try again later.',
        );
      }
      if (response.statusCode == 400) {
        return const AttendiphiEmailResult(
          success: false,
          statusCode: 400,
          userMessage: 'Please enter a valid email address.',
        );
      }
      Map<String, dynamic> decoded = {};
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) decoded = body;
      } catch (_) {}
      final serverError = (decoded['error'] as String?)?.trim() ?? '';
      return AttendiphiEmailResult(
        success: false,
        statusCode: response.statusCode,
        userMessage: serverError.isNotEmpty
            ? serverError
            : 'Could not send a reset email. Please try again.',
      );
    } catch (_) {
      AppLogger.warning(
        'PASSWORD RESET REQUEST FAILURE network',
        tag: 'AttendiphiEmail',
      );
      return const AttendiphiEmailResult(
        success: false,
        userMessage: 'Network error. Check your connection and try again.',
      );
    }
  }

  Future<AttendiphiEmailResult> sendAdminWelcome({
    required AdminUser admin,
    required String password,
    String? subject,
    String? html,
    String portalUrl = '',
  }) {
    return send(
      emailType: 'admin_welcome',
      recipientEmail: admin.email,
      recipientName: admin.name,
      subject: subject,
      html: html,
      extra: {
        'password': password,
        'roleLabel': admin.role.label,
        'portalUrl': portalUrl.trim().isEmpty
            ? '${AppUrl.portalOrigin}/'
            : portalUrl,
      },
    );
  }

  Future<AttendiphiEmailResult> send({
    required String emailType,
    required String recipientEmail,
    required String recipientName,
    String? subject,
    String? html,
    Map<String, String> extra = const {},
  }) async {
    final recipient = recipientEmail.trim().toLowerCase();
    if (recipient.isEmpty || !recipient.contains('@')) {
      return const AttendiphiEmailResult(
        success: false,
        userMessage: 'Please provide a valid recipient email address.',
      );
    }

    late final Uri endpoint;
    late final String anonKey;
    try {
      final resolved = await _resolveEndpoint();
      endpoint = resolved.endpoint;
      anonKey = resolved.anonKey;
    } on AttendiphiEmailException catch (e) {
      return AttendiphiEmailResult(success: false, userMessage: e.userMessage);
    }

    final token = await _firebaseIdToken();
    if (token == null || token.isEmpty) {
      AppLogger.warning(
        'SEND MAIL FAILURE recipient: $recipient code: missing_firebase_token',
        tag: 'AttendiphiEmail',
      );
      return const AttendiphiEmailResult(
        success: false,
        userMessage:
            'Sign in again, then retry. A Firebase session is required to send mail.',
      );
    }

    AppLogger.info(
      'SEND MAIL START type: $emailType recipient: $recipient',
      tag: 'AttendiphiEmail',
    );

    final payload = <String, dynamic>{
      'emailType': emailType,
      'recipientEmail': recipient,
      'recipientName': recipientName.trim(),
      if (subject != null && subject.trim().isNotEmpty) 'subject': subject.trim(),
      if (html != null && html.trim().isNotEmpty) 'html': html.trim(),
      ...extra,
    };

    try {
      final response = await _http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'apikey': anonKey,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic> decoded = {};
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) decoded = body;
      } catch (_) {}

      final messageId = (decoded['id'] as String?)?.trim() ?? '';
      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info(
          'SEND MAIL SUCCESS type: $emailType status: ${response.statusCode} messageId: ${messageId.isEmpty ? 'none' : messageId}',
          tag: 'AttendiphiEmail',
        );
        return AttendiphiEmailResult(
          success: true,
          messageId: messageId,
          statusCode: response.statusCode,
          userMessage: 'Email sent successfully to $recipient',
        );
      }

      AppLogger.warning(
        'SEND MAIL FAILURE type: $emailType status: ${response.statusCode}',
        tag: 'AttendiphiEmail',
      );
      final serverError = (decoded['error'] as String?)?.trim() ?? '';
      return AttendiphiEmailResult(
        success: false,
        statusCode: response.statusCode,
        userMessage: serverError.isNotEmpty
            ? serverError
            : 'Email could not be sent (${response.statusCode}). Please try again.',
      );
    } catch (_) {
      AppLogger.warning(
        'SEND MAIL FAILURE type: $emailType recipient: $recipient',
        tag: 'AttendiphiEmail',
      );
      return const AttendiphiEmailResult(
        success: false,
        userMessage: 'Network error. Check your connection and try again.',
      );
    }
  }

  Future<({Uri endpoint, String anonKey})> _resolveEndpoint() async {
    final browser = await _readBrowserConfig();
    final url = _firstNonEmpty([
      SupabaseEmailConfig.dartDefinedUrl,
      browser.url,
      SupabaseEmailConfig.productionUrl,
    ]).replaceAll(RegExp(r'/$'), '');
    final anonKey = _firstNonEmpty([
      SupabaseEmailConfig.dartDefinedAnonKey,
      browser.anonKey,
      SupabaseEmailConfig.productionPublishableKey,
    ]);
    if (url.isEmpty || anonKey.isEmpty) {
      throw AttendiphiEmailException(
        'Supabase email is not configured. Add supabase-url and supabase-anon-key.',
        code: 'missing_supabase_config',
      );
    }
    return (
      endpoint: Uri.parse('$url${SupabaseEmailConfig.functionNamePath}'),
      anonKey: anonKey,
    );
  }

  static String _firstNonEmpty(List<String> values) {
    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  Future<String?> _firebaseIdToken() async {
    final getToken = _idTokenFn;
    if (getToken != null) {
      final token = (await getToken()).trim();
      return token.isEmpty ? null : token;
    }
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) return null;
      return await user.getIdToken();
    } catch (e) {
      AppLogger.warning(
        'Firebase ID token could not be read',
        tag: 'AttendiphiEmail',
      );
      return null;
    }
  }
}

/// Ensures the signed-in Attendiphi admin also has a Firebase Auth session
/// so welcome mail can send a verified ID token.
Future<void> attachFirebaseAuthSession({
  required String email,
  required String password,
  FirebaseAuth? auth,
}) async {
  final normalized = email.trim().toLowerCase();
  final secret = password.trim();
  if (normalized.isEmpty || secret.length < 6) return;
  final firebaseAuth = auth ?? FirebaseAuth.instance;
  try {
    if (firebaseAuth.currentUser?.email?.toLowerCase() == normalized) {
      await firebaseAuth.currentUser?.getIdToken(true);
      return;
    }
    try {
      await firebaseAuth.signInWithEmailAndPassword(
        email: normalized,
        password: secret,
      );
      return;
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' && e.code != 'invalid-credential') {
        rethrow;
      }
    }
    await AdminAuthEmailClient.provisionAuthUser(
      normalized,
      password: secret,
    );
    await firebaseAuth.signInWithEmailAndPassword(
      email: normalized,
      password: secret,
    );
  } catch (e) {
    AppLogger.warning(
      'Firebase session was not attached for email sending',
      tag: 'AttendiphiEmail',
    );
  }
}

/// Exposed for tests that assert DefaultFirebaseOptions stay on qr-checkin-dev.
String attendiphiFirebaseProjectId() =>
    DefaultFirebaseOptions.web.projectId;
