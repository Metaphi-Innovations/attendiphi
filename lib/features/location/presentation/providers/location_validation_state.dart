import '../../../../core/errors/app_exception.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/usecases/validate_user_proximity.dart';

/// Sealed state for location verification and GPS permission flow.
sealed class LocationValidationState {
  const LocationValidationState();
}

/// Idle; waiting for the user to tap Allow Location.
class LocationValidationInitial extends LocationValidationState {
  const LocationValidationInitial();
}

/// Reading location service / permission status (no prompt, no GPS).
class LocationValidationCheckingService extends LocationValidationState {
  const LocationValidationCheckingService();
}

/// Currently requesting runtime location permissions from device.
class LocationValidationRequestingPermission extends LocationValidationState {
  const LocationValidationRequestingPermission();
}

/// Permission granted, currently locking onto GPS satellites.
class LocationValidationFetchingPosition extends LocationValidationState {
  const LocationValidationFetchingPosition();
}

/// Fix acquired; comparing it with the venue radius.
class LocationValidationValidatingVenue extends LocationValidationState {
  const LocationValidationValidatingVenue();
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
///
/// Use [LocationValidationError.from] to get the specific subtype.
class LocationValidationError extends LocationValidationState {
  const LocationValidationError({
    required this.exception,
    this.requiresSettings = false,
  });

  factory LocationValidationError.from(AppException e) => switch (e) {
    LocationServiceDisabledException() => LocationValidationServiceDisabled(
      exception: e,
    ),
    LocationPermissionPermanentlyDeniedException() =>
      LocationValidationPermissionBlocked(exception: e),
    LocationPermissionDeniedException() => LocationValidationPermissionDenied(
      exception: e,
    ),
    LocationTimeoutException() => LocationValidationTimeout(exception: e),
    LocationUnavailableException() => LocationValidationUnavailable(
      exception: e,
    ),
    LocationAccuracyTooLowException() =>
      LocationValidationAccuracyInsufficient(exception: e),
    _ => LocationValidationError(exception: e),
  };

  final AppException exception;
  final bool requiresSettings;
}

/// Device Location Services are off (evidence-based, never guessed).
class LocationValidationServiceDisabled extends LocationValidationError {
  const LocationValidationServiceDisabled({required super.exception})
    : super(requiresSettings: true);
}

/// Permission not granted; cause ambiguous. A new prompt may still work.
class LocationValidationPermissionDenied extends LocationValidationError {
  const LocationValidationPermissionDenied({required super.exception});
}

/// Permission blocked for this site / app; only settings can fix it.
class LocationValidationPermissionBlocked extends LocationValidationError {
  const LocationValidationPermissionBlocked({required super.exception})
    : super(requiresSettings: true);
}

/// No fix within the time limit.
class LocationValidationTimeout extends LocationValidationError {
  const LocationValidationTimeout({required super.exception});
}

/// The device could not produce a position.
class LocationValidationUnavailable extends LocationValidationError {
  const LocationValidationUnavailable({required super.exception});
}

/// A fix arrived but is too coarse to prove presence at the venue.
class LocationValidationAccuracyInsufficient extends LocationValidationError {
  const LocationValidationAccuracyInsufficient({required super.exception});
}
