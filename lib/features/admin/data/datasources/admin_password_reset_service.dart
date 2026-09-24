import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/validators.dart';
import '../../../../services/attendiphi_email_service.dart';
import '../../domain/admin_password_hasher.dart';

class PasswordResetRequestResult {
  const PasswordResetRequestResult({
    required this.accepted,
    this.userMessage = '',
  });

  final bool accepted;
  final String userMessage;
}

class PasswordResetTokenStatus {
  const PasswordResetTokenStatus({required this.valid, this.email = ''});

  final bool valid;
  final String email;
}

class PasswordResetCompleteResult {
  const PasswordResetCompleteResult({
    required this.success,
    this.invalidOrExpired = false,
    this.userMessage = '',
  });

  final bool success;
  final bool invalidOrExpired;
  final String userMessage;
}

/// Unauthenticated Forgot Password: Flutter → Supabase Edge Function →
/// Firebase Admin oob link → SMTP. Firebase Auth remains the password store.
class AdminPasswordResetService {
  AdminPasswordResetService({
    this.auth,
    this.firestore,
    this.emailService,
    this.sendPasswordResetEmailFn,
    this.verifyPasswordResetCodeFn,
    this.confirmPasswordResetFn,
  });

  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final AttendiphiEmailService? emailService;

  /// Test hook for the unauthenticated reset-mail request.
  final Future<void> Function(String email)? sendPasswordResetEmailFn;
  final Future<String> Function(String code)? verifyPasswordResetCodeFn;
  final Future<void> Function({
    required String code,
    required String newPassword,
  })? confirmPasswordResetFn;

  static const genericAcceptedMessage =
      'If an account exists for this email, a password reset link has been sent.';

  Future<PasswordResetRequestResult> requestReset({
    required String email,
  }) async {
    final formatError = Validators.validateEmail(email);
    if (formatError != null) {
      return PasswordResetRequestResult(
        accepted: false,
        userMessage: formatError,
      );
    }

    final normalized = email.trim().toLowerCase();
    try {
      if (sendPasswordResetEmailFn != null) {
        await sendPasswordResetEmailFn!(normalized);
        return const PasswordResetRequestResult(
          accepted: true,
          userMessage: genericAcceptedMessage,
        );
      }
      final result = await (emailService ?? AttendiphiEmailService.instance)
          .requestPasswordReset(email: normalized);
      if (result.success) {
        return const PasswordResetRequestResult(
          accepted: true,
          userMessage: genericAcceptedMessage,
        );
      }
      if (result.statusCode == 429) {
        return const PasswordResetRequestResult(
          accepted: false,
          userMessage: 'Too many attempts. Please try again later.',
        );
      }
      final message = result.userMessage.trim();
      return PasswordResetRequestResult(
        accepted: false,
        userMessage: message.isEmpty
            ? 'Could not send a reset email. Please try again.'
            : message,
      );
    } catch (e) {
      AppLogger.warning(
        'Password reset request failed',
        tag: 'AdminPasswordReset',
      );
      return const PasswordResetRequestResult(
        accepted: false,
        userMessage: 'Could not send a reset email. Please try again.',
      );
    }
  }

  Future<PasswordResetTokenStatus> verifyToken(String token) async {
    if (token.trim().isEmpty) {
      return const PasswordResetTokenStatus(valid: false);
    }
    try {
      final email = await _verifyCode(token.trim());
      return PasswordResetTokenStatus(valid: true, email: email.trim());
    } catch (_) {
      return const PasswordResetTokenStatus(valid: false);
    }
  }

  Future<PasswordResetCompleteResult> completeReset({
    required String token,
    required String newPassword,
  }) async {
    final password = newPassword.trim();
    final policy = AdminPasswordHasher.policyError(password);
    if (policy != null) {
      return PasswordResetCompleteResult(
        success: false,
        userMessage: policy,
      );
    }
    try {
      final email = await _verifyCode(token.trim());
      await _confirmCode(code: token.trim(), newPassword: password);
      await _syncAdminPasswordMetadata(email: email, password: password);
      return const PasswordResetCompleteResult(success: true);
    } on FirebaseAuthException catch (e) {
      return _completeError(e.code);
    } catch (_) {
      return const PasswordResetCompleteResult(
        success: false,
        userMessage: 'Could not reset the password. Please try again.',
      );
    }
  }

  Future<String> _verifyCode(String code) {
    if (verifyPasswordResetCodeFn != null) {
      return verifyPasswordResetCodeFn!(code);
    }
    final auth = this.auth ?? FirebaseAuth.instance;
    return auth.verifyPasswordResetCode(code);
  }

  Future<void> _confirmCode({
    required String code,
    required String newPassword,
  }) {
    if (confirmPasswordResetFn != null) {
      return confirmPasswordResetFn!(code: code, newPassword: newPassword);
    }
    final auth = this.auth ?? FirebaseAuth.instance;
    return auth.confirmPasswordReset(code: code, newPassword: newPassword);
  }

  PasswordResetCompleteResult _completeError(String code) {
    switch (code) {
      case 'expired-action-code':
        return const PasswordResetCompleteResult(
          success: false,
          invalidOrExpired: true,
          userMessage: 'This password reset link has expired.',
        );
      case 'invalid-action-code':
        return const PasswordResetCompleteResult(
          success: false,
          invalidOrExpired: true,
          userMessage: 'This password reset link is no longer valid.',
        );
      case 'weak-password':
        return const PasswordResetCompleteResult(
          success: false,
          userMessage: 'Please choose a stronger password.',
        );
      case 'network-request-failed':
        return const PasswordResetCompleteResult(
          success: false,
          userMessage: 'Network error. Please try again.',
        );
      default:
        return const PasswordResetCompleteResult(
          success: false,
          invalidOrExpired: true,
          userMessage: 'This password reset link is no longer valid.',
        );
    }
  }

  /// Hash/salt + mustResetPassword only. Never writes plaintext passwords.
  Future<void> _syncAdminPasswordMetadata({
    required String email,
    required String password,
  }) async {
    if (firestore == null || email.trim().isEmpty) return;
    try {
      final snapshot = await firestore!
          .collection(AppConstants.adminsCollection)
          .where('email', isEqualTo: email.trim().toLowerCase())
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return;
      final salt = AdminPasswordHasher.generateSalt();
      await snapshot.docs.first.reference.update({
        'passwordHash': AdminPasswordHasher.hash(password, salt),
        'passwordSalt': salt,
        'plainPassword': FieldValue.delete(),
        'mustResetPassword': false,
        'passwordUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Password metadata sync skipped');
      }
    }
  }
}
