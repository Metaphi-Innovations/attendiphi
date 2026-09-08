import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/usecases/validate_user_proximity.dart';

/// Sealed state for location verification and GPS permission flow.
sealed class LocationValidationState {
  const LocationValidationState();
}

/// Initial idle state.
class LocationValidationInitial extends LocationValidationState {
  const LocationValidationInitial();
}

/// Currently requesting runtime location permissions from device.
class LocationValidationRequestingPermission extends LocationValidationState {
  const LocationValidationRequestingPermission();
}

/// Permission granted, currently locking onto GPS satellites.
class LocationValidationFetchingPosition extends LocationValidationState {
  const LocationValidationFetchingPosition();
}

/// User GPS is successfully verified within the allowed perimeter (e.g. ≤ 500m).
class LocationValidationSuccess extends LocationValidationState {
  const LocationValidationSuccess({
    required this.location,
    required this.result,
  });

  final LocationConfig location;
  final ProximityResult result;
}

/// User GPS is outside the allowed perimeter (> 500m).
class LocationValidationOutsideRadius extends LocationValidationState {
  const LocationValidationOutsideRadius({
    required this.location,
    required this.distanceMeters,
    required this.allowedRadiusMeters,
  });

  final LocationConfig location;
  final double distanceMeters;
  final double allowedRadiusMeters;
}

/// Location error (denied permission, disabled GPS, accuracy too low, etc.).
class LocationValidationError extends LocationValidationState {
  const LocationValidationError({
    required this.exception,
    this.requiresSettings = false,
  });

  final AppException exception;
  final bool requiresSettings;
}
