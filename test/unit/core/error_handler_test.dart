import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/core/errors/error_handler.dart';

void main() {
  group('ErrorHandler - getUserMessage', () {
    test('returns custom user message for AppException', () {
      const exception = LocationPermissionDeniedException();
      expect(ErrorHandler.getUserMessage(exception), exception.userMessage);
    });

    test('returns friendly fallback for generic exceptions', () {
      final error = Exception('Network error');
      expect(
        ErrorHandler.getUserMessage(error),
        'Something went wrong. Please try again.',
      );
    });
  });

  group('ErrorHandler - isRetryable', () {
    test('returns true for network and server timeouts', () {
      expect(
        ErrorHandler.isRetryable(const NetworkUnavailableException()),
        isTrue,
      );
      expect(
        ErrorHandler.isRetryable(const LocationTimeoutException()),
        isTrue,
      );
      expect(
        ErrorHandler.isRetryable(
          const ServerException(technicalMessage: '500 internal'),
        ),
        isTrue,
      );
    });

    test('location permission / services errors are retryable via Allow Location', () {
      expect(
        ErrorHandler.isRetryable(
          const LocationPermissionPermanentlyDeniedException(),
        ),
        isTrue,
      );
      expect(
        ErrorHandler.isRetryable(const LocationPermissionDeniedException()),
        isTrue,
      );
      expect(
        ErrorHandler.isRetryable(const LocationServiceDisabledException()),
        isTrue,
      );
    });

    test('returns false for non-retryable permanent errors', () {
      expect(ErrorHandler.isRetryable(const InvalidQrCodeException()), isFalse);
      expect(
        ErrorHandler.isRetryable(const DuplicateCheckInException()),
        isFalse,
      );
    });
  });

  group('ErrorHandler - requiresSettings', () {
    test('identifies errors that require opening app settings', () {
      expect(
        ErrorHandler.requiresSettings(
          const LocationPermissionPermanentlyDeniedException(),
        ),
        isTrue,
      );
      expect(
        ErrorHandler.requiresSettings(const LocationServiceDisabledException()),
        isTrue,
      );
      expect(
        ErrorHandler.requiresSettings(
          const LocationPermissionDeniedException(),
        ),
        isFalse,
      );
    });
  });
}
