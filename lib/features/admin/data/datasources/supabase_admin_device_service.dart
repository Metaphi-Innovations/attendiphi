import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/config/supabase_bootstrap.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/notifications/notification_service.dart';
import 'admin_device_registrar.dart';

/// Registers admin FCM tokens in Supabase `admin_devices` and polls
/// `check_ins` for local alert notifications (FCM delivery still uses the
/// Firebase Messaging SDK).
class SupabaseAdminDeviceService implements AdminDeviceRegistrar {
  SupabaseAdminDeviceService({
    required this.notificationService,
    SupabaseClient? client,
  }) : _clientOverride = client;

  final NotificationService notificationService;
  final SupabaseClient? _clientOverride;

  StreamSubscription<String>? _tokenRefreshSubscription;
  Timer? _pollTimer;
  String? _registeredToken;
  final Set<String> _knownCheckInIds = <String>{};
  bool _primed = false;

  SupabaseClient get _client {
    final override = _clientOverride;
    if (override != null) return override;
    if (!SupabaseBootstrap.isInitialized) {
      throw StateError('Supabase not initialized (admin_devices)');
    }
    return Supabase.instance.client;
  }

  @override
  Future<void> registerAdminDevice({
    required String adminEmail,
    String? uid,
  }) async {
    if (kIsWeb) return;

    try {
      final granted = await notificationService.requestPermissions();
      if (!granted) {
        AppLogger.warning(
          'Notification permission was not granted for Admin device.',
          tag: 'SupabaseAdminDeviceService',
        );
      }

      final token = await notificationService.getDeviceToken();
      if (token != null && token.isNotEmpty) {
        await _saveDeviceToken(token: token, adminEmail: adminEmail, uid: uid);
      }

      _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = notificationService.onTokenRefresh.listen((
        newToken,
      ) async {
        await _saveDeviceToken(
          token: newToken,
          adminEmail: adminEmail,
          uid: uid,
        );
      });

      _startAttendancePoll();
    } catch (e, st) {
      AppLogger.error(
        'Failed to register admin device (Supabase): $e',
        error: e,
        stackTrace: st,
        tag: 'SupabaseAdminDeviceService',
      );
    }
  }

  void _startAttendancePoll() {
    _pollTimer?.cancel();
    _primed = false;
    _knownCheckInIds.clear();
    unawaited(_pollOnce());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      unawaited(_pollOnce());
    });
  }

  Future<void> _pollOnce() async {
    try {
      final rows = await _client
          .from('check_ins')
          .select('id,user_name,type,location_name,user_phone')
          .order('created_at', ascending: false)
          .limit(80);

      if (!_primed) {
        for (final row in rows) {
          final id = row['id']?.toString();
          if (id != null) _knownCheckInIds.add(id);
        }
        _primed = true;
        AppLogger.info(
          'Admin notification poll primed with ${_knownCheckInIds.length} records.',
          tag: 'SupabaseAdminDeviceService',
        );
        return;
      }

      for (final row in rows) {
        final id = row['id']?.toString();
        if (id == null || _knownCheckInIds.contains(id)) continue;
        _knownCheckInIds.add(id);
        final userName = row['user_name']?.toString() ?? 'Attendee';
        final type = row['type']?.toString() ?? 'Member';
        final locationName = row['location_name']?.toString() ?? 'Venue';
        final title = '🔔 New Attendance: $userName';
        final body = '$userName ($type) checked in at $locationName.';
        await notificationService.showLocalNotification(
          id: id.hashCode,
          title: title,
          body: body,
          payload: jsonEncode({
            'submissionId': id,
            'title': title,
            'body': body,
            'userName': userName,
            'type': type,
            'locationName': locationName,
            'userPhone': row['user_phone']?.toString() ?? '',
          }),
        );
      }
    } catch (e) {
      AppLogger.error(
        'Error polling check_ins for admin alerts: $e',
        tag: 'SupabaseAdminDeviceService',
      );
    }
  }

  Future<void> _saveDeviceToken({
    required String token,
    required String adminEmail,
    String? uid,
  }) async {
    try {
      _registeredToken = token;
      final platform = kIsWeb
          ? 'web'
          : Platform.isIOS
          ? 'ios'
          : Platform.isAndroid
          ? 'android'
          : 'other';

      await _client.from('admin_devices').upsert({
        'id': token,
        'raw': {
          'deviceId': token,
          'pushProvider': 'local', // not FCM
          'uid': uid ?? '',
          'adminEmail': adminEmail,
          'platform': platform,
          'isActive': true,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });

      AppLogger.info(
        'Admin device id registered (Supabase, no FCM) for $adminEmail on $platform',
        tag: 'SupabaseAdminDeviceService',
      );
    } catch (e, st) {
      AppLogger.error(
        'Failed to save token to Supabase: $e',
        error: e,
        stackTrace: st,
        tag: 'SupabaseAdminDeviceService',
      );
    }
  }

  @override
  Future<void> unregisterAdminDevice() async {
    if (kIsWeb) return;

    try {
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _pollTimer?.cancel();
      _pollTimer = null;

      if (_registeredToken != null) {
        await _client.from('admin_devices').upsert({
          'id': _registeredToken,
          'raw': {
            'token': _registeredToken,
            'isActive': false,
            'loggedOutAt': DateTime.now().toUtc().toIso8601String(),
          },
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
        _registeredToken = null;
      }
    } catch (e, st) {
      AppLogger.error(
        'Error unregistering admin device (Supabase): $e',
        error: e,
        stackTrace: st,
        tag: 'SupabaseAdminDeviceService',
      );
    }
  }

  @override
  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _pollTimer?.cancel();
  }
}
