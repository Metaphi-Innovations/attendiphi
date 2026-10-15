import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/validators.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_password_reset_service.dart';
import 'package:qr_checkin/features/admin/domain/admin_password_hasher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

User _recoveryUser({String email = 'admin@example.com'}) {
  return User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
    email: email,
  );
}

Session _recoverySession({String email = 'admin@example.com'}) {
  return Session(
    accessToken: 'access-token',
    tokenType: 'bearer',
    user: _recoveryUser(email: email),
  );
}

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

  test(
    'valid email invokes Supabase reset hook and returns generic message',
    () async {
      final resetEmails = <String>[];
      final service = AdminPasswordResetService(
        sendPasswordResetEmailFn: (email) async {
          resetEmails.add(email);
        },
      );

      final result = await service.requestReset(email: 'Unknown@Example.com');

      expect(result.accepted, isTrue);
      expect(resetEmails, ['unknown@example.com']);
      expect(
        result.userMessage,
        AdminPasswordResetService.genericAcceptedMessage,
      );
      expect(result.userMessage.toLowerCase().contains('not found'), isFalse);
    },
  );

  test('verifyToken is invalid without a recovery session', () async {
    final service = AdminPasswordResetService(currentSessionFn: () => null);
    final status = await service.verifyToken('legacy-oob');
    expect(status.valid, isFalse);
    expect(status.email, isEmpty);
  });

  test('verifyToken is valid when recovery session has email', () async {
    final service = AdminPasswordResetService(
      currentSessionFn: _recoverySession,
    );
    final status = await service.verifyToken('ignored');
    expect(status.valid, isTrue);
    expect(status.email, 'admin@example.com');
  });

  test('weak password is rejected before updatePassword', () async {
    var updated = false;
    final service = AdminPasswordResetService(
      currentSessionFn: _recoverySession,
      updatePasswordFn: (newPassword) async {
        updated = true;
      },
    );
    final result = await service.completeReset(
      token: 'oob',
      newPassword: 'short',
    );
    expect(result.success, isFalse);
    expect(result.userMessage, AdminPasswordHasher.policyError('short'));
    expect(updated, isFalse);
  });

  test('completeReset updates password when session is present', () async {
    var confirmedPassword = '';
    final service = AdminPasswordResetService(
      currentSessionFn: _recoverySession,
      updatePasswordFn: (newPassword) async {
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

  test('completeReset without session is invalidOrExpired', () async {
    final service = AdminPasswordResetService(
      currentSessionFn: () => null,
      updatePasswordFn: (newPassword) async {},
    );
    final result = await service.completeReset(
      token: 'expired',
      newPassword: 'NewPass@12',
    );
    expect(result.success, isFalse);
    expect(result.invalidOrExpired, isTrue);
    expect(result.userMessage.toLowerCase(), contains('no longer valid'));
  });

  test(
    'network failures from updatePassword do not expose internals',
    () async {
      final service = AdminPasswordResetService(
        currentSessionFn: _recoverySession,
        updatePasswordFn: (newPassword) async {
          throw const AuthException('Network request failed');
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
    },
  );
}
