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

    // Check current permission status
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        AppLogger.info(
          'Location permission denied by user',
          tag: 'PermissionService',
        );
        throw const LocationPermissionDeniedException();
      }
    }

    if (permission == LocationPermission.deniedForever) {
      AppLogger.info(
        'Location permission permanently denied',
        tag: 'PermissionService',
      );
      throw const LocationPermissionPermanentlyDeniedException();
    }

    AppLogger.debug(
      'Location permission granted: $permission',
      tag: 'PermissionService',
    );
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

  /// Open device settings for the user to manually grant permissions.
  Future<bool> openAppSettings() async {
    return permission_handler.openAppSettings();
  }
}
