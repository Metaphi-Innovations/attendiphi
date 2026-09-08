import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/permissions/permission_service.dart';
import '../../domain/entities/location_config.dart';
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

  /// Initiates location permission check and proximity validation against the target venue.
  Future<void> validateLocation() async {
    AppLogger.info(
      'Validating location for venue: ${location.name} (${location.id})',
      tag: 'LocationValidationNotifier',
    );

    try {
      // 1. Request location permission
      state = const LocationValidationRequestingPermission();
      final permissionService = ref.read(permissionServiceProvider);
      await permissionService.requestLocationPermission();

      // 2. Obtain current GPS coordinates
      state = const LocationValidationFetchingPosition();
      final getCurrentPosition = ref.read(getCurrentPositionUseCaseProvider);
      final position = await getCurrentPosition();

      // 3. Validate proximity (Haversine formula ≤ 500m)
      final validateProximity = ref.read(validateUserProximityUseCaseProvider);
      final proximityResult = validateProximity(
        userLat: position.latitude,
        userLon: position.longitude,
        accuracy: position.accuracy,
        location: location,
      );

      state = LocationValidationSuccess(
        location: location,
        result: proximityResult,
      );

      AppLogger.info(
        'Location verified: user is ${proximityResult.distanceMeters.round()}m from ${location.name}',
        tag: 'LocationValidationNotifier',
      );
    } on OutsideAllowedRadiusException catch (e) {
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
      AppLogger.logException(e, tag: 'LocationValidationNotifier');
      state = LocationValidationError(
        exception: e,
        requiresSettings: ErrorHandler.requiresSettings(e),
      );
    } catch (e, st) {
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
