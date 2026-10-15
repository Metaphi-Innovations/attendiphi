import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/router/app_url.dart';
import '../core/config/supabase_email_config.dart';
import '../core/config/supabase_email_config_stub.dart'
    if (dart.library.html) '../core/config/supabase_email_config_web.dart';
import '../core/logger/app_logger.dart';
import '../features/admin/domain/entities/admin_user.dart';

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
/// Auth uses the Supabase session access token. SMTP credentials never leave
/// the Edge Function.
class AttendiphiEmailService {
  AttendiphiEmailService({
    http.Client? httpClient,
    Future<String> Function()? idTokenFn,
    Future<BrowserSupabaseConfig> Function()? readBrowserConfigFn,
  }) : this._(
         httpClient ?? http.Client(),
         idTokenFn,
         readBrowserConfigFn ?? readBrowserSupabaseConfig,
       );

  AttendiphiEmailService._(
    this._http,
    this._idTokenFn,
    this._readBrowserConfig,
  );

  static final AttendiphiEmailService instance = AttendiphiEmailService();

  final http.Client _http;
  final Future<String> Function()? _idTokenFn;
  final Future<BrowserSupabaseConfig> Function() _readBrowserConfig;

  /// Unauthenticated Forgot Password via Edge Function → Gmail SMTP.
  /// Does not send a user access token (anon key only).
  Future<AttendiphiEmailResult> requestPasswordReset({
    required String email,
    String? portalUrl,
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

    final resetPortal = (portalUrl ?? '${AppUrl.portalOrigin}/').trim();

    AppLogger.info('PASSWORD RESET REQUEST START', tag: 'AttendiphiEmail');

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
              'portalUrl': resetPortal,
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
          userMessage: 'If an account exists for this email, a password reset link has been sent.',
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
    // Credentials emails always point at the production portal so recipients
    // are not sent to whoever's localhost created the admin.
    final resolvedPortal = portalUrl.trim().isEmpty
        ? '${AppUrl.productionOrigin}/'
        : portalUrl.trim();
    return send(
      emailType: 'admin_welcome',
      recipientEmail: admin.email,
      recipientName: admin.name,
      subject: subject,
      html: html,
      extra: {
        'password': password,
        'roleLabel': admin.role.label,
        'portalUrl': resolvedPortal,
        if (admin.id.trim().isNotEmpty) 'adminId': admin.id.trim(),
      },
    );
  }

  /// Creates or updates the Supabase Auth user and links `admins.auth_user_id`.
  Future<({bool success, String userMessage, String authUserId})>
  provisionAuthAdmin({
    required String email,
    required String password,
    String? adminId,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanPassword = password.trim();
    final cleanAdminId = (adminId ?? '').trim();
    if (cleanEmail.isEmpty || !cleanEmail.contains('@')) {
      return (
        success: false,
        userMessage: 'A valid email is required to provision Auth.',
        authUserId: '',
      );
    }
    if (cleanPassword.length < 6) {
      return (
        success: false,
        userMessage: 'Password must be at least 6 characters.',
        authUserId: '',
      );
    }

    late final Uri endpoint;
    late final String anonKey;
    try {
      final resolved = await _resolveEndpoint();
      endpoint = resolved.endpoint;
      anonKey = resolved.anonKey;
    } on AttendiphiEmailException catch (e) {
      return (success: false, userMessage: e.userMessage, authUserId: '');
    }

    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      return (
        success: false,
        userMessage: 'Sign in again, then retry. A Supabase session is required to provision admins.',
        authUserId: '',
      );
    }

    try {
      final response = await _http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'apikey': anonKey,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'action': 'provision_admin',
              'email': cleanEmail,
              'password': cleanPassword,
              if (cleanAdminId.isNotEmpty) 'adminId': cleanAdminId,
            }),
          )
          .timeout(const Duration(seconds: 25));

      Map<String, dynamic> decoded = {};
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) decoded = body;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return (
          success: true,
          userMessage:
              decoded['message'] as String? ?? 'Auth user provisioned.',
          authUserId: (decoded['authUserId'] as String? ?? '').trim(),
        );
      }

      final errorMsg = (decoded['error'] as String?)?.trim() ?? '';
      return (
        success: false,
        userMessage: errorMsg.isNotEmpty
            ? errorMsg
            : 'Could not provision Auth user (${response.statusCode}).',
        authUserId: '',
      );
    } catch (e) {
      return (
        success: false,
        userMessage: 'Network error provisioning Auth ($e).',
        authUserId: '',
      );
    }
  }

  /// Deletes an admin user from Supabase Authentication via the Edge Function.
  ///
  /// Only administrators can delete admin accounts. Requires a valid Supabase
  /// access token.
  Future<({bool success, String userMessage})> deleteAuthAdmin({
    required String uid,
    String? email,
  }) async {
    final cleanUid = uid.trim();
    final cleanEmail = (email ?? '').trim().toLowerCase();
    if (cleanUid.isEmpty && cleanEmail.isEmpty) {
      return (
        success: false,
        userMessage:
            'A user UID or email is required to delete the Auth account.',
      );
    }

    late final Uri endpoint;
    late final String anonKey;
    try {
      final resolved = await _resolveEndpoint();
      endpoint = resolved.endpoint;
      anonKey = resolved.anonKey;
    } on AttendiphiEmailException catch (e) {
      return (success: false, userMessage: e.userMessage);
    }

    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      AppLogger.warning(
        'DELETE AUTH USER FAILURE uid: $cleanUid code: missing_access_token',
        tag: 'AttendiphiEmail',
      );
      return (
        success: false,
        userMessage: 'Sign in again, then retry. A Supabase session is required to delete admins.',
      );
    }

    AppLogger.info(
      'DELETE AUTH USER START uid: $cleanUid email: $cleanEmail',
      tag: 'AttendiphiEmail',
    );

    try {
      final response = await _http
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'apikey': anonKey,
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'action': 'delete_admin',
              'targetUid': cleanUid,
              if (cleanEmail.isNotEmpty) 'email': cleanEmail,
            }),
          )
          .timeout(const Duration(seconds: 25));

      Map<String, dynamic> decoded = {};
      try {
        final body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) decoded = body;
      } catch (_) {}

      if (response.statusCode >= 200 && response.statusCode < 300) {
        AppLogger.info(
          'DELETE AUTH USER SUCCESS uid: $cleanUid',
          tag: 'AttendiphiEmail',
        );
        return (
          success: true,
          userMessage:
              decoded['message'] as String? ??
              'Admin deleted from Authentication successfully.',
        );
      }

      final errorMsg = (decoded['error'] as String?)?.trim() ?? '';
      AppLogger.warning(
        'DELETE AUTH USER FAILURE uid: $cleanUid status: ${response.statusCode} error: $errorMsg',
        tag: 'AttendiphiEmail',
      );
      return (
        success: false,
        userMessage: errorMsg.isNotEmpty
            ? errorMsg
            : 'Could not delete user from Authentication (${response.statusCode}).',
      );
    } catch (e) {
      AppLogger.warning(
        'DELETE AUTH USER FAILURE uid: $cleanUid error: $e',
        tag: 'AttendiphiEmail',
      );
      return (
        success: false,
        userMessage:
            'Network error communicating with authentication service ($e).',
      );
    }
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

    final token = await _accessToken();
    if (token == null || token.isEmpty) {
      AppLogger.warning(
        'SEND MAIL FAILURE recipient: $recipient code: missing_access_token',
        tag: 'AttendiphiEmail',
      );
      return const AttendiphiEmailResult(
        success: false,
        userMessage: 'Sign in again, then retry. A Supabase session is required to send mail.',
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
      if (subject != null && subject.trim().isNotEmpty)
        'subject': subject.trim(),
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

  Future<String?> _accessToken() async {
    final getToken = _idTokenFn;
    if (getToken != null) {
      final token = (await getToken()).trim();
      return token.isEmpty ? null : token;
    }
    try {
      final token = Supabase.instance.client.auth.currentSession?.accessToken;
      if (token == null) return null;
      final trimmed = token.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (e) {
      AppLogger.warning(
        'Supabase access token could not be read',
        tag: 'AttendiphiEmail',
      );
      return null;
    }
  }
}
