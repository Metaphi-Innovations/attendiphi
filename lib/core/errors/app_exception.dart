import '../l10n/app_strings.dart';

/// Sealed exception hierarchy for the QR Check-In application.
///
/// Each exception carries a [userMessage] for display and a
/// [technicalMessage] for developer logging.
sealed class AppException implements Exception {
  const AppException({
    required this.userMessage,
    required this.technicalMessage,
    this.originalError,
    this.stackTrace,
  });

  /// User-friendly message safe to display in the UI.
  final String userMessage;

  /// Technical message for developer logs / Crashlytics.
  final String technicalMessage;

  /// The original error that caused this exception, if any.
  final Object? originalError;

  /// Stack trace from the original error, if available.
  final StackTrace? stackTrace;

  @override
  String toString() => '$runtimeType: $technicalMessage';
}

// ── Location ──────────────────────────────────────────────────────────────

/// Location permission was not granted and the cause is ambiguous (prompt
/// dismissed, or the browser could not tell device Location was off).
class LocationPermissionDeniedException extends AppException {
  const LocationPermissionDeniedException({
    super.userMessage = AppStrings.locationPermissionDenied,
    super.technicalMessage = 'Location permission denied by user.',
    super.originalError,
    super.stackTrace,
  });
}

/// Location permission is blocked for this site / app (requires settings).
class LocationPermissionPermanentlyDeniedException extends AppException {
  const LocationPermissionPermanentlyDeniedException({
    super.userMessage = AppStrings.locationPermissionPermanentlyDenied,
    super.technicalMessage =
        'Location permission permanently denied. Requires settings change.',
    super.originalError,
    super.stackTrace,
  });
}

/// Device location services are turned off.
class LocationServiceDisabledException extends AppException {
  const LocationServiceDisabledException({
    super.userMessage = AppStrings.locationServiceDisabled,
    super.technicalMessage = 'Device location services disabled.',
    super.originalError,
    super.stackTrace,
  });
}

/// Unable to obtain a GPS position.
class LocationUnavailableException extends AppException {
  const LocationUnavailableException({
    super.userMessage = AppStrings.locationUnavailable,
    super.technicalMessage = 'GPS position unavailable.',
    super.originalError,
    super.stackTrace,
  });
}

/// GPS location request timed out.
class LocationTimeoutException extends AppException {
  const LocationTimeoutException({
    super.userMessage = AppStrings.locationTimeout,
    super.technicalMessage = 'Location request timed out.',
    super.originalError,
    super.stackTrace,
  });
}

/// GPS accuracy is too low for reliable verification.
class LocationAccuracyTooLowException extends AppException {
  LocationAccuracyTooLowException({
    required double accuracy,
    super.userMessage = AppStrings.locationAccuracyTooLow,
    String? technicalMessage,
    super.originalError,
    super.stackTrace,
  }) : super(
         technicalMessage:
             technicalMessage ?? 'GPS accuracy too low: ${accuracy}m.',
       );
}

// ── QR Code ───────────────────────────────────────────────────────────────

/// QR code data is invalid or unrecognized.
class InvalidQrCodeException extends AppException {
  const InvalidQrCodeException({
    super.userMessage = 'This QR code is not valid for check-in.',
    super.technicalMessage = 'Invalid QR code scanned.',
    super.originalError,
    super.stackTrace,
  });
}

/// QR code payload is malformed (missing fields, bad JSON).
class MalformedQrPayloadException extends AppException {
  const MalformedQrPayloadException({
    super.userMessage =
        'The QR code could not be read. Please try scanning again.',
    super.technicalMessage = 'Malformed QR payload.',
    super.originalError,
    super.stackTrace,
  });
}

/// The locationId from the QR code was not found.
class LocationNotFoundException extends AppException {
  const LocationNotFoundException({
    super.userMessage = 'This check-in location was not found. Please contact your administrator.',
    super.technicalMessage = 'Location not found.',
    super.originalError,
    super.stackTrace,
  });
}

/// The location exists but is currently inactive.
class LocationInactiveException extends AppException {
  const LocationInactiveException({
    super.userMessage = 'This check-in location is currently inactive.',
    super.technicalMessage = 'Location is inactive.',
    super.originalError,
    super.stackTrace,
  });
}

// ── Check-In ──────────────────────────────────────────────────────────────

/// User is outside the allowed radius.
class OutsideAllowedRadiusException extends AppException {
  OutsideAllowedRadiusException({
    required this.distanceMeters,
    required this.allowedRadiusMeters,
    String? userMessage,
    String? technicalMessage,
    super.originalError,
    super.stackTrace,
  }) : super(
         userMessage:
             userMessage ??
             'You are approximately ${distanceMeters.round()} meters away '
                 'from the check-in location.\n\n'
                 'Please move closer and try again.',
         technicalMessage:
             technicalMessage ??
             'User is ${distanceMeters.round()}m away, '
                 'allowed radius is ${allowedRadiusMeters}m.',
       );

  final double distanceMeters;
  final double allowedRadiusMeters;
}

/// Check-in was a duplicate (idempotency key already used).
class DuplicateCheckInException extends AppException {
  const DuplicateCheckInException({
    super.userMessage =
        'You have already checked in. Duplicate submissions are not allowed.',
    super.technicalMessage = 'Duplicate check-in submission detected.',
    this.existingSubmissionData,
    super.originalError,
    super.stackTrace,
  });

  final Map<String, dynamic>? existingSubmissionData;
}

/// Check-in submission failed (generic server error).
class CheckInSubmissionFailedException extends AppException {
  const CheckInSubmissionFailedException({
    super.userMessage = 'Check-in failed. Please try again.',
    super.technicalMessage = 'Check-in submission failed.',
    super.originalError,
    super.stackTrace,
  });
}

/// Substitute check-in is missing a face photo.
class MissingSubstitutePhotoException extends AppException {
  const MissingSubstitutePhotoException({
    super.userMessage = 'A face photo is required for substitute check-in.',
    super.technicalMessage = 'Substitute check-in missing photo.',
    super.originalError,
    super.stackTrace,
  });
}

// ── Camera ────────────────────────────────────────────────────────────────

/// Camera permission was denied.
class CameraPermissionDeniedException extends AppException {
  const CameraPermissionDeniedException({
    super.userMessage =
        'Camera permission is required to take a verification photo.',
    super.technicalMessage = 'Camera permission denied.',
    super.originalError,
    super.stackTrace,
  });
}

/// Failed to capture a photo.
class PhotoCaptureFailedException extends AppException {
  const PhotoCaptureFailedException({
    super.userMessage = 'Unable to access the camera. Please try again.',
    super.technicalMessage = 'Photo capture failed.',
    super.originalError,
    super.stackTrace,
  });
}

/// Photo upload to storage failed.
class PhotoUploadFailedException extends AppException {
  const PhotoUploadFailedException({
    super.userMessage = 'Photo upload failed. Please try again.',
    super.technicalMessage = 'Photo upload to storage failed.',
    super.originalError,
    super.stackTrace,
  });
}

// ── Network ───────────────────────────────────────────────────────────────

/// No internet connection available.
class NetworkUnavailableException extends AppException {
  const NetworkUnavailableException({
    super.userMessage =
        'No internet connection. Please reconnect and try again.',
    super.technicalMessage = 'Network unavailable.',
    super.originalError,
    super.stackTrace,
  });
}

/// Server returned an unexpected error.
class ServerException extends AppException {
  const ServerException({
    super.userMessage = 'Something went wrong. Please try again.',
    required super.technicalMessage,
    super.originalError,
    super.stackTrace,
  });
}

// ── Auth ──────────────────────────────────────────────────────────────────

/// User is not authorized (missing admin role, etc.).
class UnauthorizedException extends AppException {
  const UnauthorizedException({
    super.userMessage = 'You do not have administrator access.',
    super.technicalMessage = 'Unauthorized access attempt.',
    super.originalError,
    super.stackTrace,
  });
}

/// Invalid login credentials.
class InvalidCredentialsException extends AppException {
  const InvalidCredentialsException({
    super.userMessage = 'Invalid email or password.',
    super.technicalMessage = 'Authentication failed: invalid credentials.',
    super.originalError,
    super.stackTrace,
  });
}
