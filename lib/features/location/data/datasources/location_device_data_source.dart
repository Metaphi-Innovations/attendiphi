import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';

/// Contract for fetching live device GPS position.
abstract class LocationDeviceDataSource {
  Future<Position> getCurrentPosition();
}

/// Geolocator implementation of [LocationDeviceDataSource].
///
/// Uses multi-sample averaging and short-term caching to eliminate
/// GPS jitter between consecutive check-ins from the same physical location.
class LocationDeviceDataSourceImpl implements LocationDeviceDataSource {
  LocationDeviceDataSourceImpl();

  /// Cached position and its timestamp for short-term reuse.
  Position? _cachedPosition;
  DateTime? _cacheTimestamp;

  /// How long a cached GPS position remains valid (seconds). 3 minutes for seamless screen flow.
  static const int _cacheDurationSeconds = 180;

  /// Fast single-shot timeout in seconds.
  static const int _fastGpsTimeoutSeconds = 4;

  @override
  Future<Position> getCurrentPosition() async {
    // 1. Return cached position if fresh (within 3 minutes)
    if (_cachedPosition != null && _cacheTimestamp != null) {
      final age = DateTime.now().difference(_cacheTimestamp!).inSeconds;
      if (age < _cacheDurationSeconds) {
        AppLogger.info(
          'Returning cached GPS position (${age}s old): '
          'lat=${_cachedPosition!.latitude}, lon=${_cachedPosition!.longitude}',
          tag: 'LocationDeviceDataSource',
        );
        return _cachedPosition!;
      }
    }

    // 2. Check service & permissions
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw const LocationPermissionPermanentlyDeniedException();
    }

    // 3. Fast single-shot GPS acquisition with fallback
    try {
      Position pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: _fastGpsTimeoutSeconds),
          ),
        );
      } catch (_) {
        // Fallback: check last known position or try medium accuracy with short timeout
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null && lastKnown.accuracy <= AppConstants.maxGpsAccuracyMeters) {
          pos = lastKnown;
        } else {
          pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 5),
            ),
          );
        }
      }

      if (pos.accuracy > AppConstants.maxGpsAccuracyMeters) {
        throw LocationAccuracyTooLowException(accuracy: pos.accuracy);
      }

      if (pos.isMocked) {
        AppLogger.warning(
          'Mock location detected on device: ${pos.latitude}, ${pos.longitude}',
          tag: 'LocationDeviceDataSource',
        );
      }

      _cachedPosition = pos;
      _cacheTimestamp = DateTime.now();
      return pos;
    } on AppException {
      rethrow;
    } catch (e, st) {
      AppLogger.error(
        'Failed to obtain GPS position: $e',
        error: e,
        stackTrace: st,
        tag: 'LocationDeviceDataSource',
      );
      throw LocationUnavailableException(
        originalError: e,
        stackTrace: st,
      );
    }
  }
}

