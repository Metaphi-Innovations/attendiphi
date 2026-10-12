import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Opaque, HMAC-signed check-in session token for public URLs.
///
/// Public URL shape:
/// `https://attendiphi.metaphi.in/checkin/<token>`
///
/// Token format: `v1.<base64url(payload)>.<base64url(hmac)>`
/// Payload (UTF-8): `locationId|sessionDate|adminId`
///
/// Signing secret:
/// - Prefer `--dart-define=CHECKIN_SESSION_TOKEN_SECRET=...` (see
///   `scripts/build_web_release.sh`)
/// - Tests may pass [secretOverride]
/// - Debug/profile without a define uses [bootstrapSecret]
/// - **Flutter Web release** without a define also uses [bootstrapSecret]:
///   dart-defines are extractable from the JS bundle, so an empty define
///   must not blank QR Standee / check-in. Prefer injecting a long random
///   define in production Hosting builds anyway.
/// - **Non-web release** without a define still throws [StateError]
class CheckInSessionToken {
  CheckInSessionToken._();

  static const tokenPrefix = 'v1.';
  static const dartDefineSecret = String.fromEnvironment(
    'CHECKIN_SESSION_TOKEN_SECRET',
    defaultValue: '',
  );

  /// Fallback integrity key for debug and for Web release when no dart-define
  /// was baked in. Not a confidential server secret.
  static const bootstrapSecret = 'attendiphi-checkin-session-hmac-v1';

  /// Matches [scripts/build_web_release.sh] minimum length.
  static const minSecretLength = 16;

  /// True when the compile-time dart-define is non-empty and meets
  /// [minSecretLength]. Short non-empty defines are rejected, not treated
  /// as configured.
  static bool get hasConfiguredSecret {
    final value = dartDefineSecret.trim();
    return value.length >= minSecretLength;
  }

  /// True when [signingSecret] would return [bootstrapSecret]
  /// (empty define / no override, and bootstrap is allowed for this build).
  ///
  /// Short non-empty defines are not bootstrap: [signingSecret] throws.
  static bool isUsingBootstrapSecret({String? secretOverride}) {
    final override = secretOverride?.trim() ?? '';
    if (override.isNotEmpty) return false;
    final fromDefine = dartDefineSecret.trim();
    if (fromDefine.isNotEmpty) return false;
    return !kReleaseMode || kIsWeb;
  }

  /// Resolves the HMAC key. Extracted for unit tests of release/web policy.
  @visibleForTesting
  static String resolveSigningSecret({
    required String fromDefine,
    required bool isRelease,
    required bool isWeb,
    String? secretOverride,
  }) {
    final override = secretOverride?.trim() ?? '';
    if (override.isNotEmpty) {
      _assertMinSecretLength(override, source: 'secretOverride');
      return override;
    }
    final defined = fromDefine.trim();
    if (defined.isNotEmpty) {
      _assertMinSecretLength(
        defined,
        source: 'CHECKIN_SESSION_TOKEN_SECRET',
      );
      return defined;
    }
    // Web bundles already expose dart-defines; prefer working check-in over
    // a blank QR Standee when Hosting was deployed without the define.
    if (isRelease && !isWeb) {
      throw StateError(
        'CHECKIN_SESSION_TOKEN_SECRET dart-define is required for release '
        'builds. Pass --dart-define=CHECKIN_SESSION_TOKEN_SECRET=<secret> '
        'with at least $minSecretLength characters '
        '(see scripts/build_web_release.sh).',
      );
    }
    return bootstrapSecret;
  }

  static String signingSecret({String? secretOverride}) {
    return resolveSigningSecret(
      fromDefine: dartDefineSecret,
      isRelease: kReleaseMode,
      isWeb: kIsWeb,
      secretOverride: secretOverride,
    );
  }

  static void _assertMinSecretLength(String secret, {required String source}) {
    if (secret.length >= minSecretLength) return;
    throw StateError(
      '$source must be at least $minSecretLength characters '
      '(see scripts/build_web_release.sh).',
    );
  }

  /// True when [segment] looks like a v1 session token (not a legacy locationId).
  static bool looksLikeToken(String? segment) {
    final value = segment?.trim() ?? '';
    if (!value.startsWith(tokenPrefix)) return false;
    final parts = value.split('.');
    return parts.length == 3 &&
        parts[0] == 'v1' &&
        parts[1].isNotEmpty &&
        parts[2].isNotEmpty;
  }

  /// Legacy plaintext location id path segment (e.g. `location_x`).
  static bool looksLikeLegacyLocationId(String? segment) {
    final value = segment?.trim() ?? '';
    if (value.isEmpty || looksLikeToken(value)) return false;
    return RegExp(r'^[a-zA-Z0-9_\-]{2,64}$').hasMatch(value);
  }

  /// Creates a URL-safe opaque path token.
  static String create({
    required String locationId,
    required String sessionDate,
    String? adminId,
    String? secretOverride,
  }) {
    final loc = locationId.trim();
    final date = sessionDate.trim();
    if (loc.isEmpty) {
      throw ArgumentError.value(locationId, 'locationId', 'must not be empty');
    }
    if (!_isValidSessionDate(date)) {
      throw ArgumentError.value(
        sessionDate,
        'sessionDate',
        'must be yyyy-MM-dd',
      );
    }
    final admin = (adminId ?? '').trim();
    final payload = '$loc|$date|$admin';
    final payloadB64 = _base64UrlEncode(utf8.encode(payload));
    final mac = _hmac(
      payload: payload,
      secret: signingSecret(secretOverride: secretOverride),
    );
    final macB64 = _base64UrlEncode(mac);
    return '$tokenPrefix$payloadB64.$macB64';
  }

  /// Parses and verifies a token. Returns null when invalid / tampered.
  static CheckInSessionClaims? tryParse(
    String? token, {
    String? secretOverride,
  }) {
    try {
      return parse(token, secretOverride: secretOverride);
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    } on StateError {
      return null;
    }
  }

  /// Parses and verifies a token. Throws [FormatException] when invalid.
  static CheckInSessionClaims parse(
    String? token, {
    String? secretOverride,
  }) {
    final raw = token?.trim() ?? '';
    if (!looksLikeToken(raw)) {
      throw const FormatException('Not a check-in session token');
    }
    final parts = raw.split('.');
    final payloadB64 = parts[1];
    final macB64 = parts[2];

    late final List<int> payloadBytes;
    late final List<int> providedMac;
    try {
      payloadBytes = _base64UrlDecode(payloadB64);
      providedMac = _base64UrlDecode(macB64);
    } catch (_) {
      throw const FormatException('Malformed check-in session token');
    }

    final payload = utf8.decode(payloadBytes);
    final expectedMac = _hmac(
      payload: payload,
      secret: signingSecret(secretOverride: secretOverride),
    );
    if (!_constantTimeEquals(expectedMac, providedMac)) {
      throw const FormatException('Invalid check-in session token signature');
    }

    final fields = payload.split('|');
    if (fields.length != 3) {
      throw const FormatException('Invalid check-in session token payload');
    }
    final locationId = fields[0].trim();
    final sessionDate = fields[1].trim();
    final adminId = fields[2].trim();
    if (locationId.isEmpty || !_isValidSessionDate(sessionDate)) {
      throw const FormatException('Invalid check-in session token fields');
    }

    return CheckInSessionClaims(
      locationId: locationId,
      sessionDateStr: sessionDate,
      adminId: adminId.isEmpty ? null : adminId,
    );
  }

  static bool _isValidSessionDate(String value) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    if (parsed == null) return false;
    final ymd =
        '${parsed.year.toString().padLeft(4, '0')}-'
        '${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
    return ymd == value;
  }

  static List<int> _hmac({required String payload, required String secret}) {
    final key = utf8.encode(secret);
    final bytes = utf8.encode(payload);
    return Hmac(sha256, key).convert(bytes).bytes;
  }

  static String _base64UrlEncode(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static List<int> _base64UrlDecode(String value) {
    var normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    final mod = normalized.length % 4;
    if (mod > 0) {
      normalized = normalized.padRight(normalized.length + (4 - mod), '=');
    }
    return base64.decode(normalized);
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Verified claims recovered from a [CheckInSessionToken].
class CheckInSessionClaims {
  const CheckInSessionClaims({
    required this.locationId,
    required this.sessionDateStr,
    this.adminId,
  });

  final String locationId;
  final String sessionDateStr;
  final String? adminId;
}
