import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../../../core/logger/app_logger.dart';
import '../../../../firebase_options.dart';

/// Result of provisioning a Firebase Auth user on a secondary app.
class AdminAuthProvisionResult {
  const AdminAuthProvisionResult({required this.uid, this.created = true});

  final String uid;
  final bool created;
}

/// Secondary-app Auth provisioning for new admins. Does not send email.
///
/// Never signs in on the primary [FirebaseAuth.instance]. Never calls
/// signInWithEmailAndPassword for the new admin — that would risk replacing
/// the Super Admin session and is unnecessary to create Firestore profiles.
class AdminAuthEmailClient {
  AdminAuthEmailClient._();

  static const secondaryAppName = 'attendiphiAdminProvision';

  /// In-flight create locks keyed by email (prevents double Create taps).
  static final Map<String, Future<String?>> _inflight = {};

  /// Creates the Firebase Auth user if missing. Returns the Auth UID.
  ///
  /// On [email-already-in-use], throws [FirebaseAuthException] without signing
  /// in. Callers must resolve duplicate / orphaned Auth accounts via Firestore.
  static Future<String?> provisionAuthUser(
    String email, {
    String? password,
    http.Client? httpClient,
    String? apiKey,
  }) async {
    final normalized = email.trim().toLowerCase();
    final secret = password?.trim() ?? '';
    if (secret.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters.',
      );
    }
    if (httpClient != null) {
      return await _signUpIfNeeded(
        client: httpClient,
        apiKey: (apiKey ?? _webApiKey()).trim(),
        email: normalized,
        password: secret,
      );
    }

    final existing = _inflight[normalized];
    if (existing != null) return existing;

    final future = _provisionViaSdk(normalized, password: secret);
    _inflight[normalized] = future;
    try {
      return await future;
    } finally {
      _inflight.remove(normalized);
    }
  }

  /// Redacts an email for logs (`j***@example.com`). Never log full addresses.
  @visibleForTesting
  static String redactEmail(String email) {
    final normalized = email.trim().toLowerCase();
    final at = normalized.indexOf('@');
    if (at <= 0 || at == normalized.length - 1) return '[redacted-email]';
    final local = normalized.substring(0, at);
    final domain = normalized.substring(at + 1);
    final prefix = local.isEmpty ? '*' : local[0];
    return '$prefix***@$domain';
  }

  static Future<void> _ensureRecaptcha(FirebaseAuth auth) async {
    if (!kIsWeb) return;
    try {
      await auth.initializeRecaptchaConfig();
    } catch (e) {
      AppLogger.warning('reCAPTCHA init failed: $e', tag: 'AdminAuthEmail');
    }
  }

  static Future<String?> _provisionViaSdk(
    String email, {
    required String password,
  }) async {
    FirebaseAuth? authUsed;
    final primaryUidBefore = FirebaseAuth.instance.currentUser?.uid;
    final redacted = redactEmail(email);
    try {
      authUsed = await _secondaryAuth();
      // Guard: never use the primary Auth instance for provisioning.
      if (identical(authUsed, FirebaseAuth.instance)) {
        throw FirebaseAuthException(
          code: 'internal-error',
          message: 'Secondary Firebase Auth is required to create admins.',
        );
      }

      // Critical on Flutter Web: do not share IndexedDB/local persistence with
      // the primary Super Admin session.
      try {
        await authUsed.setPersistence(Persistence.NONE);
      } catch (e) {
        AppLogger.warning(
          'Secondary Auth persistence: $e',
          tag: 'AdminAuthEmail',
        );
      }

      await _ensureRecaptcha(authUsed);

      try {
        final cred = await authUsed.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final uid = cred.user?.uid.trim() ?? '';
        if (uid.isEmpty) {
          throw FirebaseAuthException(
            code: 'internal-error',
            message: 'Firebase Auth did not return a UID.',
          );
        }
        AppLogger.info(
          'AUTH USER created recipient: $redacted',
          tag: 'AdminAuthEmail',
        );
        return uid;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          // Do NOT signInWithEmailAndPassword — preserves Super Admin session.
          AppLogger.info(
            'AUTH USER exists recipient: $redacted',
            tag: 'AdminAuthEmail',
          );
          rethrow;
        }
        rethrow;
      }
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      AppLogger.error(
        'AUTH PROVISION FAILURE recipient: $redacted',
        error: e,
        tag: 'AdminAuthEmail',
      );
      throw FirebaseAuthException(
        code: 'internal-error',
        message: e.toString(),
      );
    } finally {
      await _disposeSecondary(authUsed);
      final primaryUidAfter = FirebaseAuth.instance.currentUser?.uid;
      if (primaryUidBefore != null &&
          primaryUidAfter != null &&
          primaryUidBefore != primaryUidAfter) {
        AppLogger.warning(
          'AUTH WARNING: primary session changed during provision (spillover).',
          tag: 'AdminAuthEmail',
        );
      }
    }
  }

  static Future<void> _disposeSecondary(FirebaseAuth? authUsed) async {
    try {
      await authUsed?.signOut();
    } catch (_) {}
    try {
      final app = Firebase.app(secondaryAppName);
      await app.delete();
    } catch (_) {}
  }

  static Future<FirebaseAuth> _secondaryAuth() async {
    FirebaseApp app;
    try {
      app = Firebase.app(secondaryAppName);
    } catch (_) {
      app = await Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.apps.isNotEmpty
            ? Firebase.app().options
            : DefaultFirebaseOptions.currentPlatform,
      );
    }
    return FirebaseAuth.instanceFor(app: app);
  }

  static String _webApiKey() {
    try {
      final key = Firebase.app().options.apiKey;
      if (key.isNotEmpty) return key;
    } catch (_) {}
    return DefaultFirebaseOptions.web.apiKey;
  }

  static Uri _endpoint(String path, String apiKey) {
    return Uri.https(
      'identitytoolkit.googleapis.com',
      '/v1/$path',
      {'key': apiKey},
    );
  }

  /// Test / HTTP path: signUp only. Never signInWithPassword.
  static Future<String?> _signUpIfNeeded({
    required http.Client client,
    required String apiKey,
    required String email,
    required String password,
  }) async {
    if (apiKey.isEmpty) {
      throw FirebaseAuthException(
        code: 'internal-error',
        message: 'Firebase Auth is not configured.',
      );
    }
    final response = await client
        .post(
          _endpoint('accounts:signUp', apiKey),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            'returnSecureToken': true,
          }),
        )
        .timeout(const Duration(seconds: 20));
    final code = _errorCode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['localId'] is String) {
          return decoded['localId'] as String;
        }
      } catch (_) {}
      return null;
    }
    if (code == 'EMAIL_EXISTS') {
      throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'EMAIL_EXISTS',
      );
    }
    throw FirebaseAuthException(
      code: _toAuthCode(code),
      message: code,
    );
  }

  static String _errorCode(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final message = decoded['error']['message'];
        if (message is String && message.isNotEmpty) {
          return message.split(' ').first.split(':').first;
        }
      }
    } catch (_) {}
    return 'internal-error';
  }

  static String _toAuthCode(String identityToolkitCode) {
    switch (identityToolkitCode) {
      case 'EMAIL_EXISTS':
        return 'email-already-in-use';
      case 'EMAIL_NOT_FOUND':
        return 'user-not-found';
      case 'INVALID_EMAIL':
        return 'invalid-email';
      case 'OPERATION_NOT_ALLOWED':
        return 'operation-not-allowed';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'too-many-requests';
      case 'MISSING_RECAPTCHA_TOKEN':
      case 'CAPTCHA_CHECK_FAILED':
        return 'captcha-check-failed';
      case 'API_KEY_HTTP_REFERRER_BLOCKED':
      case 'API_KEY_INVALID':
        return 'invalid-api-key';
      default:
        return identityToolkitCode.toLowerCase().replaceAll('_', '-');
    }
  }

  static String publicCreateError(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'Please provide a valid email address.';
        case 'weak-password':
          return 'Password must be at least 6 characters.';
        case 'email-already-in-use':
          return 'An Admin account already exists for this email.';
        case 'network-request-failed':
          return 'Network error. Please try again.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'operation-not-allowed':
          return 'Enable Email/Password in Firebase Authentication, then try again.';
        case 'captcha-check-failed':
          return 'Firebase blocked the request as automated. Refresh and try again.';
        case 'unauthorized-domain':
        case 'invalid-api-key':
          return 'Add attendiphi-by-metaphi.web.app and attendiphi.metaphi.in under Authentication → Settings → Authorized domains.';
        default:
          return 'Could not create the Admin account. Please try again.';
      }
    }
    final text = error.toString();
    if (text.contains('Firebase Auth user was created')) {
      // Fixed copy — do not echo Exception text (may include emails).
      return 'Firebase Auth user was created, but the Admin profile could not be '
          'saved. Stay signed in as Super Admin and try again, or delete the '
          'Auth user for the email you entered under Authentication → Users '
          'if it shows as orphaned.';
    }
    if (text.contains('orphaned') || text.contains('Authentication → Users')) {
      return 'A Firebase Auth account already exists for this email, but no '
          'Admin profile is linked (orphaned Auth user). In Firebase Console → '
          'Authentication → Users, delete the Auth user for the email you '
          'entered, then create the Admin again.';
    }
    if (text.contains('already exists')) {
      return 'An Admin account already exists for this email.';
    }
    if (text.contains('permission-denied') || text.contains('PERMISSION_DENIED')) {
      return 'Could not save the Admin profile. Stay signed in as Super Admin and try again.';
    }
    return 'Could not create the Admin account. Please try again.';
  }

  static String publicSendError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'Please provide a valid recipient email address.';
      case 'network-request-failed':
        return 'Network error. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Enable Email/Password in Firebase Authentication, then try again.';
      case 'captcha-check-failed':
        return 'Firebase blocked the request as automated. Refresh and try again.';
      case 'unauthorized-continue-uri':
      case 'invalid-continue-uri':
      case 'missing-continue-uri':
      case 'unauthorized-domain':
        return 'Add attendiphi-by-metaphi.web.app and attendiphi.metaphi.in under Authentication → Settings → Authorized domains.';
      case 'invalid-api-key':
        return 'Firebase Auth is blocked for this domain. Check authorized domains.';
      default:
        final detail = error.message?.trim();
        if (detail != null && detail.isNotEmpty && detail != error.code) {
          return 'Failed to send mail.\nPlease try again. (${error.code}: $detail)';
        }
        return 'Failed to send mail.\nPlease try again. (${error.code})';
    }
  }
}
