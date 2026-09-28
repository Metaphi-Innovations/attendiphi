import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qr_checkin/core/config/supabase_email_config.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/firebase_options.dart';
import 'package:qr_checkin/services/attendiphi_email_service.dart';

void main() {
  const admin = AdminUser(
    id: 'adm-1',
    name: 'Test Admin',
    email: 'newadmin@example.com',
    phone: '9876543210',
  );

  test('posts Firebase bearer token and never includes SMTP secrets', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'ok': true, 'id': 'smtp-123'}), 200);
    });

    final service = AttendiphiEmailService(
      httpClient: client,
      idTokenFn: () async => 'firebase-id-token',
      readBrowserConfigFn: () async => const BrowserSupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ),
    );

    final result = await service.sendAdminWelcome(
      admin: admin,
      password: 'TempPass1!',
    );

    expect(result.success, isTrue);
    expect(result.messageId, 'smtp-123');
    expect(captured.headers['Authorization'], 'Bearer firebase-id-token');
    expect(captured.headers['apikey'], 'public-anon-key');
    expect(captured.url.path, endsWith('/functions/v1/send-attendiphi-email'));
    expect(captured.body.contains('SMTP_PASSWORD'), isFalse);
    expect(captured.body.contains('RESEND'), isFalse);
    expect(captured.body.contains('admin_welcome'), isTrue);
    expect(captured.body.contains('TempPass1!'), isTrue);
  });

  test('returns failure for non-2xx Edge Function responses', () async {
    final client = MockClient((request) async {
      return http.Response(jsonEncode({'ok': false, 'error': 'nope'}), 401);
    });
    final service = AttendiphiEmailService(
      httpClient: client,
      idTokenFn: () async => 'firebase-id-token',
      readBrowserConfigFn: () async => const BrowserSupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ),
    );

    final result = await service.sendAdminWelcome(
      admin: admin,
      password: 'TempPass1!',
    );
    expect(result.success, isFalse);
    expect(result.statusCode, 401);
    expect(result.userMessage, 'nope');
  });

  test('password reset posts type and email without secrets or a Firebase token',
      () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({
          'ok': true,
          'emailType': 'password_reset',
          'message':
              'If an account exists for this email, a password reset link has been sent.',
        }),
        200,
      );
    });

    final service = AttendiphiEmailService(
      httpClient: client,
      idTokenFn: () async => 'must-not-be-sent',
      readBrowserConfigFn: () async => const BrowserSupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ),
    );

    final result = await service.requestPasswordReset(
      email: 'locked-out@example.com',
    );

    expect(result.success, isTrue);
    expect(result.userMessage, contains('If an account exists'));
    expect(captured.headers['Authorization'], 'Bearer public-anon-key');
    expect(captured.headers['apikey'], 'public-anon-key');
    expect(captured.body.contains('must-not-be-sent'), isFalse);
    expect(captured.body.contains('RESEND'), isFalse);
    expect(captured.body.contains('private_key'), isFalse);
    expect(captured.body.contains('password_reset'), isTrue);
    expect(captured.body.contains('locked-out@example.com'), isTrue);
    expect(jsonDecode(captured.body)['password'], isNull);
  });

  test('password reset maps 429 without leaking whether the user exists',
      () async {
    final service = AttendiphiEmailService(
      httpClient: MockClient((request) async {
        return http.Response(jsonEncode({'ok': false, 'error': 'limited'}), 429);
      }),
      readBrowserConfigFn: () async => const BrowserSupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ),
    );
    final result = await service.requestPasswordReset(email: 'a@b.com');
    expect(result.success, isFalse);
    expect(result.statusCode, 429);
    expect(result.userMessage.toLowerCase().contains('not found'), isFalse);
  });

  test('deleteAuthAdmin posts delete_admin action with Bearer token', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode({'ok': true, 'deleted': true, 'message': 'Deleted successfully'}),
        200,
      );
    });

    final service = AttendiphiEmailService(
      httpClient: client,
      idTokenFn: () async => 'firebase-id-token',
      readBrowserConfigFn: () async => const BrowserSupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ),
    );

    final result = await service.deleteAuthAdmin(
      uid: 'uid-to-delete',
      email: 'delete-me@example.com',
    );

    expect(result.success, isTrue);
    expect(result.userMessage, 'Deleted successfully');
    expect(captured.headers['Authorization'], 'Bearer firebase-id-token');
    expect(captured.headers['apikey'], 'public-anon-key');
    expect(captured.url.path, endsWith('/functions/v1/send-attendiphi-email'));
    final body = jsonDecode(captured.body) as Map<String, dynamic>;
    expect(body['action'], 'delete_admin');
    expect(body['targetUid'], 'uid-to-delete');
    expect(body['email'], 'delete-me@example.com');
  });

  test('deleteAuthAdmin returns failure when server returns non-2xx', () async {
    final client = MockClient((request) async {
      return http.Response(
        jsonEncode({'ok': false, 'error': 'Permission denied'}),
        403,
      );
    });

    final service = AttendiphiEmailService(
      httpClient: client,
      idTokenFn: () async => 'firebase-id-token',
      readBrowserConfigFn: () async => const BrowserSupabaseConfig(
        url: 'https://example.supabase.co',
        anonKey: 'public-anon-key',
      ),
    );

    final result = await service.deleteAuthAdmin(
      uid: 'uid-to-delete',
    );

    expect(result.success, isFalse);
    expect(result.userMessage, 'Permission denied');
  });

  test('Firebase project used for tokens is qr-checkin-dev', () {
    expect(DefaultFirebaseOptions.web.projectId, 'qr-checkin-dev');
    expect(SupabaseEmailConfig.firebaseProjectId, 'qr-checkin-dev');
    expect(attendiphiFirebaseProjectId(), 'qr-checkin-dev');
    expect(
      SupabaseEmailConfig.productionUrl,
      'https://ktnhyohshdwqvvlgeynp.supabase.co',
    );
  });
}

