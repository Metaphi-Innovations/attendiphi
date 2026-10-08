import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/cookie_helper.dart';
import '../../../../core/utils/device_fingerprint_helper.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../presentation/providers/checkin_providers.dart';
import 'check_in_remote_data_source.dart';

/// Service managing persistent local device check-in records to ensure each device
/// can submit attendance only once per session / day.
class DeviceCheckInService {
  DeviceCheckInService([this._prefs, this._remoteDataSource]);

  final SharedPreferences? _prefs;
  final CheckInRemoteDataSource? _remoteDataSource;

  static const String _deviceIdKey = 'app_device_id';
  static const String _lastSubmissionKey = 'app_last_submission';
  static const String _sessionPrefix = 'app_session_checkin_';

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Builds a deterministic key scoped to the session date and location ID.
  String getSessionKey({String? sessionDateStr, String? locationId}) {
    final dateKey = (sessionDateStr != null && sessionDateStr.trim().isNotEmpty)
        ? sessionDateStr.trim()
        : DateFormat('yyyy-MM-dd').format(DateTime.now());
    final locKey = (locationId != null && locationId.trim().isNotEmpty)
        ? locationId.trim()
        : 'location_x';
    return '$_sessionPrefix${dateKey}_$locKey';
  }

  /// Retrieves or generates a permanent unique device ID anchored by hardware fingerprinting.
  Future<String> getOrCreateDeviceId() async {
    try {
      final fingerprint = await DeviceFingerprintHelper.getDeviceFingerprint();
      final prefs = await _getPrefs();
      String? deviceId = prefs.getString(_deviceIdKey);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = CookieHelper.getCookie(_deviceIdKey);
      }
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = fingerprint.isNotEmpty ? 'fp_$fingerprint' : const Uuid().v4();
        await prefs.setString(_deviceIdKey, deviceId);
        CookieHelper.setCookie(_deviceIdKey, deviceId);
        AppLogger.info('Generated permanent device ID: $deviceId', tag: 'DeviceCheckInService');
      } else {
        // Sync across storage mechanisms
        await prefs.setString(_deviceIdKey, deviceId);
        CookieHelper.setCookie(_deviceIdKey, deviceId);
      }
      return deviceId;
    } catch (e) {
      AppLogger.warning('Error accessing device ID from storage: $e', tag: 'DeviceCheckInService');
      final fallbackFp = await DeviceFingerprintHelper.getDeviceFingerprint();
      return fallbackFp.isNotEmpty ? 'fp_$fallbackFp' : const Uuid().v4();
    }
  }

  String _sessionDateYmd(String? sessionDateStr) {
    final s = sessionDateStr?.trim();
    if (s != null && s.length >= 10) return s.substring(0, 10);
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '${now.year}-$m-$d';
  }

  /// True only when a resolvable [CheckInSubmission] exists for this session.
  ///
  /// Cookie value `'1'` / a device lock alone is **not** attendance — those
  /// markers previously caused Approved/Success with no Firestore Present row.
  Future<bool> hasCheckedInForSession({
    String? sessionDateStr,
    String? locationId,
    bool probeServer = true,
  }) async {
    final submission = await getSubmissionForSession(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
      probeServer: probeServer,
    );
    if (submission != null) return true;

    await clearIncompleteSessionMarker(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
    );
    return false;
  }

  /// Removes lock-only / non-JSON session cookies that are not real attendance.
  Future<void> clearIncompleteSessionMarker({
    String? sessionDateStr,
    String? locationId,
  }) async {
    try {
      final key =
          getSessionKey(sessionDateStr: sessionDateStr, locationId: locationId);
      final prefs = await _getPrefs();
      final prefsVal = prefs.getString(key);
      final hasPrefsJson =
          prefsVal != null && prefsVal.trim().startsWith('{');
      if (hasPrefsJson) return;

      final cookie = CookieHelper.getCookie(key);
      if (cookie == null || cookie.isEmpty) return;

      // '1' = lock-only marker; bare UUID = id token without JSON payload.
      if (cookie == '1' || !cookie.trim().startsWith('{')) {
        CookieHelper.removeCookie(key);
        AppLogger.info(
          'Cleared incomplete session marker for "$key" (was "$cookie")',
          tag: 'DeviceCheckInService',
        );
      }
    } catch (e) {
      AppLogger.warning(
        'Error clearing incomplete session marker: $e',
        tag: 'DeviceCheckInService',
      );
    }
  }

  CheckInSubmission? _parseStoredSubmission(String? jsonStr) {
    if (jsonStr == null || jsonStr.isEmpty || jsonStr == '1') return null;
    final trimmed = jsonStr.trim();
    if (!trimmed.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      return CheckInSubmission.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Retrieves the recorded attendance submission for this session from local storage / cookies.
  Future<CheckInSubmission?> _getLocalSubmission({
    String? sessionDateStr,
    String? locationId,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key =
          getSessionKey(sessionDateStr: sessionDateStr, locationId: locationId);

      // 1. Check SharedPreferences for this specific session key
      String? jsonStr = prefs.getString(key);

      // 2. Fallback to CookieHelper (must be JSON — not '1' / bare id)
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = CookieHelper.getCookie(key);
      }

      final fromSession = _parseStoredSubmission(jsonStr);
      if (fromSession != null) return fromSession;

      // 3. Fallback to last submission if available and matches session date
      jsonStr = prefs.getString(_lastSubmissionKey);
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '1') {
        jsonStr = CookieHelper.getCookie(_lastSubmissionKey);
      }

      final sub = _parseStoredSubmission(jsonStr);
      if (sub != null) {
        if (sessionDateStr != null && sessionDateStr.trim().isNotEmpty) {
          final target = _parseSessionDate(sessionDateStr);
          if (sub.timestamp.year == target.year &&
              sub.timestamp.month == target.month &&
              sub.timestamp.day == target.day) {
            return sub;
          }
        } else {
          return sub;
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Error reading session submission from storage: $e',
        tag: 'DeviceCheckInService',
      );
    }
    return null;
  }

  /// Retrieves the submission for this session. Checks local storage first,
  /// then falls back to a Firestore server-side query by deviceId.
  Future<CheckInSubmission?> getSubmissionForSession({
    String? sessionDateStr,
    String? locationId,
    bool probeServer = true,
  }) async {
    // Try local first
    final local = await _getLocalSubmission(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
    );
    if (local != null) return local;

    // Check last submission if session date matches
    final last = await getLastSubmission();
    if (last != null) {
      if (sessionDateStr != null && sessionDateStr.trim().isNotEmpty) {
        final target = _parseSessionDate(sessionDateStr);
        if (last.timestamp.year == target.year &&
            last.timestamp.month == target.month &&
            last.timestamp.day == target.day) {
          return last;
        }
      } else {
        return last;
      }
    }

    if (!probeServer) return null;

    // Server-side fallback (works for admin-capable clients; public may be denied)
    if (_remoteDataSource != null) {
      try {
        final deviceId = await getOrCreateDeviceId();
        final sessionDate = _parseSessionDate(sessionDateStr);
        final serverSubmission = await _remoteDataSource
            .getDeviceSubmission(
              deviceId,
              sessionDate,
            )
            .timeout(
              const Duration(milliseconds: 1500),
              onTimeout: () => null,
            );
        if (serverSubmission != null) {
          await recordSubmission(
            sessionDateStr: sessionDateStr,
            submission: serverSubmission,
          );
          return serverSubmission;
        }

        // Lock without a readable check-in → incomplete attempt; do not treat
        // as checked-in. Clear any local '1' marker so the member can retry.
        final sessionDateYmd = _sessionDateYmd(sessionDateStr);
        final isLocked = await _remoteDataSource
            .isDeviceSessionLocked(
              deviceId: deviceId,
              sessionDateYmd: sessionDateYmd,
            )
            .timeout(
              const Duration(milliseconds: 2000),
              onTimeout: () => false,
            );
        if (isLocked) {
          AppLogger.warning(
            'Device session lock exists without resolvable check-in '
            '($deviceId / $sessionDateYmd) — treating as incomplete',
            tag: 'DeviceCheckInService',
          );
          await clearIncompleteSessionMarker(
            sessionDateStr: sessionDateStr,
            locationId: locationId,
          );
        }
      } catch (e) {
        AppLogger.warning(
          'Server-side submission retrieval failed: $e',
          tag: 'DeviceCheckInService',
        );
      }
    }

    return null;
  }

  /// Checks if this device has any attendance submission recorded.
  Future<bool> hasAnySubmission() async {
    final sub = await getLastSubmission();
    return sub != null;
  }

  /// Persists a successful attendance submission locally on this device.
  Future<void> recordSubmission({
    String? sessionDateStr,
    required CheckInSubmission submission,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = getSessionKey(
        sessionDateStr: sessionDateStr,
        locationId: submission.locationId,
      );
      // Strip base64 photo before saving to local storage to prevent QuotaExceeded errors
      final storageSubmission = submission.copyWith(photoBase64: '');
      final jsonStr = jsonEncode(storageSubmission.toMap());
      // Persist full submission in local SharedPreferences storage
      await prefs.setString(key, jsonStr);
      await prefs.setString(_lastSubmissionKey, jsonStr);

      // Lightweight id token in cookies only — never treat this as a full
      // submission (see hasCheckedInForSession / _parseStoredSubmission).
      CookieHelper.setCookie(key, submission.id);
      CookieHelper.setCookie(_lastSubmissionKey, submission.id);

      AppLogger.info(
        'Recorded check-in on device for session "$key" (${submission.userName})',
        tag: 'DeviceCheckInService',
      );
    } catch (e) {
      AppLogger.warning(
        'Error saving check-in to device storage: $e',
        tag: 'DeviceCheckInService',
      );
    }
  }

  /// Retrieves the most recent submission performed on this device.
  Future<CheckInSubmission?> getLastSubmission() async {
    try {
      final prefs = await _getPrefs();
      String? jsonStr = prefs.getString(_lastSubmissionKey);
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '1') {
        jsonStr = CookieHelper.getCookie(_lastSubmissionKey);
      }
      return _parseStoredSubmission(jsonStr);
    } catch (e) {
      AppLogger.warning(
        'Error reading last submission: $e',
        tag: 'DeviceCheckInService',
      );
    }
    return null;
  }

  /// Clears stored session records on this device (e.g. for testing / debugging).
  Future<void> clearSessionRecords() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs
          .getKeys()
          .where((k) => k.startsWith(_sessionPrefix) || k == _lastSubmissionKey);
      for (final key in keys) {
        await prefs.remove(key);
        CookieHelper.removeCookie(key);
      }
      CookieHelper.removeCookie(_lastSubmissionKey);
    } catch (e) {
      AppLogger.warning(
        'Error clearing device session records: $e',
        tag: 'DeviceCheckInService',
      );
    }
  }

  DateTime _parseSessionDate(String? sessionDateStr) {
    if (sessionDateStr != null && sessionDateStr.trim().isNotEmpty) {
      return DateTime.tryParse(sessionDateStr.trim()) ?? DateTime.now();
    }
    return DateTime.now();
  }
}

/// Provider for [SharedPreferences] (can be overridden in tests).
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Riverpod provider for [DeviceCheckInService].
final deviceCheckInServiceProvider = Provider<DeviceCheckInService>((ref) {
  CheckInRemoteDataSource? remoteDataSource;
  try {
    remoteDataSource = ref.watch(checkInRemoteDataSourceProvider);
  } catch (_) {}
  return DeviceCheckInService(
    ref.watch(sharedPreferencesProvider),
    remoteDataSource,
  );
});
