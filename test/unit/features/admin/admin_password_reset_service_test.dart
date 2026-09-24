import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_checkin/core/config/supabase_email_config.dart';
import 'package:qr_checkin/core/utils/validators.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_password_reset_service.dart';
import 'package:qr_checkin/features/admin/domain/admin_password_hasher.dart';
import 'package:qr_checkin/services/attendiphi_email_service.dart';

void main() {
  test('invalid email is rejected before any network call', () async {
    var called = false;
    final service = AdminPasswordResetService(
      sendPasswordResetEmailFn: (email) async {
        called = true;
      },
    );

    final result = await service.requestReset(email: 'not-an-email');

    expect(result.accepted, isFalse);
    expect(result.userMessage, Validators.validateEmail('not-an-email'));
    expect(called, isFalse);
  });

  test('unknown emails still return the generic accepted message', () async {
    final service = AdminPasswordResetService(
      emailService: AttendiphiEmailService(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'ok': true,
              'emailType': 'password_reset',
              'message':
                  'If an account exists for this email, a password reset link has been sent.',
            }),
            200,
          );
        }),
        readBrowserConfigFn: () async => const BrowserSupabaseConfig(
          url: 'https://example.supabase.co',
          anonKey: 'public-anon-key',
        ),
      ),
    );

    final result = await service.requestReset(email: 'unknown@example.com');
    expect(result.accepted, isTrue);
    expect(result.userMessage, contains('If an account exists for this email'));
    expect(result.userMessage.toLowerCase().contains('not found'), isFalse);
    expect(result.userMessage.toLowerCase().contains('does not exist'), isFalse);
  });

  test('rate-limit responses are not treated as user-not-found', () async {
    final service = AdminPasswordResetService(
      emailService: AttendiphiEmailService(
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({'ok': false, 'error': 'Too many attempts'}),
            429,
          );
        }),
        readBrowserConfigFn: () async => const BrowserSupabaseConfig(
          url: 'https://example.supabase.co',
          anonKey: 'public-anon-key',
        ),
      ),
    );

    final result = await service.requestReset(email: 'admin@example.com');
    expect(result.accepted, isFalse);
    expect(result.userMessage, contains('Too many attempts'));
  });

  test('missing oobCode is invalid', () async {
    final status = await AdminPasswordResetService().verifyToken('  ');
    expect(status.valid, isFalse);
  });

  test('invalid oobCode is reported as invalid', () async {
    final service = AdminPasswordResetService(
      verifyPasswordResetCodeFn: (code) async {
        throw FirebaseAuthException(code: 'invalid-action-code');
      },
    );
    final status = await service.verifyToken('bad-code');
    expect(status.valid, isFalse);
  });

  test('expired oobCode is reported as invalid', () async {
    final service = AdminPasswordResetService(
      verifyPasswordResetCodeFn: (code) async {
        throw FirebaseAuthException(code: 'expired-action-code');
      },
    );
    final status = await service.verifyToken('expired-code');
    expect(status.valid, isFalse);
  });

  test('weak password is rejected before confirmPasswordReset', () async {
    var confirmed = false;
    final service = AdminPasswordResetService(
      verifyPasswordResetCodeFn: (code) async => 'admin@example.com',
      confirmPasswordResetFn: ({required code, required newPassword}) async {
        confirmed = true;
      },
    );
    final result = await service.completeReset(
      token: 'oob',
      newPassword: 'short',
    );
    expect(result.success, isFalse);
    expect(result.userMessage, AdminPasswordHasher.policyError('short'));
    expect(confirmed, isFalse);
  });

  test('successful confirmPasswordReset updates Firebase Auth only', () async {
    var confirmedPassword = '';
    final service = AdminPasswordResetService(
      verifyPasswordResetCodeFn: (code) async {
        expect(code, 'good-oob');
        return 'admin@example.com';
      },
      confirmPasswordResetFn: ({required code, required newPassword}) async {
        confirmedPassword = newPassword;
      },
    );

    final result = await service.completeReset(
      token: 'good-oob',
      newPassword: 'NewPass@12',
    );
    expect(result.success, isTrue);
    expect(confirmedPassword, 'NewPass@12');
  });

  test('expired confirmPasswordReset is marked invalidOrExpired', () async {
    final service = AdminPasswordResetService(
      verifyPasswordResetCodeFn: (code) async => 'admin@example.com',
      confirmPasswordResetFn: ({required code, required newPassword}) async {
        throw FirebaseAuthException(code: 'expired-action-code');
      },
    );
    final result = await service.completeReset(
      token: 'expired',
      newPassword: 'NewPass@12',
    );
    expect(result.success, isFalse);
    expect(result.invalidOrExpired, isTrue);
    expect(result.userMessage.toLowerCase(), contains('expired'));
  });

  test('network failures do not expose internals', () async {
    final service = AdminPasswordResetService(
      verifyPasswordResetCodeFn: (code) async => 'admin@example.com',
      confirmPasswordResetFn: ({required code, required newPassword}) async {
        throw FirebaseAuthException(code: 'network-request-failed');
      },
    );
    final result = await service.completeReset(
      token: 'oob',
      newPassword: 'NewPass@12',
    );
    expect(result.success, isFalse);
    expect(result.userMessage.toLowerCase(), contains('network'));
    expect(result.userMessage.toLowerCase().contains('stack'), isFalse);
    expect(result.userMessage.contains('RESEND'), isFalse);
  });
}
