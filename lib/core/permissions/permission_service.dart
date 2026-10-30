import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

import '../errors/app_exception.dart';
import '../l10n/app_strings.dart';
import '../logger/app_logger.dart';

/// Handles runtime permissions for location and camera.
///
/// Wraps platform permission APIs with typed [AppException] errors.
class PermissionService {
  const PermissionService({
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    bool? isWebOverride,
  }) : _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _isWeb = isWebOverride ?? kIsWeb;

  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final bool _isWeb;

  /// Request location permission.
  ///
  /// Always invokes the platform / browser prompt when location is not already
  /// granted. On web, OS Location-off or an unset site permission is often
  /// reported as [LocationPermission.deniedForever] *before* any Allow dialog —
  /// we still call [requestPermission], prefer a recoverable services-off /
  /// soft-deny error over “blocked for this site”, and let Retry re-prompt.
  ///
  /// Throws:
  /// - [LocationServiceDisabledException] if location services are off
  /// - [LocationPermissionDeniedException] if permission denied (retryable)
  /// - [LocationPermissionPermanentlyDeniedException] if permanently denied
  ///   (native only after an explicit permanent deny)
  Future<void> requestLocationPermission() async {
    var permission = await _checkPermission();
    final alreadyGranted =
        permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    // Always attempt the browser/OS prompt before treating the status as final.
    // User-gesture Retry / fresh QR scan depends on this path.
    if (!alreadyGranted) {
      AppLogger.info(
        'Requesting location permission (current=$permission, web=$_isWeb)',
        tag: 'PermissionService',
      );
      permission = await _requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      AppLogger.debug(
        'Location permission granted: $permission',
        tag: 'PermissionService',
      );
      return;
    }

    // Prefer "turn Location on" over "blocked" when OS services are off.
    // (Web often reports deniedForever while Location is simply disabled.)
    final serviceEnabled = await _isLocationServiceEnabled();
    if (!serviceEnabled) {
      AppLogger.info(
        'Location services disabled after permission probe '
        '(permission=$permission, web=$_isWeb)',
        tag: 'PermissionService',
      );
      throw const LocationServiceDisabledException(
        userMessage: AppStrings.locationServiceDisabled,
        technicalMessage:
            'Device location services disabled (checked after permission request).',
      );
    }

    if (permission == LocationPermission.deniedForever) {
      // Web: deniedForever frequently means "Ask" not yet resolved, OS GPS was
      // off during the probe, or Block — keep copy helpful but recoverable via
      // Retry / Allow Location (do not dead-end the QR flow).
      if (_isWeb) {
        AppLogger.info(
          'Web location deniedForever — treating as recoverable deny so Retry '
          'can re-show the browser Allow dialog',
          tag: 'PermissionService',
        );
        throw const LocationPermissionDeniedException(
          userMessage: AppStrings.locationPermissionDenied,
          technicalMessage:
              'Web LocationPermission.deniedForever after requestPermission '
              '(recoverable; Retry re-prompts).',
        );
      }
      AppLogger.info(
        'Location permission permanently denied',
        tag: 'PermissionService',
      );
      throw const LocationPermissionPermanentlyDeniedException(
        userMessage: AppStrings.locationPermissionPermanentlyDenied,
      );
    }

    AppLogger.info(
      'Location permission denied by user',
      tag: 'PermissionService',
    );
    throw const LocationPermissionDeniedException(
      userMessage: AppStrings.locationPermissionDenied,
    );
  }

  /// Check if location permission is currently granted.
  Future<bool> isLocationPermissionGranted() async {
    final permission = await _checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request camera permission.
  ///
  /// Throws [CameraPermissionDeniedException] if denied.
  Future<void> requestCameraPermission() async {
    final status = await permission_handler.Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      AppLogger.info(
        'Camera permission denied: $status',
        tag: 'PermissionService',
      );
      throw const CameraPermissionDeniedException();
    }

    AppLogger.debug('Camera permission granted', tag: 'PermissionService');
  }

  /// Open the device / browser settings page for manual permission changes.
  Future<bool> openAppSettings() async {
    return permission_handler.openAppSettings();
  }
}
