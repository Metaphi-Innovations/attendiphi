import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/usecases/validate_user_proximity.dart';
import 'location_providers.dart';
import 'location_validation_state.dart';

/// Provider for [PermissionService].
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return PermissionService();
});

/// Riverpod Notifier managing the GPS permission and proximity validation workflow.
///
/// One verification runs at a time; there is no polling and no automatic
/// retry loop. Recovery after the user changes settings happens through
/// [recheckAfterResume] (status read only) or an explicit Retry tap.
class LocationValidationNotifier extends Notifier<LocationValidationState> {
  LocationValidationNotifier(this._location);

  LocationConfig _location;
  bool _inFlight = false;

  /// Resume may start at most one verification per failure; a user tap
  /// re-arms it. Stops dialog → pause → resume → dialog loops.
  bool _resumeRecoveryUsed = false;

  /// Venue used for proximity checks (may be refreshed from Supabase).
  LocationConfig get location => _location;

  /// Whether a status check or verification is running.
  bool get isBusy => _inFlight;

  /// Prefer live Supabase venue details when the screen refreshes them.
  void applyLocation(LocationConfig updated) {
    if (updated.id != _location.id) return;
    _location = updated;
  }

  @override
  LocationValidationState build() {
    return const LocationValidationInitial();
  }

  /// Location restriction resolved from live config, then last known, then
  /// defaults (ON). Unknown config never relaxes enforcement.
  bool get _enforceProximity => ref.read(locationRestrictionEnabledProvider);

  /// Venue-coord placeholder used when restrictions are OFF and GPS is
  /// unavailable. Not verified; cannot pass an enforced check.
  ProximityResult _bypassProximityResult() {
    return ProximityResult(
      distanceMeters: 0,
      isWithinRadius: true,
      allowedRadiusMeters: _location.radiusMeters,
      userLatitude: _location.latitude,
      userLongitude: _location.longitude,
      gpsAccuracy: 0,
    );
  }

  void _emitBypassSuccess({String reason = 'restrictions OFF'}) {
    AppLogger.info(
      'Skipping location enforcement ($reason) for ${_location.name}',
      tag: 'LocationValidationNotifier',
    );
    state = LocationValidationSuccess(
      location: _location,
      result: _bypassProximityResult(),
    );
  }

  /// Clears GPS cache and returns to idle.
  ///
  /// Call on every fresh QR entry so a cached fix cannot complete the gate.
  void prepareFreshScan() {
    ref.read(locationDeviceDataSourceProvider).clearCachedPosition();
    _resumeRecoveryUsed = false;
    state = const LocationValidationInitial();
  }

  Future<LocationAccessStatus> _readAccess() async {
    try {
      return await ref.read(permissionServiceProvider).checkLocationAccess();
    } catch (e, st) {
      AppLogger.error(
        'Location access status check failed: $e',
        error: e,
        stackTrace: st,
        tag: 'LocationValidationNotifier',
      );
      return LocationAccessStatus.needsPrompt;
    }
  }

  /// Entry check for a fresh QR session. Never prompts.
  ///
  /// - granted → verifies immediately (no prompt needed)
  /// - needsPrompt → stays [LocationValidationInitial]; the screen shows the
  ///   Allow dialog so the browser prompt runs from a user gesture
  /// - blocked / serviceDisabled → matching error state (or bypass when the
  ///   location restriction is OFF)
  Future<LocationAccessStatus?> checkAccessOnEntry() async {
    if (_inFlight) return null;
    _inFlight = true;
    LocationAccessStatus status;
    try {
      state = const LocationValidationCheckingService();
      status = await _readAccess();
      AppLogger.info(
        'Entry location access for ${_location.name}: $status',
        tag: 'LocationValidationNotifier',
      );
      switch (status) {
        case LocationAccessStatus.needsPrompt:
          state = const LocationValidationInitial();
        case LocationAccessStatus.blocked:
          _applyError(const LocationPermissionPermanentlyDeniedException());
        case LocationAccessStatus.serviceDisabled:
          _applyError(const LocationServiceDisabledException());
        case LocationAccessStatus.granted:
          break;
      }
    } finally {
      _inFlight = false;
    }
    if (status == LocationAccessStatus.granted) {
      await _verify(forceRefresh: true);
    }
    return status;
  }

  /// Called when the user cancels the Allow dialog. Returns true when the
  /// location restriction is OFF and check-in may continue unverified.
  bool continueWithoutLocationIfAllowed() {
    if (_enforceProximity) return false;
    _emitBypassSuccess(reason: 'Allow dialog cancelled under restrictions OFF');
    return true;
  }

  /// Clears GPS cache and runs permission + GPS after an Allow / Retry tap.
  Future<void> resetAndValidate({bool forceRefresh = true}) async {
    if (_inFlight) return;
    ref.read(locationDeviceDataSourceProvider).clearCachedPosition();
    await validateLocation(forceRefresh: forceRefresh);
  }

  /// User-initiated verification (Allow / Retry). Ignored while one is running.
  Future<void> validateLocation({bool forceRefresh = true}) async {
    _resumeRecoveryUsed = false;
    await _verify(forceRefresh: forceRefresh);
  }

  /// Re-reads status after the app returns to the foreground. Never prompts
  /// and never polls. Starts at most one verification per failure, and only
  /// when the new status proves the blocking cause is gone.
  ///
  /// Returns the status read, or null when nothing was checked.
  Future<LocationAccessStatus?> recheckAfterResume() async {
    if (_inFlight) return null;
    final current = state;
    final recoverable =
        current is LocationValidationServiceDisabled ||
        current is LocationValidationPermissionDenied ||
        current is LocationValidationPermissionBlocked;
    if (!recoverable) return null;

    _inFlight = true;
    LocationAccessStatus status;
    try {
      status = await _readAccess();
    } finally {
      _inFlight = false;
    }
    AppLogger.info(
      'Resume recheck: ${current.runtimeType} → access $status',
      tag: 'LocationValidationNotifier',
    );

    switch (status) {
      case LocationAccessStatus.blocked:
        if (current is! LocationValidationPermissionBlocked) {
          _applyError(const LocationPermissionPermanentlyDeniedException());
        }
      case LocationAccessStatus.serviceDisabled:
        if (current is! LocationValidationServiceDisabled) {
          _applyError(const LocationServiceDisabledException());
        }
      case LocationAccessStatus.needsPrompt:
        // Site reset from Block to Ask: a prompt is possible again, but it must
        // come from a user tap.
        if (current is LocationValidationPermissionBlocked) {
          state = const LocationValidationInitial();
        }
      case LocationAccessStatus.granted:
        // Web cannot read device Location, so "granted" says nothing about a
        // services-off error there; the user retries with the dialog button.
        final causeResolved =
            current is! LocationValidationServiceDisabled ||
            ref.read(permissionServiceProvider).canDetectServiceState;
        if (causeResolved && !_resumeRecoveryUsed) {
          _resumeRecoveryUsed = true;
          await _verify(forceRefresh: true);
        }
    }
    return status;
  }

  void _applyError(AppException e) {
    if (!_enforceProximity) {
      _emitBypassSuccess(reason: '${e.runtimeType} under restrictions OFF');
      return;
    }
    AppLogger.logException(e, tag: 'LocationValidationNotifier');
    state = LocationValidationError.from(e);
  }

  Future<void> _verify({required bool forceRefresh}) async {
    if (_inFlight) {
      AppLogger.debug(
        'Location verification already running; ignoring request',
        tag: 'LocationValidationNotifier',
      );
      return;
    }
    _inFlight = true;
    final enforceProximity = _enforceProximity;

    AppLogger.info(
      'Validating location for venue: ${_location.name} (${_location.id}) '
      '(enforceProximity=$enforceProximity, forceRefresh=$forceRefresh)',
      tag: 'LocationValidationNotifier',
    );

    try {
      // 1. Status, then a prompt only when the state allows one.
      state = const LocationValidationCheckingService();
      final permissionService = ref.read(permissionServiceProvider);
      final access = await _readAccess();
      switch (access) {
        case LocationAccessStatus.granted:
          break;
        case LocationAccessStatus.blocked:
          throw const LocationPermissionPermanentlyDeniedException(
            technicalMessage: 'Permission blocked; not re-prompting.',
          );
        case LocationAccessStatus.serviceDisabled:
          throw const LocationServiceDisabledException();
        case LocationAccessStatus.needsPrompt:
          state = const LocationValidationRequestingPermission();
          await permissionService.requestLocationPermission();
      }

      // 2. Obtain GPS with a forced live fix (no in-memory cache).
      state = const LocationValidationFetchingPosition();
      final getCurrentPosition = ref.read(getCurrentPositionUseCaseProvider);
      final position = await getCurrentPosition(
        permissionAlreadyGranted: true,
        forceRefresh: forceRefresh,
      );

      // 3. Validate proximity (Haversine). When restrictions OFF, outside radius is OK.
      state = const LocationValidationValidatingVenue();
      final validateProximity = ref.read(validateUserProximityUseCaseProvider);
      final proximityResult = validateProximity(
        userLat: position.latitude,
        userLon: position.longitude,
        accuracy: position.accuracy,
        location: _location,
        enforceProximity: enforceProximity,
      );

      state = LocationValidationSuccess(
        location: _location,
        result: proximityResult,
      );

      AppLogger.info(
        'Location ${proximityResult.isVerified ? 'verified' : 'recorded (bypass)'}: '
        'user is ${proximityResult.distanceMeters.round()}m from ${_location.name} '
        '(accuracy ${proximityResult.gpsAccuracy.round()}m)',
        tag: 'LocationValidationNotifier',
      );
    } on OutsideAllowedRadiusException catch (e) {
      // Only reached when enforceProximity is true.
      AppLogger.warning(
        'User is outside radius: ${e.distanceMeters.round()}m (allowed: ${e.allowedRadiusMeters}m)',
        tag: 'LocationValidationNotifier',
      );
      state = LocationValidationOutsideRadius(
        location: _location,
        distanceMeters: e.distanceMeters,
        allowedRadiusMeters: e.allowedRadiusMeters,
      );
    } on AppException catch (e) {
      if (!enforceProximity) {
        _emitBypassSuccess(reason: 'GPS unavailable under restrictions OFF');
        return;
      }
      AppLogger.logException(e, tag: 'LocationValidationNotifier');
      state = LocationValidationError.from(e);
    } catch (e, st) {
      if (!enforceProximity) {
        _emitBypassSuccess(reason: 'GPS error under restrictions OFF');
        return;
      }
      AppLogger.error(
        'Unexpected location validation error: $e',
        error: e,
        stackTrace: st,
        tag: 'LocationValidationNotifier',
      );
      state = LocationValidationError(
        exception: ServerException(
          technicalMessage: 'Unexpected location error: $e',
          originalError: e,
          stackTrace: st,
        ),
      );
    } finally {
      _inFlight = false;
    }
  }

  /// Opens the device settings page.
  Future<void> openSettings() async {
    final permissionService = ref.read(permissionServiceProvider);
    await permissionService.openAppSettings();
  }
}

/// Family provider for [LocationValidationNotifier] scoped to a [LocationConfig].
final locationValidationFamilyProvider =
    NotifierProvider.family<
      LocationValidationNotifier,
      LocationValidationState,
      LocationConfig
    >(LocationValidationNotifier.new);
