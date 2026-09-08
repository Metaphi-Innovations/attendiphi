import '../../../../core/errors/app_exception.dart';
import '../../../location/domain/entities/location_config.dart';
import '../../domain/entities/qr_payload.dart';

/// Sealed state representation for the QR Scanner screen.
sealed class QrScannerState {
  const QrScannerState();
}

/// Initial camera view state, ready to scan.
class QrScannerInitial extends QrScannerState {
  const QrScannerInitial();
}

/// Barcode detected, currently parsing payload and verifying with Firestore.
class QrScannerProcessing extends QrScannerState {
  const QrScannerProcessing({required this.rawCode});

  final String rawCode;
}

/// QR payload validated and location verified active in Firestore.
class QrScannerSuccess extends QrScannerState {
  const QrScannerSuccess({
    required this.payload,
    required this.location,
  });

  final QrPayload payload;
  final LocationConfig location;
}

/// QR scan or location verification failed.
class QrScannerError extends QrScannerState {
  const QrScannerError({
    required this.exception,
    this.rawCode,
  });

  final AppException exception;
  final String? rawCode;
}
