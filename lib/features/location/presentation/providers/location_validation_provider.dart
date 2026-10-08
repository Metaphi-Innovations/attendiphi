import 'package:flutter_riverpod/flutter_riverpod.dart';

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
class LocationValidationNotifier
    extends Notifier<LocationValidationState> {
  LocationValidationNotifier(this.location);

  final LocationConfig location;

  @override
  LocationValidationState build() {
    return const LocationValidationInitial();
  }

  /// Venue-coord fallback used when restrictions are OFF and GPS is unavailable.
  ProximityResult _bypassProximityResult() {
    return ProximityResult(
      distanceMeters: 0,
      isWithinRadius: true,
      allowedRadiusMeters: location.radiusMeters,
      userLatitude: location.latitude,
      userLongitude: location.longitude,
      gpsAccuracy: 0,
    );
  }

  void _emitBypassSuccess({String reason = 'restrictions OFF'}) {
    AppLogger.info(
      'Skipping location enforcement ($reason) for ${location.name}',
      tag: 'LocationValidationNotifier',
    );
    state = LocationValidationSuccess(
      location: location,
      result: _bypassProximityResult(),
    );
  }

  /// Clears any prior deny/error and re-runs permission + GPS validation.
  ///
  /// Call this on every fresh QR visit so an accidental Deny does not leave
  /// the user stuck on a stale "location denied" state.
  Future<void> resetAndValidate() async {
    state = const LocationValidationInitial();
    await validateLocation();
  }

  /// Initiates location permission check and proximity validation against the target venue.
  /// When Super Admin restrictions are OFF, GPS/radius never blocks check-in.
  Future<void> validateLocation() async {
    // Match QR form: wait for config. While loading, do not treat as ON (M5).
    final configReady = ref.read(restrictionsConfigReadyProvider);
    final enforceProximity =
        configReady && ref.read(restrictionsEnabledProvider);

    AppLogger.info(
      'Validating location for venue: ${location.name} (${location.id}) '
      '(enforceProximity=$enforceProximity, configReady=$configReady)',
      tag: 'LocationValidationNotifier',
    );

    try {
      // 1. Request location permission (re-prompts after a prior Deny when possible)
      state = const LocationValidationRequestingPermission();
      final permissionService = ref.read(permissionServiceProvider);
      await permissionService.requestLocationPermission();

      // 2. Obtain current GPS coordinates
      state = const LocationValidationFetchingPosition();
      final getCurrentPosition = ref.read(getCurrentPositionUseCaseProvider);
      final position = await getCurrentPosition();

      // 3. Validate proximity (Haversine). When restrictions OFF, outside radius is OK.
      final validateProximity = ref.read(validateUserProximityUseCaseProvider);
      final proximityResult = validateProximity(
        userLat: position.latitude,
        userLon: position.longitude,
        accuracy: position.accuracy,
        location: location,
        enforceProximity: enforceProximity,
      );

      state = LocationValidationSuccess(
        location: location,
        result: proximityResult,
      );

      AppLogger.info(
        'Location ${proximityResult.isWithinRadius ? 'verified' : 'recorded (bypass)'}: '
        'user is ${proximityResult.distanceMeters.round()}m from ${location.name}',
        tag: 'LocationValidationNotifier',
      );
    } on OutsideAllowedRadiusException catch (e) {
      // Only reached when enforceProximity is true.
      AppLogger.warning(
        'User is outside radius: ${e.distanceMeters.round()}m (allowed: ${e.allowedRadiusMeters}m)',
        tag: 'LocationValidationNotifier',
      );
      state = LocationValidationOutsideRadius(
        location: location,
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
final locationValidationFamilyProvider = NotifierProvider.family<
    LocationValidationNotifier, LocationValidationState, LocationConfig>(
  LocationValidationNotifier.new,
);
