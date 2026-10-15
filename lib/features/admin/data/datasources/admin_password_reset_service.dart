import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/router/app_url.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/validators.dart';
import '../../../../services/attendiphi_email_service.dart';
import '../../domain/admin_password_hasher.dart';
import 'supabase_admin_remote_data_source.dart';

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

/// Forgot Password via Edge Function (Gmail SMTP) + Supabase recovery link.
///
/// The Edge Function creates an Auth recovery `action_link` and emails it from
/// Attendiphi mail. Completing the reset uses the recovery session with
/// `updateUser`.
class AdminPasswordResetService {
  AdminPasswordResetService({
    this.sendPasswordResetEmailFn,
    this.currentSessionFn,
    this.updatePasswordFn,
    this.emailService,
  });

  /// Test hook for the unauthenticated reset-mail request.
  final Future<void> Function(String email)? sendPasswordResetEmailFn;

  /// Test hook for reading the current (recovery) session.
  final Session? Function()? currentSessionFn;

  /// Test hook for applying the new password.
  final Future<void> Function(String newPassword)? updatePasswordFn;

  final AttendiphiEmailService? emailService;

  static const genericAcceptedMessage =
      'If an account exists for this email, a password reset link has been sent.';

  static const _requestNewLinkMessage =
      'This password reset link is no longer valid. Please request a new one.';

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
      } else {
        final result = await (emailService ?? AttendiphiEmailService.instance)
            .requestPasswordReset(
              email: normalized,
              portalUrl: '${AppUrl.portalOrigin}/',
            );
        if (!result.success) {
          return PasswordResetRequestResult(
            accepted: false,
            userMessage: result.userMessage.isNotEmpty
                ? result.userMessage
                : 'Could not send a reset email. Please try again.',
          );
        }
      }
      return const PasswordResetRequestResult(
        accepted: true,
        userMessage: genericAcceptedMessage,
      );
    } on AttendiphiEmailException catch (e) {
      AppLogger.warning(
        'Password reset request failed code: ${e.code}',
        tag: 'AdminPasswordReset',
      );
      return PasswordResetRequestResult(
        accepted: false,
        userMessage: e.userMessage,
      );
    } catch (_) {
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

  /// Valid when the Supabase recovery redirect established a session.
  ///
  /// [token] is only a leftover `oobCode` from legacy links; it cannot be
  /// verified, so without a session the link is treated as invalid.
  Future<PasswordResetTokenStatus> verifyToken(String token) async {
    try {
      final session = _currentSession();
      final email = (session?.user.email ?? '').trim();
      if (session == null || email.isEmpty) {
        return const PasswordResetTokenStatus(valid: false);
      }
      return PasswordResetTokenStatus(valid: true, email: email);
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
      return PasswordResetCompleteResult(success: false, userMessage: policy);
    }

    final session = _currentSession();
    if (session == null) {
      return const PasswordResetCompleteResult(
        success: false,
        invalidOrExpired: true,
        userMessage: _requestNewLinkMessage,
      );
    }

    try {
      if (updatePasswordFn != null) {
        await updatePasswordFn!(password);
      } else {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: password),
        );
      }
      await _syncAdminPasswordMetadata(
        email: session.user.email ?? '',
        password: password,
      );
      return const PasswordResetCompleteResult(success: true);
    } on AuthException catch (e) {
      return _completeError(e);
    } catch (_) {
      return const PasswordResetCompleteResult(
        success: false,
        userMessage: 'Could not reset the password. Please try again.',
      );
    }
  }

  Session? _currentSession() {
    if (currentSessionFn != null) return currentSessionFn!();
    return Supabase.instance.client.auth.currentSession;
  }

  PasswordResetCompleteResult _completeError(AuthException e) {
    final msg = e.message.toLowerCase();
    if (e.code == 'weak_password' || msg.contains('weak')) {
      return const PasswordResetCompleteResult(
        success: false,
        userMessage: 'Please choose a stronger password.',
      );
    }
    if (msg.contains('network') || msg.contains('fetch')) {
      return const PasswordResetCompleteResult(
        success: false,
        userMessage: 'Network error. Please try again.',
      );
    }
    if (msg.contains('same') && msg.contains('password')) {
      return const PasswordResetCompleteResult(
        success: false,
        userMessage: 'Please choose a different password.',
      );
    }
    return const PasswordResetCompleteResult(
      success: false,
      invalidOrExpired: true,
      userMessage: _requestNewLinkMessage,
    );
  }

  /// Hash/salt + clear must_reset_password via SECURITY DEFINER RPC
  /// (regular admins cannot UPDATE public.admins under RLS).
  Future<void> _syncAdminPasswordMetadata({
    required String email,
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    if (cleanEmail.isEmpty || updatePasswordFn != null) return;
    try {
      final salt = AdminPasswordHasher.generateSalt();
      final hash = AdminPasswordHasher.hash(password, salt);
      final client = Supabase.instance.client;
      try {
        await client.rpc('link_own_admin_auth');
      } catch (_) {}
      await client.rpc(
        'complete_own_password_reset',
        params: {'p_password_hash': hash, 'p_password_salt': salt},
      );

      final ds = SupabaseAdminRemoteDataSource();
      final admin = await ds.getAdminByEmail(cleanEmail);
      if (admin != null && admin.mustResetPassword) {
        throw StateError(
          'must_reset_password still true after complete_own_password_reset',
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Password metadata sync failed (flag may stay true): $e',
        tag: 'AdminPasswordReset',
      );
      rethrow;
    }
  }
}
