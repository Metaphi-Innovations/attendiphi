import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';

/// Contract for fetching live device GPS position.
abstract class LocationDeviceDataSource {
  /// Returns the current GPS position.
  ///
  /// [permissionAlreadyGranted] means the caller just finished a permission
  /// prompt; we still re-check status (web can report stale denied).
  /// [forceRefresh] skips in-memory cache and last-known fast path, and
  /// always re-invokes [Geolocator.requestPermission] before acquiring.
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
/// Web uses longer first-fix timeouts than native — mobile browsers often
/// need several seconds after Allow before a position is ready.
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

  /// Web first-fix timeouts — browsers are slower after Allow.
  static const int webMediumGpsTimeoutSeconds = 10;

  /// Web high-accuracy attempt.
  static const int webHighGpsTimeoutSeconds = 10;

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

    // 2. Permissions first (so web can show Allow), then services check.
    // Never map OS Location-off → “blocked for this site”.
    // Fresh QR / Retry (forceRefresh) always re-invokes requestPermission so
    // the browser permission API runs even when a prior grant is cached.
    var permission = await _checkPermission();
    var granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!granted || forceRefresh) {
      AppLogger.info(
        'Requesting location permission (current=$permission, '
        'alreadyGrantedFlag=$permissionAlreadyGranted, '
        'forceRefresh=$forceRefresh, web=$_isWeb)',
        tag: 'LocationDeviceDataSource',
      );
      permission = await _requestPermission();
      granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    }

    if (!granted) {
      final serviceEnabled = await _isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw const LocationServiceDisabledException();
      }
      if (permission == LocationPermission.deniedForever) {
        // Web often reports deniedForever when Location was off or site is Ask.
        if (_isWeb) {
          throw const LocationPermissionDeniedException(
            technicalMessage:
                'Web LocationPermission.deniedForever after requestPermission '
                '(recoverable; Retry re-prompts).',
          );
        }
        throw const LocationPermissionPermanentlyDeniedException();
      }
      throw const LocationPermissionDeniedException();
    }

    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    AppLogger.info(
      'GPS acquire start (web=$_isWeb, forceRefresh=$forceRefresh, '
      'permission=$permission, medium=${_mediumTimeoutSeconds}s, '
      'high=${_highTimeoutSeconds}s, maxAccuracy=${_maxAccuracyMeters}m)',
      tag: 'LocationDeviceDataSource',
    );

    // Web: permission dialog often resolves before the GPS stack is ready.
    if (_isWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

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

      // 4. Live fix. Web must use high accuracy: geolocator_web maps medium
      // to enableHighAccuracy false.
      final firstAccuracy = _isWeb
          ? LocationAccuracy.high
          : LocationAccuracy.medium;
      Position? pos = await _tryCurrentPosition(
        accuracy: firstAccuracy,
        timeLimitSeconds: _mediumTimeoutSeconds,
      );

      // Web: one quick retry after a miss (common after first Allow).
      if (_isWeb && (pos == null || !_isAccuracyAcceptable(pos))) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final retryHigh = await _tryCurrentPosition(
          accuracy: LocationAccuracy.high,
          timeLimitSeconds: _mediumTimeoutSeconds,
        );
        pos = _preferBetter(pos, retryHigh);
      }

      // 5. High-accuracy if the first fix is missing or too coarse.
      if (pos == null || !_isAccuracyAcceptable(pos)) {
        final high = await _tryCurrentPosition(
          accuracy: LocationAccuracy.high,
          timeLimitSeconds: _highTimeoutSeconds,
        );
        pos = _preferBetter(pos, high);
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
          'GPS unavailable after ${elapsedMs}ms (web=$_isWeb)',
          tag: 'LocationDeviceDataSource',
        );
        throw LocationTimeoutException(
          userMessage: _isWeb
              ? 'Still getting your location. Make sure Location is allowed '
                    'for this site (Precise Location on iPhone), wait a moment, '
                    'then tap Retry.'
              : 'Unable to determine your location. Please check your GPS '
                    'and try again.',
          technicalMessage:
              'GPS position timed out after ${elapsedMs}ms (web=$_isWeb).',
        );
      }
      if (!_isAccuracyAcceptable(pos)) {
        AppLogger.warning(
          'GPS accuracy too low: ${pos.accuracy.toStringAsFixed(0)}m '
          '(max ${_maxAccuracyMeters.toStringAsFixed(0)}m, web=$_isWeb)',
          tag: 'LocationDeviceDataSource',
        );
        throw LocationAccuracyTooLowException(
          accuracy: pos.accuracy,
          userMessage: _isWeb
              ? 'Browser location accuracy is too coarse '
                    '(±${pos.accuracy.round()}m; need ≤${_maxAccuracyMeters.round()}m). '
                    'Try a phone on the venue Wi‑Fi/GPS, or move near a window and tap Retry.'
              : 'Your GPS signal is too weak for accurate verification. '
                    'Please move to an open area and try again.',
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

  Future<Position?> _tryCurrentPosition({
    required LocationAccuracy accuracy,
    required int timeLimitSeconds,
  }) async {
    final limit = Duration(seconds: timeLimitSeconds);
    // Web live fixes always ask for high accuracy. geolocator_web turns
    // LocationAccuracy.medium into enableHighAccuracy: false.
    final LocationSettings settings = _isWeb
        ? WebSettings(
            accuracy: LocationAccuracy.high,
            maximumAge: Duration.zero,
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
