import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../domain/usecases/parse_qr_code.dart';
import 'qr_scanner_state.dart';

/// Provider for the [ParseQrCode] usecase.
final parseQrCodeUseCaseProvider = Provider<ParseQrCode>((ref) {
  return const ParseQrCode();
});

/// Riverpod StateNotifier managing the QR scanning and validation lifecycle.
class QrScannerNotifier extends Notifier<QrScannerState> {
  @override
  QrScannerState build() {
    return const QrScannerInitial();
  }

  /// Handles a barcode detected by the mobile_scanner.
  Future<void> onQrCodeDetected(String rawCode) async {
    // Avoid re-processing if already busy
    if (state is QrScannerProcessing || state is QrScannerSuccess) {
      return;
    }

    state = QrScannerProcessing(rawCode: rawCode);
    AppLogger.info('QR detected: processing payload', tag: 'QrScanner');

    try {
      // 1. Parse & validate the QR payload structure
      final parseQr = ref.read(parseQrCodeUseCaseProvider);
      final payload = parseQr(rawCode);

      // 2. Query Firestore to verify location exists and is active
      final getLocationConfig = ref.read(getLocationConfigUseCaseProvider);
      final location = await getLocationConfig(payload.locationId);

      state = QrScannerSuccess(payload: payload, location: location);

      AppLogger.info(
        'QR verified: location "${location.name}" (ID: ${location.id}) is active',
        tag: 'QrScanner',
      );
    } on AppException catch (e) {
      AppLogger.logException(e, context: 'onQrCodeDetected', tag: 'QrScanner');
      state = QrScannerError(exception: e, rawCode: rawCode);
    } catch (e, st) {
      AppLogger.error(
        'Unexpected error processing QR: $e',
        error: e,
        stackTrace: st,
        tag: 'QrScanner',
      );
      state = QrScannerError(
        exception: ServerException(
          technicalMessage: 'Unexpected error: $e',
          originalError: e,
          stackTrace: st,
        ),
        rawCode: rawCode,
      );
    }
  }

  /// Resets the scanner back to the initial listening state.
  void reset() {
    state = const QrScannerInitial();
  }
}

/// Provider for [QrScannerNotifier].
final qrScannerProvider = NotifierProvider<QrScannerNotifier, QrScannerState>(
  () {
    return QrScannerNotifier();
  },
);
