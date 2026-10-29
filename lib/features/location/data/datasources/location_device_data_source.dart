import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';

/// Contract for fetching live device GPS position.
abstract class LocationDeviceDataSource {
  /// Returns the current GPS position.
  ///
  /// When [permissionAlreadyGranted] is true (caller just finished
  /// [PermissionService.requestLocationPermission]), skips redundant
  /// `requestPermission` so the post-Allow path stays snappy.
  Future<Position> getCurrentPosition({bool permissionAlreadyGranted = false});
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
/// Prefers in-memory cache → fresh last-known → short medium fix, so the
/// post-Allow path typically resolves in ~1–2s instead of waiting on a long
/// high-accuracy timeout first.
class LocationDeviceDataSourceImpl implements LocationDeviceDataSource {
  LocationDeviceDataSourceImpl({
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position?> Function()? getLastKnownPosition,
    Future<Position> Function(LocationSettings settings)? getCurrentPositionFn,
    DateTime Function()? clock,
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
       _clock = clock ?? DateTime.now;

  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position?> Function() _getLastKnownPosition;
  final Future<Position> Function(LocationSettings settings)
  _getCurrentPositionFn;
  final DateTime Function() _clock;

  /// Cached position and its wall-clock capture time for short-term reuse.
  Position? _cachedPosition;
  DateTime? _cacheTimestamp;

  /// How long a cached GPS position remains valid (seconds).
  static const int cacheDurationSeconds = 180;

  /// Max age for platform last-known before we refuse the fast path.
  static const int lastKnownMaxAgeSeconds = 120;

  /// Primary post-Allow fix — medium is much faster on web/mobile than high.
  static const int mediumGpsTimeoutSeconds = 2;

  /// One short high-accuracy attempt only if medium fails / is too coarse.
  static const int highGpsTimeoutSeconds = 2;

  @override
  Future<Position> getCurrentPosition({
    bool permissionAlreadyGranted = false,
  }) async {
    final now = _clock();

    // 1. In-memory cache (same session / screen flow).
    final cached = _cachedPosition;
    final cachedAt = _cacheTimestamp;
    if (cached != null && cachedAt != null) {
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

    // 2. Service + permissions (skip re-prompt when caller already granted).
    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    if (!permissionAlreadyGranted) {
      var permission = await _checkPermission();
      final alreadyGranted =
          permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!alreadyGranted) {
        permission = await _requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationPermissionPermanentlyDeniedException();
      }
    }

    try {
      // 3. Fresh last-known first — avoids waiting on a new satellite fix.
      final lastKnown = await _getLastKnownPosition();
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

      // 4. Short medium-accuracy fix (fast on web + mobile).
      Position? pos = await _tryCurrentPosition(
        accuracy: LocationAccuracy.medium,
        timeLimitSeconds: mediumGpsTimeoutSeconds,
      );

      // 5. Brief high-accuracy only if medium missing or too coarse.
      if (pos == null || !isGpsAccuracyAcceptable(pos)) {
        final high = await _tryCurrentPosition(
          accuracy: LocationAccuracy.high,
          timeLimitSeconds: highGpsTimeoutSeconds,
        );
        if (high != null) pos = high;
      }

      // 6. Last resort: still-usable last-known within cache TTL window.
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

      if (pos == null) {
        throw const LocationUnavailableException();
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
