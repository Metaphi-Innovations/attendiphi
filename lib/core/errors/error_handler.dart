import 'app_exception.dart';

/// Maps [AppException] types to user-friendly error messages.
///
/// This centralizes error → UI mapping so widgets don't need to
/// know about exception internals.
class ErrorHandler {
  ErrorHandler._();

  /// Returns the user-facing message for an error.
  ///
  /// Falls back to a generic message if the error is not an [AppException].
  static String getUserMessage(Object error) {
    if (error is AppException) {
      return error.userMessage;
    }
    return 'Something went wrong. Please try again.';
  }

  /// Returns whether the error is retryable.
  ///
  /// Network and timeout errors are typically retryable; auth/validation
  /// errors are not.
  static bool isRetryable(Object error) {
    return switch (error) {
      NetworkUnavailableException() => true,
      LocationTimeoutException() => true,
      LocationUnavailableException() => true,
      ServerException() => true,
      PhotoUploadFailedException() => true,
      CheckInSubmissionFailedException() => true,
      // Retryable via Allow Location / Retry (re-invokes browser/OS prompt).
      LocationPermissionDeniedException() => true,
      LocationPermissionPermanentlyDeniedException() => true,
      LocationServiceDisabledException() => true,
      InvalidQrCodeException() => false,
      MalformedQrPayloadException() => false,
      LocationNotFoundException() => false,
      LocationInactiveException() => false,
      OutsideAllowedRadiusException() => false,
      DuplicateCheckInException() => false,
      CameraPermissionDeniedException() => false,
      UnauthorizedException() => false,
      InvalidCredentialsException() => false,
      _ => false,
    };
  }

  /// Returns whether the error requires opening device settings.
  static bool requiresSettings(Object error) {
    return error is LocationPermissionPermanentlyDeniedException ||
        error is LocationServiceDisabledException;
  }
}
