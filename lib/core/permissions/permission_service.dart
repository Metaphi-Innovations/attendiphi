import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:permission_handler/permission_handler.dart'
    as permission_handler;

import '../errors/app_exception.dart';
import '../logger/app_logger.dart';

/// Side-effect-free snapshot of whether location can be used right now.
enum LocationAccessStatus {
  /// Permission granted (and, on native, device Location is on).
  granted,

  /// Permission not decided yet (or unknown); a user-initiated prompt may work.
  needsPrompt,

  /// Permission blocked for this site / app; prompting again will not help.
  blocked,

  /// Device Location Services are off (only provable on native).
  serviceDisabled,
}

bool _isGranted(LocationPermission p) =>
    p == LocationPermission.always || p == LocationPermission.whileInUse;

/// Maps a geolocation PERMISSION_DENIED outcome to the most specific error the
/// evidence supports, using the site permission state read *after* the error.
///
/// - site `denied` (Permissions API) → blocked for this site.
/// - site `granted` → the site is allowed but the device refused a position,
///   which on Android Chrome means device Location is off.
/// - anything else (`prompt`, unsupported) → ambiguous: the user dismissed the
///   prompt or declined Chrome's "turn on Location" dialog. Neutral message.
AppException classifyLocationDenial(LocationPermission siteState) {
  if (siteState == LocationPermission.deniedForever) {
    return const LocationPermissionPermanentlyDeniedException(
      technicalMessage: 'PERMISSION_DENIED with site permission denied.',
    );
  }
  if (_isGranted(siteState)) {
    return const LocationServiceDisabledException(
      technicalMessage:
          'PERMISSION_DENIED while site permission granted '
          '(device Location off).',
    );
  }
  return LocationPermissionDeniedException(
    technicalMessage: 'PERMISSION_DENIED with site permission $siteState.',
  );
}

/// Handles runtime permissions for location and camera.
///
/// Wraps platform permission APIs with typed [AppException] errors.
///
/// Web caveats (geolocator_web 4.x): `isLocationServiceEnabled` is always true
/// and `requestPermission` maps every browser error to `deniedForever`, so on
/// web the prompt goes through `getCurrentPosition` and errors are classified
/// with [classifyLocationDenial].
class PermissionService {
  PermissionService({
    Future<bool> Function()? isLocationServiceEnabled,
    Future<LocationPermission> Function()? checkPermission,
    Future<LocationPermission> Function()? requestPermission,
    Future<Position> Function(LocationSettings settings)? getCurrentPositionFn,
    bool? isWebOverride,
    this.webPromptTimeout = const Duration(seconds: 60),
  }) : _isLocationServiceEnabled =
           isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
       _checkPermission = checkPermission ?? Geolocator.checkPermission,
       _requestPermission = requestPermission ?? Geolocator.requestPermission,
       _getCurrentPositionFn =
           getCurrentPositionFn ??
           ((settings) => Geolocator.getCurrentPosition(
             locationSettings: settings,
           )),
       _isWeb = isWebOverride ?? kIsWeb;

  final Future<bool> Function() _isLocationServiceEnabled;
  final Future<LocationPermission> Function() _checkPermission;
  final Future<LocationPermission> Function() _requestPermission;
  final Future<Position> Function(LocationSettings settings)
  _getCurrentPositionFn;
  final bool _isWeb;

  /// How long the browser prompt may stay open before we re-read the
  /// Permissions API. The user may need time to read the dialog.
  final Duration webPromptTimeout;

  /// Whether [checkLocationAccess] can report device Location being off.
  /// Browsers do not expose it.
  bool get canDetectServiceState => !_isWeb;

  /// Whether permissions are browser site permissions (vs. app permissions).
  bool get isWeb => _isWeb;

  Future<LocationPermission> _safeCheckPermission() async {
    try {
      return await _checkPermission();
    } catch (e) {
      AppLogger.info(
        'Location permission state unavailable: $e',
        tag: 'PermissionService',
      );
      return LocationPermission.unableToDetermine;
    }
  }

  /// Reads the current location access state without prompting and without
  /// requesting a GPS fix.
  Future<LocationAccessStatus> checkLocationAccess() async {
    if (!_isWeb && !await _isLocationServiceEnabled()) {
      return LocationAccessStatus.serviceDisabled;
    }
    final permission = await _safeCheckPermission();
    final status = switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => LocationAccessStatus.granted,
      LocationPermission.deniedForever => LocationAccessStatus.blocked,
      LocationPermission.denied ||
      LocationPermission.unableToDetermine => LocationAccessStatus.needsPrompt,
    };
    AppLogger.debug(
      'Location access status=$status (permission=$permission, web=$_isWeb)',
      tag: 'PermissionService',
    );
    return status;
  }

  /// Ensures location permission, prompting only when the state allows it.
  ///
  /// Must be called from a user gesture on web. Never re-prompts when the
  /// permission is blocked.
  ///
  /// Throws:
  /// - [LocationServiceDisabledException] when there is evidence device
  ///   Location is off
  /// - [LocationPermissionDeniedException] when not granted and the cause is
  ///   ambiguous (retryable)
  /// - [LocationPermissionPermanentlyDeniedException] when blocked
  /// - [LocationUnavailableException] when allowed but no position came back
  Future<void> requestLocationPermission() async {
    final status = await checkLocationAccess();
    switch (status) {
      case LocationAccessStatus.granted:
        return;
      case LocationAccessStatus.serviceDisabled:
        AppLogger.info(
          'Location services disabled; not prompting',
          tag: 'PermissionService',
        );
        throw const LocationServiceDisabledException(
          technicalMessage: 'Device location services disabled.',
        );
      case LocationAccessStatus.blocked:
        AppLogger.info(
          'Location permission blocked; not prompting',
          tag: 'PermissionService',
        );
        throw const LocationPermissionPermanentlyDeniedException(
          technicalMessage: 'Permission blocked before prompt.',
        );
      case LocationAccessStatus.needsPrompt:
        break;
    }

    AppLogger.info(
      'Requesting location permission (web=$_isWeb)',
      tag: 'PermissionService',
    );
    if (_isWeb) return _promptWeb();

    final permission = await _requestPermission();
    if (_isGranted(permission)) return;
    if (!await _isLocationServiceEnabled()) {
      throw const LocationServiceDisabledException(
        technicalMessage:
            'Device location services disabled (checked after request).',
      );
    }
    if (permission == LocationPermission.deniedForever) {
      AppLogger.info(
        'Location permission permanently denied',
        tag: 'PermissionService',
      );
      throw const LocationPermissionPermanentlyDeniedException();
    }
    AppLogger.info('Location permission denied by user', tag: 'PermissionService');
    throw const LocationPermissionDeniedException();
  }

  /// Triggers the browser prompt with a cheap position request and classifies
  /// the outcome. geolocator_web's own `requestPermission` hides the error code.
  Future<void> _promptWeb() async {
    final future = _getCurrentPositionFn(
      WebSettings(
        accuracy: LocationAccuracy.low,
        maximumAge: const Duration(minutes: 5),
      ),
    );
    unawaited(
      future.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    );
    try {
      await future.timeout(webPromptTimeout);
      AppLogger.debug('Browser location prompt granted', tag: 'PermissionService');
    } on PermissionDeniedException catch (e) {
      final after = await _safeCheckPermission();
      AppLogger.info(
        'Browser location PERMISSION_DENIED (site permission now $after): $e',
        tag: 'PermissionService',
      );
      throw classifyLocationDenial(after);
    } on PositionUpdateException catch (e) {
      final after = await _safeCheckPermission();
      AppLogger.info(
        'Browser location POSITION_UNAVAILABLE (site permission $after): $e',
        tag: 'PermissionService',
      );
      if (_isGranted(after)) {
        throw LocationUnavailableException(originalError: e);
      }
      throw classifyLocationDenial(after);
    } on TimeoutException {
      final after = await _safeCheckPermission();
      AppLogger.info(
        'Browser location prompt unresolved after '
        '${webPromptTimeout.inSeconds}s (site permission $after)',
        tag: 'PermissionService',
      );
      // Granted but slow first fix: the GPS step will fetch the position.
      if (_isGranted(after)) return;
      throw classifyLocationDenial(after);
    }
  }

  /// Check if location permission is currently granted.
  Future<bool> isLocationPermissionGranted() async {
    return _isGranted(await _safeCheckPermission());
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
