import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

import '../errors/app_exception.dart';
import '../logger/app_logger.dart';

/// Handles runtime permissions for location and camera.
///
/// Wraps platform permission APIs with typed [AppException] errors.
class PermissionService {
  const PermissionService();

  /// Request location permission.
  ///
  /// Always invokes the platform prompt path when location is not already
  /// granted. On web, a previous Deny is reported as [LocationPermission.deniedForever];
  /// calling [Geolocator.requestPermission] again still runs `getCurrentPosition`,
  /// which re-shows the browser dialog when the user later sets the site back
  /// to Ask/Allow (e.g. after an accidental Deny + re-scan).
  ///
  /// Throws:
  /// - [LocationServiceDisabledException] if location services are off
  /// - [LocationPermissionDeniedException] if permission denied
  /// - [LocationPermissionPermanentlyDeniedException] if permanently denied
  Future<void> requestLocationPermission() async {
    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw const LocationServiceDisabledException();
    }

    var permission = await Geolocator.checkPermission();

    final alreadyGranted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!alreadyGranted) {
      AppLogger.info(
        'Requesting location permission (current=$permission, web=$kIsWeb)',
        tag: 'PermissionService',
      );
      // Re-prompt even when status is deniedForever so a fresh QR scan / Allow
      // tap can surface the system dialog again after the user resets site
      // permission, or succeed immediately if they already chose Allow.
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse) {
      AppLogger.debug(
        'Location permission granted: $permission',
        tag: 'PermissionService',
      );
      return;
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogger.info(
        'Location permission permanently denied',
        tag: 'PermissionService',
      );
      throw const LocationPermissionPermanentlyDeniedException();
    }

    AppLogger.info(
      'Location permission denied by user',
      tag: 'PermissionService',
    );
    throw const LocationPermissionDeniedException();
  }

  /// Check if location permission is currently granted.
  Future<bool> isLocationPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request camera permission.
  ///
  /// Throws [CameraPermissionDeniedException] if denied.
  Future<void> requestCameraPermission() async {
    final status =
        await permission_handler.Permission.camera.request();

    if (status.isDenied || status.isPermanentlyDenied) {
      AppLogger.info(
        'Camera permission denied: $status',
        tag: 'PermissionService',
      );
      throw const CameraPermissionDeniedException();
    }

    AppLogger.debug(
      'Camera permission granted',
      tag: 'PermissionService',
    );
  }

  /// Open the device / browser settings page for manual permission changes.
  Future<bool> openAppSettings() async {
    return permission_handler.openAppSettings();
  }
}
