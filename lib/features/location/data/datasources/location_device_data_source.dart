import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:geolocator/geolocator.dart'
    as geo
    show LocationServiceDisabledException;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/permissions/permission_service.dart';

/// Contract for fetching live device GPS position.
abstract class LocationDeviceDataSource {
  /// Returns the current GPS position.
  ///
  /// [permissionAlreadyGranted] means the caller just finished a permission
  /// prompt; we still re-check status (web can report stale denied) and skip
  /// a redundant [Geolocator.requestPermission] when already granted.
  /// [forceRefresh] skips in-memory cache and last-known fast path only.
  Future<Position> getCurrentPosition({
    bool permissionAlreadyGranted = false,
    bool forceRefresh = false,
  });

  /// Drops the short-lived in-memory fix so a fresh QR scan cannot reuse it.
  void clearCachedPosition();
}

/// Whether [position] is accurate enough for check-in proximity.
///
/// [maxAccuracyMeters] defaults to the native [AppConstants.maxGpsAccuracyMeters]
/// gate. Web callers pass [AppConstants.maxGpsAccuracyMetersWeb].
bool isGpsAccuracyAcceptable(
  Position position, {
  double maxAccuracyMeters = AppConstants.maxGpsAccuracyMeters,
}) {
  return position.accuracy <= maxAccuracyMeters;
}

/// Whether [position.timestamp] is within [maxAgeSeconds] of [now].
bool isGpsPositionFresh(
  Position position, {
  required DateTime now,
  required int maxAgeSeconds,
}) {
  final ageSeconds = now.difference(position.timestamp).inSeconds;
  // Allow small clock skew (device clock behind GPS timestamp).
  if (ageSeconds < 0) return ageSeconds > -30;
  return ageSeconds <= maxAgeSeconds;
}

/// Geolocator implementation of [LocationDeviceDataSource].
///
/// Web: network fix (3s) raced against high accuracy (6s); worst case ≈ 6s.
/// Native: medium then high with short timeouts.
class LocationDeviceDataSourceImpl implements LocationDeviceDataSource {
  LocationDeviceDataSourceImpl({
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position?> Function()? getLastKnownPosition,
    Future<Position> Function(LocationSettings settings)? getCurrentPositionFn,
    DateTime Function()? clock,
    bool? isWebOverride,
  }) : _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _getLastKnownPosition =
           getLastKnownPosition ?? Geolocator.getLastKnownPosition,
       _getCurrentPositionFn =
           getCurrentPositionFn ??
           ((settings) => Geolocator.getCurrentPosition(
             locationSettings: settings,
           )),
       _clock = clock ?? DateTime.now,
       _isWeb = isWebOverride ?? kIsWeb;

  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position?> Function() _getLastKnownPosition;
  final Future<Position> Function(LocationSettings settings)
  _getCurrentPositionFn;
  final DateTime Function() _clock;
  final bool _isWeb;

  /// Cached position and its wall-clock capture time for short-term reuse.
  Position? _cachedPosition;
  DateTime? _cacheTimestamp;

  @override
  void clearCachedPosition() {
    _cachedPosition = null;
    _cacheTimestamp = null;
  }

  /// How long a cached GPS position remains valid (seconds).
  static const int cacheDurationSeconds = 180;

  /// Max age for platform last-known before we refuse the fast path.
  static const int lastKnownMaxAgeSeconds = 120;

  /// Native medium timeout (snappy).
  static const int nativeMediumGpsTimeoutSeconds = 3;

  /// Native high timeout.
  static const int nativeHighGpsTimeoutSeconds = 3;

  /// Web network/Wi‑Fi fix (enableHighAccuracy: false), raced with high.
  static const int webMediumGpsTimeoutSeconds = 3;

  /// Web high-accuracy fix, raced with the network fix. Worst case ≈ 6s.
  static const int webHighGpsTimeoutSeconds = 6;

  /// Browser may return a fix it already holds that is at most this old.
  static const int webMaximumAgeSeconds = 30;

  int get _mediumTimeoutSeconds =>
      _isWeb ? webMediumGpsTimeoutSeconds : nativeMediumGpsTimeoutSeconds;

  int get _highTimeoutSeconds =>
      _isWeb ? webHighGpsTimeoutSeconds : nativeHighGpsTimeoutSeconds;

  double get _maxAccuracyMeters => _isWeb
      ? AppConstants.maxGpsAccuracyMetersWeb
      : AppConstants.maxGpsAccuracyMeters;

  bool _isAccuracyAcceptable(Position position) =>
      isGpsAccuracyAcceptable(position, maxAccuracyMeters: _maxAccuracyMeters);

  /// Prefer the lower `accuracy` value (smaller circle of uncertainty).
  Position? _preferBetter(Position? current, Position? candidate) {
    if (candidate == null) return current;
    if (current == null) return candidate;
    return candidate.accuracy < current.accuracy ? candidate : current;
  }

  @override
  Future<Position> getCurrentPosition({
    bool permissionAlreadyGranted = false,
    bool forceRefresh = false,
  }) async {
    final started = _clock();
    final now = started;

    if (forceRefresh) {
      _cachedPosition = null;
      _cacheTimestamp = null;
    }

    // 1. In-memory cache (same session / screen flow).
    final cached = _cachedPosition;
    final cachedAt = _cacheTimestamp;
    if (!forceRefresh && cached != null && cachedAt != null) {
      final age = now.difference(cachedAt).inSeconds;
      if (age < cacheDurationSeconds && _isAccuracyAcceptable(cached)) {
        AppLogger.info(
          'Returning cached GPS position (${age}s old): '
          'lat=${cached.latitude}, lon=${cached.longitude}',
          tag: 'LocationDeviceDataSource',
        );
        return cached;
      }
    }

    // 2. Permission and services.
    // Web: geolocator's requestPermission maps every browser error to
    // deniedForever and its services check is always true, so web never
    // requests here (PermissionService prompts first) and classifies the
    // acquisition errors below instead.
    var permission = await _checkPermission();
    var granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (_isWeb) {
      if (permission == LocationPermission.deniedForever) {
        throw const LocationPermissionPermanentlyDeniedException(
          technicalMessage: 'Web site permission denied (blocked).',
        );
      }
    } else {
      if (!granted) {
        AppLogger.info(
          'Requesting location permission (current=$permission, '
          'alreadyGrantedFlag=$permissionAlreadyGranted, '
          'forceRefresh=$forceRefresh)',
          tag: 'LocationDeviceDataSource',
        );
        permission = await _requestPermission();
        granted =
            permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse;
      }

      if (!await _isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      if (!granted) {
        if (permission == LocationPermission.deniedForever) {
          throw const LocationPermissionPermanentlyDeniedException();
        }
        throw const LocationPermissionDeniedException();
      }
    }

    final failures = <Object>[];

    AppLogger.info(
      'GPS acquire start (web=$_isWeb, forceRefresh=$forceRefresh, '
      'permission=$permission, medium=${_mediumTimeoutSeconds}s, '
      'high=${_highTimeoutSeconds}s, maxAccuracy=${_maxAccuracyMeters}m)',
      tag: 'LocationDeviceDataSource',
    );

    try {
      // 3. Fresh last-known first (native only).
      // geolocator_web throws UnsupportedError for getLastKnownPosition, which
      // used to become LocationUnavailableException before any live fix.
      final lastKnown = await _readLastKnownPosition();
      if (!forceRefresh &&
          lastKnown != null &&
          _isAccuracyAcceptable(lastKnown) &&
          isGpsPositionFresh(
            lastKnown,
            now: now,
            maxAgeSeconds: lastKnownMaxAgeSeconds,
          )) {
        AppLogger.info(
          'Using fresh last-known GPS '
          '(accuracy=${lastKnown.accuracy.toStringAsFixed(0)}m): '
          'lat=${lastKnown.latitude}, lon=${lastKnown.longitude}',
          tag: 'LocationDeviceDataSource',
        );
        return _remember(lastKnown);
      }

      // 4. Live fix.
      Position? pos;
      if (_isWeb) {
        pos = await _raceWebFix(failures);
      } else {
        pos = await _tryCurrentPosition(
          accuracy: LocationAccuracy.medium,
          timeLimitSeconds: _mediumTimeoutSeconds,
          failures: failures,
        );
        // 5. Native: one high-accuracy follow-up when medium misses.
        if (pos == null || !_isAccuracyAcceptable(pos)) {
          final high = await _tryCurrentPosition(
            accuracy: LocationAccuracy.high,
            timeLimitSeconds: _highTimeoutSeconds,
            failures: failures,
          );
          pos = _preferBetter(pos, high);
        }
      }

      // 6. Last resort: still-usable last-known within cache TTL.
      if ((pos == null || !_isAccuracyAcceptable(pos)) &&
          lastKnown != null &&
          _isAccuracyAcceptable(lastKnown) &&
          isGpsPositionFresh(
            lastKnown,
            now: _clock(),
            maxAgeSeconds: cacheDurationSeconds,
          )) {
        AppLogger.info(
          'Falling back to last-known GPS after live fix miss',
          tag: 'LocationDeviceDataSource',
        );
        return _remember(lastKnown);
      }

      final elapsedMs = _clock().difference(started).inMilliseconds;

      if (pos == null) {
        AppLogger.warning(
          'GPS unavailable after ${elapsedMs}ms (web=$_isWeb, '
          'failures=$failures)',
          tag: 'LocationDeviceDataSource',
        );
        throw await _classifyAcquisitionFailure(failures, elapsedMs);
      }
      if (!_isAccuracyAcceptable(pos)) {
        AppLogger.warning(
          'GPS accuracy too low: ${pos.accuracy.toStringAsFixed(0)}m '
          '(max ${_maxAccuracyMeters.toStringAsFixed(0)}m, web=$_isWeb)',
          tag: 'LocationDeviceDataSource',
        );
        throw LocationAccuracyTooLowException(
          accuracy: pos.accuracy,
          technicalMessage:
              'GPS accuracy too low: ${pos.accuracy.toStringAsFixed(1)}m '
              '(max ${_maxAccuracyMeters.toStringAsFixed(0)}m, web=$_isWeb).',
        );
      }

      if (pos.isMocked) {
        AppLogger.warning(
          'Mock location detected on device: ${pos.latitude}, ${pos.longitude}',
          tag: 'LocationDeviceDataSource',
        );
      }

      AppLogger.info(
        'GPS acquired in ${elapsedMs}ms '
        '(accuracy=${pos.accuracy.toStringAsFixed(0)}m)',
        tag: 'LocationDeviceDataSource',
      );
      return _remember(pos);
    } on AppException {
      rethrow;
    } catch (e, st) {
      AppLogger.error(
        'Failed to obtain GPS position: $e',
        error: e,
        stackTrace: st,
        tag: 'LocationDeviceDataSource',
      );
      throw LocationUnavailableException(originalError: e, stackTrace: st);
    }
  }

  /// Native last-known cache. Web skips the call: geolocator_web throws
  /// [UnsupportedError] and has no last-known position.
  Future<Position?> _readLastKnownPosition() async {
    if (_isWeb) return null;
    try {
      return await _getLastKnownPosition();
    } on UnsupportedError catch (e) {
      AppLogger.info(
        'Last-known GPS unsupported, requesting a live fix: $e',
        tag: 'LocationDeviceDataSource',
      );
      return null;
    }
  }

  /// Runs a network fix and a high-accuracy fix in parallel.
  ///
  /// Returns the first fix that is precise (≤ [AppConstants.maxGpsAccuracyMeters])
  /// immediately. A coarser fix waits for the other request so a wide Wi‑Fi
  /// circle cannot wrongly push a member outside the venue radius; once both
  /// settle, the more accurate one wins (web cap is applied by the caller).
  Future<Position?> _raceWebFix(List<Object> failures) {
    final done = Completer<Position?>();
    Position? best;
    var pending = 2;

    void onResult(Position? pos) {
      if (done.isCompleted) return;
      best = _preferBetter(best, pos);
      if (pos != null && pos.accuracy <= AppConstants.maxGpsAccuracyMeters) {
        done.complete(pos);
        return;
      }
      pending--;
      if (pending == 0) done.complete(best);
    }

    _tryCurrentPosition(
      accuracy: LocationAccuracy.medium,
      timeLimitSeconds: _mediumTimeoutSeconds,
      failures: failures,
    ).then(onResult);
    _tryCurrentPosition(
      accuracy: LocationAccuracy.high,
      timeLimitSeconds: _highTimeoutSeconds,
      failures: failures,
    ).then(onResult);
    return done.future;
  }

  /// Turns the collected per-attempt errors into the most specific exception.
  /// A permission or device error wins over a plain timeout.
  Future<AppException> _classifyAcquisitionFailure(
    List<Object> failures,
    int elapsedMs,
  ) async {
    if (failures.any((e) => e is PermissionDeniedException)) {
      if (!_isWeb) return const LocationPermissionDeniedException();
      LocationPermission after;
      try {
        after = await _checkPermission();
      } catch (_) {
        after = LocationPermission.unableToDetermine;
      }
      return classifyLocationDenial(after);
    }
    if (failures.any((e) => e is geo.LocationServiceDisabledException)) {
      return const LocationServiceDisabledException();
    }
    if (failures.any((e) => e is PositionUpdateException)) {
      return LocationUnavailableException(
        technicalMessage:
            'Position unavailable after ${elapsedMs}ms (web=$_isWeb).',
      );
    }
    return LocationTimeoutException(
      technicalMessage:
          'GPS position timed out after ${elapsedMs}ms (web=$_isWeb).',
    );
  }

  Future<Position?> _tryCurrentPosition({
    required LocationAccuracy accuracy,
    required int timeLimitSeconds,
    required List<Object> failures,
  }) async {
    final limit = Duration(seconds: timeLimitSeconds);
    // geolocator_web maps medium → enableHighAccuracy: false (network fix)
    // and high → true (GPS).
    final LocationSettings settings = _isWeb
        ? WebSettings(
            accuracy: accuracy,
            maximumAge: const Duration(seconds: webMaximumAgeSeconds),
            timeLimit: limit,
          )
        : LocationSettings(accuracy: accuracy, timeLimit: limit);
    try {
      final future = _getCurrentPositionFn(settings);
      if (!_isWeb) return await future;
      // geolocator_web writes timeLimit.inMicroseconds into the browser
      // timeout, which is in milliseconds, so a 10s limit waits ~10000s.
      // Stop waiting ourselves. Swallow a late error from the abandoned call.
      unawaited(
        future.then<void>(
          (_) {},
          onError: (Object _, StackTrace _) {},
        ),
      );
      return await future.timeout(limit);
    } catch (e) {
      failures.add(e);
      AppLogger.info(
        'GPS ${settings.accuracy} fix missed within ${timeLimitSeconds}s: $e',
        tag: 'LocationDeviceDataSource',
      );
      return null;
    }
  }

  Position _remember(Position pos) {
    _cachedPosition = pos;
    _cacheTimestamp = _clock();
    return pos;
  }
}
