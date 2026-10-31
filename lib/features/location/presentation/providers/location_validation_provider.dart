import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' show Position;

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/usecases/validate_user_proximity.dart';
import 'location_providers.dart';
import 'location_validation_state.dart';

/// Provider for [PermissionService].
final permissionServiceProvider = Provider<PermissionService>((ref) {
  return const PermissionService();
});

/// Riverpod Notifier managing the GPS permission and proximity validation workflow.
class LocationValidationNotifier extends Notifier<LocationValidationState> {
  LocationValidationNotifier(this._location);

  LocationConfig _location;

  /// Venue used for proximity checks (may be refreshed from Supabase).
  LocationConfig get location => _location;

  /// Prefer live Supabase venue details when the screen refreshes them.
  void applyLocation(LocationConfig updated) {
    if (updated.id != _location.id) return;
    _location = updated;
  }

  @override
  LocationValidationState build() {
    return const LocationValidationInitial();
  }

  /// Venue-coord fallback used when restrictions are OFF and GPS is unavailable.
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

  /// Permission + GPS started on QR entry, consumed by [validateLocation].
  Future<Position>? _pendingFix;

  /// Fresh QR entry: drop the previous scan's fix and start permission + GPS
  /// immediately (browser shows its own prompt when the site is Ask), in
  /// parallel with the screen's date/device gates.
  void startScan() {
    ref.read(locationDeviceDataSourceProvider).clearCachedPosition();
    state = const LocationValidationInitial();
    final fix = _acquirePosition();
    // Errors surface when validateLocation awaits; gated-out scans drop it.
    fix.ignore();
    _pendingFix = fix;
  }

  Future<Position> _acquirePosition() async {
    await ref.read(permissionServiceProvider).requestLocationPermission();
    return ref.read(getCurrentPositionUseCaseProvider)(
      permissionAlreadyGranted: true,
      forceRefresh: true,
    );
  }

  /// Initiates location permission check and proximity validation against the target venue.
  /// When Super Admin restrictions are OFF, GPS/radius never blocks check-in.
  Future<void> validateLocation() async {
    // Match QR form: wait for config. While loading, do not treat as ON (M5).
    final configReady = ref.read(restrictionsConfigReadyProvider);
    // Enforce radius/permission only when location restriction is ON.
    // When OFF we still attempt GPS fetch for audit; failures do not block.
    final enforceProximity =
        configReady && ref.read(locationRestrictionEnabledProvider);

    AppLogger.info(
      'Validating location for venue: ${_location.name} (${_location.id}) '
      '(enforceProximity=$enforceProximity, configReady=$configReady)',
      tag: 'LocationValidationNotifier',
    );

    try {
      // 1–2. Permission (browser prompt only when Ask) + live GPS. Reuse the
      // fix already in flight from startScan so gates don't delay GPS.
      final pending = _pendingFix;
      _pendingFix = null;
      state = pending != null
          ? const LocationValidationFetchingPosition()
          : const LocationValidationRequestingPermission();
      final position = await (pending ?? _acquirePosition());

      // 3. Validate proximity (Haversine). When restrictions OFF, outside radius is OK.
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
        'Location ${proximityResult.isWithinRadius ? 'verified' : 'recorded (bypass)'}: '
        'user is ${proximityResult.distanceMeters.round()}m from ${_location.name}',
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
      state = LocationValidationError(
        exception: e,
        requiresSettings: ErrorHandler.requiresSettings(e),
      );
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
