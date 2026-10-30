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

/// Whether this phone/browser already completed (or locked) check-in for a session.
class DeviceSessionAttendance {
  const DeviceSessionAttendance._({
    this.submission,
    this.claimedWithoutPayload = false,
  });

  factory DeviceSessionAttendance.found(CheckInSubmission submission) {
    return DeviceSessionAttendance._(submission: submission);
  }

  /// Server device lock exists but the prior row is not readable (anon RLS).
  factory DeviceSessionAttendance.claimedWithoutPayload() {
    return const DeviceSessionAttendance._(claimedWithoutPayload: true);
  }

  static const none = DeviceSessionAttendance._();

  final CheckInSubmission? submission;
  final bool claimedWithoutPayload;

  /// True when the UI must skip the form and show Attendance Recorded.
  bool get alreadyCheckedIn => submission != null || claimedWithoutPayload;
}

/// Service managing persistent local device check-in records to ensure each device
/// can submit attendance only once per session / day.
class DeviceCheckInService {
  DeviceCheckInService([this._prefs, this._remoteDataSource]);

  final SharedPreferences? _prefs;
  final CheckInRemoteDataSource? _remoteDataSource;

  static const String _deviceIdKey = 'app_device_id';
  static const String _lastSubmissionKey = 'app_last_submission';
  static const String _sessionPrefix = 'app_session_checkin_';

  /// Cookies/localStorage ~4KB; keep JSON under this to avoid silent drop.
  static const int _maxCookiePayloadChars = 3500;

  Future<SharedPreferences> _getPrefs() async {
    return _prefs ?? await SharedPreferences.getInstance();
  }

  /// Normalizes QR/session date strings to `yyyy-MM-dd` so storage keys match.
  String normalizeSessionDateKey(String? sessionDateStr) {
    final s = sessionDateStr?.trim() ?? '';
    if (s.length >= 10) {
      final ymd = s.substring(0, 10);
      if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(ymd)) return ymd;
    }
    return DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  /// Builds a deterministic key scoped to the session date and location ID.
  String getSessionKey({String? sessionDateStr, String? locationId}) {
    final dateKey = normalizeSessionDateKey(sessionDateStr);
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
        deviceId = fingerprint.isNotEmpty
            ? 'fp_$fingerprint'
            : const Uuid().v4();
        await prefs.setString(_deviceIdKey, deviceId);
        CookieHelper.setCookie(_deviceIdKey, deviceId);
        AppLogger.info(
          'Generated permanent device ID: $deviceId',
          tag: 'DeviceCheckInService',
        );
      } else {
        // Sync across storage mechanisms
        await prefs.setString(_deviceIdKey, deviceId);
        CookieHelper.setCookie(_deviceIdKey, deviceId);
      }
      return deviceId;
    } catch (e) {
      AppLogger.warning(
        'Error accessing device ID from storage: $e',
        tag: 'DeviceCheckInService',
      );
      final fallbackFp = await DeviceFingerprintHelper.getDeviceFingerprint();
      return fallbackFp.isNotEmpty ? 'fp_$fallbackFp' : const Uuid().v4();
    }
  }

  String _sessionDateYmd(String? sessionDateStr) =>
      normalizeSessionDateKey(sessionDateStr);

  /// True only when this device should be treated as already checked in.
  Future<bool> hasCheckedInForSession({
    String? sessionDateStr,
    String? locationId,
    bool probeServer = true,
  }) async {
    final attendance = await resolveSessionAttendance(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
      probeServer: probeServer,
    );
    if (attendance.alreadyCheckedIn) return true;

    await clearIncompleteSessionMarker(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
    );
    return false;
  }

  /// Resolves prior attendance for early QR gates (form / location screens).
  Future<DeviceSessionAttendance> resolveSessionAttendance({
    String? sessionDateStr,
    String? locationId,
    bool probeServer = true,
  }) async {
    final key = getSessionKey(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
    );
    AppLogger.info(
      'resolveSessionAttendance key=$key '
      'date=${normalizeSessionDateKey(sessionDateStr)} '
      'location=${locationId ?? "(default)"} probeServer=$probeServer',
      tag: 'DeviceCheckInService',
    );

    final submission = await getSubmissionForSession(
      sessionDateStr: sessionDateStr,
      locationId: locationId,
      probeServer: probeServer,
    );
    if (submission != null) {
      return DeviceSessionAttendance.found(submission);
    }

    if (!probeServer || _remoteDataSource == null) {
      return DeviceSessionAttendance.none;
    }

    // getSubmissionForSession already probed the row; re-check lock only.
    try {
      final deviceId = await getOrCreateDeviceId();
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
        AppLogger.info(
          'Device session locked without readable check-in '
          '($deviceId / $sessionDateYmd) — treating as already checked in',
          tag: 'DeviceCheckInService',
        );
        return DeviceSessionAttendance.claimedWithoutPayload();
      }
    } catch (e) {
      AppLogger.warning(
        'Device lock probe failed: $e',
        tag: 'DeviceCheckInService',
      );
    }
    return DeviceSessionAttendance.none;
  }

  /// Removes lock-only / non-JSON session cookies that are not real attendance.
  Future<void> clearIncompleteSessionMarker({
    String? sessionDateStr,
    String? locationId,
  }) async {
    try {
      final key = getSessionKey(
        sessionDateStr: sessionDateStr,
        locationId: locationId,
      );
      final prefs = await _getPrefs();
      final prefsVal = prefs.getString(key);
      final hasPrefsJson = prefsVal != null && prefsVal.trim().startsWith('{');
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

  bool _matchesSessionDate(CheckInSubmission sub, String? sessionDateStr) {
    if (sessionDateStr == null || sessionDateStr.trim().isEmpty) return true;
    final target = _parseSessionDate(sessionDateStr);
    return sub.timestamp.year == target.year &&
        sub.timestamp.month == target.month &&
        sub.timestamp.day == target.day;
  }

  /// Retrieves the recorded attendance submission for this session from local storage / cookies.
  Future<CheckInSubmission?> _getLocalSubmission({
    String? sessionDateStr,
    String? locationId,
  }) async {
    try {
      final prefs = await _getPrefs();
      final key = getSessionKey(
        sessionDateStr: sessionDateStr,
        locationId: locationId,
      );

      // 1. Check SharedPreferences for this specific session key
      String? jsonStr = prefs.getString(key);
      var source = 'prefs';

      // 2. Fallback to CookieHelper / localStorage (must be JSON — not '1' / bare id)
      if (jsonStr == null || jsonStr.isEmpty) {
        jsonStr = CookieHelper.getCookie(key);
        source = 'cookie';
      }

      final fromSession = _parseStoredSubmission(jsonStr);
      if (fromSession != null) {
        AppLogger.info(
          'Local session hit via $source for "$key"',
          tag: 'DeviceCheckInService',
        );
        return fromSession;
      }

      // 3. Fallback to last submission if available and matches session date
      jsonStr = prefs.getString(_lastSubmissionKey);
      source = 'prefs-last';
      if (jsonStr == null || jsonStr.isEmpty || jsonStr == '1') {
        jsonStr = CookieHelper.getCookie(_lastSubmissionKey);
        source = 'cookie-last';
      }

      final sub = _parseStoredSubmission(jsonStr);
      if (sub != null && _matchesSessionDate(sub, sessionDateStr)) {
        // Also require same location when we know it.
        final loc = locationId?.trim() ?? '';
        if (loc.isEmpty || sub.locationId == loc) {
          AppLogger.info(
            'Local last-submission hit via $source for session date',
            tag: 'DeviceCheckInService',
          );
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
  /// then falls back to a server-side query by deviceId.
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
    if (last != null && _matchesSessionDate(last, sessionDateStr)) {
      final loc = locationId?.trim() ?? '';
      if (loc.isEmpty || last.locationId == loc) return last;
    }

    if (!probeServer) return null;

    // Server-side fallback (works for admin-capable clients; public may be denied)
    if (_remoteDataSource != null) {
      try {
        final deviceId = await getOrCreateDeviceId();
        final sessionDate = _parseSessionDate(sessionDateStr);
        final serverSubmission = await _remoteDataSource
            .getDeviceSubmission(deviceId, sessionDate)
            .timeout(const Duration(milliseconds: 1500), onTimeout: () => null);
        if (serverSubmission != null) {
          await recordSubmission(
            sessionDateStr: sessionDateStr,
            submission: serverSubmission,
          );
          return serverSubmission;
        }

        // Lock without a readable check-in is handled by resolveSessionAttendance
        // (show success). Do not clear local markers here — that caused the form
        // to reopen on second QR scan when RLS blocks check_ins reads.
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
          AppLogger.info(
            'Device session lock exists without resolvable check-in '
            '($deviceId / $sessionDateYmd)',
            tag: 'DeviceCheckInService',
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

  void _persistCookiePayload(String key, String jsonStr) {
    if (jsonStr.length <= _maxCookiePayloadChars) {
      CookieHelper.setCookie(key, jsonStr);
    } else {
      // Fall back to id-only token when JSON is too large for cookies.
      AppLogger.warning(
        'Session payload too large for cookie (${jsonStr.length} chars); '
        'storing id token only for "$key"',
        tag: 'DeviceCheckInService',
      );
    }
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

      // Also persist JSON via CookieHelper (cookie + localStorage + sessionStorage)
      // so Safari / ephemeral WebViews still recover the first check-in on re-scan.
      _persistCookiePayload(key, jsonStr);
      _persistCookiePayload(_lastSubmissionKey, jsonStr);

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
      final keys = prefs.getKeys().where(
        (k) => k.startsWith(_sessionPrefix) || k == _lastSubmissionKey,
      );
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
    final ymd = normalizeSessionDateKey(sessionDateStr);
    return DateTime.tryParse(ymd) ?? DateTime.now();
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
