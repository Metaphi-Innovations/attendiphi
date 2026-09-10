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

  /// Checks whether this device has already submitted attendance for the specified session.
  /// First checks local storage/cookies, then falls back to a Firestore server-side query.
  Future<bool> hasCheckedInForSession({
    String? sessionDateStr,
    String? locationId,
  }) async {
    // 1. Fast local check via cookie
    final key = getSessionKey(sessionDateStr: sessionDateStr, locationId: locationId);
    if (CookieHelper.hasCookie(key)) {
      return true;
    }

    // 2. Check local SharedPreferences
    final submission = await _getLocalSubmission(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
    );
    if (submission != null) return true;

    // 3. Server-side fallback: query Firestore by deviceId (critical for iOS)
    if (_remoteDataSource != null) {
      try {
        final deviceId = await getOrCreateDeviceId();
        final sessionDate = _parseSessionDate(sessionDateStr);
        final serverSubmission = await _remoteDataSource.getDeviceSubmission(
          deviceId,
          sessionDate,
        );
        if (serverSubmission != null) {
          // Re-persist locally so future checks are fast
          await recordSubmission(
            sessionDateStr: sessionDateStr,
            submission: serverSubmission,
          );
          return true;
        }
      } catch (e) {
        AppLogger.warning(
          'Server-side device check failed: $e',
          tag: 'DeviceCheckInService',
        );
      }
    }

    return false;
  }

  /// Retrieves the recorded attendance submission for this session from local storage / cookies.
  Future<CheckInSubmission?> _getLocalSubmission({
    String? sessionDateStr,
    String? locationId,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = getSessionKey(sessionDateStr: sessionDateStr, locationId: locationId);
      
      // 1. Check SharedPreferences for this specific session key
      String? jsonStr = prefs.getString(key);

      // 2. Fallback to CookieHelper (which checks cookies, window.localStorage, window.sessionStorage)
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = CookieHelper.getCookie(key);
      }

      if (jsonStr != null && jsonStr.isNotEmpty && jsonStr != '1') {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return CheckInSubmission.fromMap(map);
      }

      // 3. Fallback to last submission if available and matches session date
      jsonStr = prefs.getString(_lastSubmissionKey);
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = CookieHelper.getCookie(_lastSubmissionKey);
      }

      if (jsonStr != null && jsonStr.isNotEmpty && jsonStr != '1') {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        final sub = CheckInSubmission.fromMap(map);
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
      AppLogger.warning('Error reading session submission from storage: $e', tag: 'DeviceCheckInService');
    }
    return null;
  }

  /// Retrieves the submission for this session. Checks local storage first,
  /// then falls back to a Firestore server-side query by deviceId.
  Future<CheckInSubmission?> getSubmissionForSession({
    String? sessionDateStr,
    String? locationId,
  }) async {
    // Try local first
    final local = await _getLocalSubmission(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
    );
    if (local != null) return local;

    // Server-side fallback
    if (_remoteDataSource != null) {
      try {
        final deviceId = await getOrCreateDeviceId();
        final sessionDate = _parseSessionDate(sessionDateStr);
        final serverSubmission = await _remoteDataSource.getDeviceSubmission(
          deviceId,
          sessionDate,
        );
        if (serverSubmission != null) {
          // Re-persist locally
          await recordSubmission(
            sessionDateStr: sessionDateStr,
            submission: serverSubmission,
          );
          return serverSubmission;
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
    if (CookieHelper.hasCookie(_lastSubmissionKey)) return true;
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
      
      // Persist lightweight token in cookies (<50 bytes) to prevent cookie header bloat or truncation
      CookieHelper.setCookie(key, submission.id);
      CookieHelper.setCookie(_lastSubmissionKey, submission.id);

      AppLogger.info(
        'Recorded check-in on device for session "$key" (${submission.userName})',
        tag: 'DeviceCheckInService',
      );
    } catch (e) {
      AppLogger.warning('Error saving check-in to device storage: $e', tag: 'DeviceCheckInService');
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
      if (jsonStr != null && jsonStr.isNotEmpty && jsonStr != '1') {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return CheckInSubmission.fromMap(map);
      }
    } catch (e) {
      AppLogger.warning('Error reading last submission: $e', tag: 'DeviceCheckInService');
    }
    return null;
  }

  /// Clears stored session records on this device (e.g. for testing / debugging).
  Future<void> clearSessionRecords() async {
    try {
      final prefs = await _getPrefs();
      final keys = prefs.getKeys().where((k) => k.startsWith(_sessionPrefix) || k == _lastSubmissionKey);
      for (final key in keys) {
        await prefs.remove(key);
        CookieHelper.removeCookie(key);
      }
      CookieHelper.removeCookie(_lastSubmissionKey);
    } catch (e) {
      AppLogger.warning('Error clearing device session records: $e', tag: 'DeviceCheckInService');
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
