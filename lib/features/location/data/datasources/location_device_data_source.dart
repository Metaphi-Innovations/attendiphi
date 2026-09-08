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

  /// How long a cached GPS position remains valid (seconds).
  static const int _cacheDurationSeconds = 60;

  /// Number of GPS samples to average for a stable reading.
  static const int _sampleCount = 3;

  /// Per-sample timeout to avoid hanging on a slow fix.
  static const int _perSampleTimeoutSeconds = 5;

  @override
  Future<Position> getCurrentPosition() async {
    // 1. Return cached position if fresh (within 60 seconds)
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

    // 3. Collect multiple GPS samples for averaging
    try {
      final samples = <Position>[];

      for (int i = 0; i < _sampleCount; i++) {
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.best,
              timeLimit: Duration(seconds: _perSampleTimeoutSeconds),
            ),
          );

          // Only accept samples within the accuracy threshold
          if (pos.accuracy <= AppConstants.maxGpsAccuracyMeters) {
            samples.add(pos);
            AppLogger.info(
              'GPS sample ${i + 1}/$_sampleCount: '
              'lat=${pos.latitude}, lon=${pos.longitude}, acc=${pos.accuracy}m',
              tag: 'LocationDeviceDataSource',
            );
          }
        } catch (e) {
          // If a single sample fails/times out, continue to next
          AppLogger.warning(
            'GPS sample ${i + 1}/$_sampleCount failed: $e',
            tag: 'LocationDeviceDataSource',
          );
        }
      }

      // 4. If no samples collected, fall back to a single high-accuracy attempt
      if (samples.isEmpty) {
        final fallback = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: AppConstants.gpsTimeoutSeconds),
          ),
        );

        if (fallback.accuracy > AppConstants.maxGpsAccuracyMeters) {
          throw LocationAccuracyTooLowException(accuracy: fallback.accuracy);
        }

        _cachedPosition = fallback;
        _cacheTimestamp = DateTime.now();
        return fallback;
      }

      // 5. Compute inverse-variance weighted average of all valid samples
      //    Weight = 1 / (accuracy^2) — tighter readings contribute more
      double sumLat = 0;
      double sumLon = 0;
      double sumWeight = 0;
      Position bestSample = samples.first;

      for (final sample in samples) {
        final weight = 1.0 / (sample.accuracy * sample.accuracy);
        sumLat += sample.latitude * weight;
        sumLon += sample.longitude * weight;
        sumWeight += weight;

        if (sample.accuracy < bestSample.accuracy) {
          bestSample = sample;
        }
      }

      final avgLat = sumLat / sumWeight;
      final avgLon = sumLon / sumWeight;

      // Build the averaged position using bestSample's metadata
      final averaged = Position(
        latitude: avgLat,
        longitude: avgLon,
        timestamp: bestSample.timestamp,
        accuracy: bestSample.accuracy,
        altitude: bestSample.altitude,
        altitudeAccuracy: bestSample.altitudeAccuracy,
        heading: bestSample.heading,
        headingAccuracy: bestSample.headingAccuracy,
        speed: bestSample.speed,
        speedAccuracy: bestSample.speedAccuracy,
      );

      AppLogger.info(
        'GPS averaged (${samples.length} samples): '
        'lat=${averaged.latitude}, lon=${averaged.longitude}, '
        'bestAcc=${averaged.accuracy}m',
        tag: 'LocationDeviceDataSource',
      );

      // 6. Cache the averaged position for 60 seconds
      _cachedPosition = averaged;
      _cacheTimestamp = DateTime.now();

      return averaged;
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

