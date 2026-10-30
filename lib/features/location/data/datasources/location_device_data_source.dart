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
  /// [forceRefresh] skips in-memory cache and last-known fast path.
  Future<Position> getCurrentPosition({
    bool permissionAlreadyGranted = false,
    bool forceRefresh = false,
  });
}

/// Whether [position] is accurate enough for check-in proximity.
bool isGpsAccuracyAcceptable(Position position) {
  return position.accuracy <= AppConstants.maxGpsAccuracyMeters;
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
      if (age < cacheDurationSeconds && isGpsAccuracyAcceptable(cached)) {
        AppLogger.info(
          'Returning cached GPS position (${age}s old): '
          'lat=${cached.latitude}, lon=${cached.longitude}',
          tag: 'LocationDeviceDataSource',
        );
        return cached;
      }
    }

    // 2. Service + permissions (always re-check; web status can be stale).
    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await _checkPermission();
    var granted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!granted) {
      AppLogger.info(
        'Location not granted (current=$permission, '
        'alreadyGrantedFlag=$permissionAlreadyGranted, web=$_isWeb) — requesting',
        tag: 'LocationDeviceDataSource',
      );
      permission = await _requestPermission();
      granted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    }

    AppLogger.info(
      'GPS acquire start (web=$_isWeb, forceRefresh=$forceRefresh, '
      'permission=$permission, medium=${_mediumTimeoutSeconds}s, '
      'high=${_highTimeoutSeconds}s)',
      tag: 'LocationDeviceDataSource',
    );

    if (permission == LocationPermission.denied) {
      throw const LocationPermissionDeniedException();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }
    if (!granted) {
      throw const LocationPermissionDeniedException();
    }

    // Web: permission dialog often resolves before the GPS stack is ready.
    if (_isWeb) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    try {
      // 3. Fresh last-known first (skip on forceRefresh / Retry).
      Position? lastKnown;
      if (!forceRefresh) {
        lastKnown = await _getLastKnownPosition();
        if (lastKnown != null &&
            isGpsAccuracyAcceptable(lastKnown) &&
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
      } else {
        lastKnown = await _getLastKnownPosition();
      }

      // 4. Medium fix (longer on web).
      Position? pos = await _tryCurrentPosition(
        accuracy: LocationAccuracy.medium,
        timeLimitSeconds: _mediumTimeoutSeconds,
      );

      // Web: one quick retry after a miss (common after first Allow).
      if (_isWeb && (pos == null || !isGpsAccuracyAcceptable(pos))) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final retryMedium = await _tryCurrentPosition(
          accuracy: LocationAccuracy.medium,
          timeLimitSeconds: _mediumTimeoutSeconds,
        );
        if (retryMedium != null) pos = retryMedium;
      }

      // 5. High-accuracy if medium missing or too coarse.
      if (pos == null || !isGpsAccuracyAcceptable(pos)) {
        final high = await _tryCurrentPosition(
          accuracy: LocationAccuracy.high,
          timeLimitSeconds: _highTimeoutSeconds,
        );
        if (high != null) pos = high;
      }

      // 6. Last resort: still-usable last-known within cache TTL.
      if ((pos == null || !isGpsAccuracyAcceptable(pos)) &&
          lastKnown != null &&
          isGpsAccuracyAcceptable(lastKnown) &&
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
      if (!isGpsAccuracyAcceptable(pos)) {
        throw LocationAccuracyTooLowException(accuracy: pos.accuracy);
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

  Future<Position?> _tryCurrentPosition({
    required LocationAccuracy accuracy,
    required int timeLimitSeconds,
  }) async {
    try {
      return await _getCurrentPositionFn(
        LocationSettings(
          accuracy: accuracy,
          timeLimit: Duration(seconds: timeLimitSeconds),
        ),
      );
    } catch (e) {
      AppLogger.info(
        'GPS $accuracy fix missed within ${timeLimitSeconds}s: $e',
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
