import 'dart:convert';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/logger/app_logger.dart';
import '../check_in_session_token.dart';
import '../entities/qr_payload.dart';

/// Usecase responsible for parsing, validating, and extracting the [QrPayload]
/// from a raw barcode string.
///
/// Supports:
/// - JSON format: `{"locationId": "location_x"}`
/// - URI deep link format: `app://checkin?locationId=location_x`
/// - Plaintext ID: `location_x`
class ParseQrCode {
  const ParseQrCode();

  /// Parses the raw QR code string.
  ///
  /// Throws:
  /// - [InvalidQrCodeException] if the string is empty or invalid
  /// - [MalformedQrPayloadException] if JSON payload is missing the locationId field
  QrPayload call(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      throw const InvalidQrCodeException(
        userMessage: 'The scanned QR code is empty.',
        technicalMessage: 'Null or empty raw QR payload provided.',
      );
    }

    final trimmed = raw.trim();

    // 1. Try parsing as JSON
    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final locationId = decoded['locationId']?.toString().trim();
          if (locationId == null || locationId.isEmpty) {
            throw const MalformedQrPayloadException(
              userMessage: 'The QR code is missing a location identifier.',
              technicalMessage: 'JSON payload missing "locationId" key.',
            );
          }

          DateTime? timestamp;
          if (decoded.containsKey('timestamp')) {
            timestamp = DateTime.tryParse(decoded['timestamp'].toString());
          }

          return QrPayload(
            locationId: locationId,
            timestamp: timestamp,
            rawPayload: trimmed,
          );
        }
      } on AppException {
        rethrow;
      } catch (e, st) {
        AppLogger.warning(
          'Failed to decode JSON QR payload: $e',
          tag: 'ParseQrCode',
        );
        throw MalformedQrPayloadException(
          originalError: e,
          stackTrace: st,
        );
      }
    }

    // 2. Try parsing as URI, including path URLs and legacy hash URLs.
    //    New: https://attendiphi.metaphi.in/checkin/<opaque-token>
    //    Legacy: https://…/checkin-permission?date=…&locationId=…
    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final Map<String, String> params =
          Map<String, String>.from(uri.queryParameters);

      var path = uri.path;
      // Path query parameters plus legacy fragment query parameters.
      if (uri.hasFragment) {
        final fragment = uri.fragment;
        final fragUri = Uri.tryParse(
          fragment.contains('?') || fragment.startsWith('/')
              ? fragment
              : '/$fragment',
        );
        if (fragUri != null) {
          params.addAll(fragUri.queryParameters);
          if (fragUri.path.isNotEmpty) path = fragUri.path;
        }
      }

      final segments =
          path.split('/').where((s) => s.trim().isNotEmpty).toList();
      if (segments.length >= 2 && segments[segments.length - 2] == 'checkin') {
        final tokenSegment = segments.last;
        final claims = CheckInSessionToken.tryParse(tokenSegment);
        if (claims != null) {
          return QrPayload(
            locationId: claims.locationId,
            sessionDateStr: claims.sessionDateStr,
            adminId: claims.adminId ?? params['adminId']?.trim(),
            rawPayload: trimmed,
          );
        }
      }

      if (params.containsKey('locationId')) {
        final locationId = params['locationId']!.trim();
        if (locationId.isNotEmpty) {
          return QrPayload(
            locationId: locationId,
            sessionDateStr: params['date']?.trim(),
            adminId: params['adminId']?.trim(),
            rawPayload: trimmed,
          );
        }
      }
    }

    // 3. Opaque token pasted as bare path segment.
    final bareClaims = CheckInSessionToken.tryParse(trimmed);
    if (bareClaims != null) {
      return QrPayload(
        locationId: bareClaims.locationId,
        sessionDateStr: bareClaims.sessionDateStr,
        adminId: bareClaims.adminId,
        rawPayload: trimmed,
      );
    }

    // 4. Fallback: Treat as direct location identifier if alphanumeric and valid format
    // Valid locationId: 2-64 characters, letters, digits, underscores, dashes
    final validIdRegex = RegExp(r'^[a-zA-Z0-9_\-]{2,64}$');
    if (validIdRegex.hasMatch(trimmed)) {
      return QrPayload(
        locationId: trimmed,
        rawPayload: trimmed,
      );
    }

    throw const InvalidQrCodeException();
  }
}

