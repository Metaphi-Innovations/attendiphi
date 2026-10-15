import 'package:flutter/foundation.dart';

import 'check_in_session_token.dart';

/// Resolved public check-in session (from opaque token or legacy URL).
class ResolvedCheckInSession {
  const ResolvedCheckInSession({
    required this.locationId,
    required this.sessionDateStr,
    this.adminId,
    this.sessionToken,
    this.isLegacy = false,
  });

  final String locationId;
  final String? sessionDateStr;
  final String? adminId;

  /// Opaque path token when available (preferred for in-app navigation).
  final String? sessionToken;
  final bool isLegacy;
}

/// Resolves `/checkin/:segment` plus optional legacy query params.
///
/// - Preferred: `/checkin/<v1.…>` opaque token
/// - Legacy: `/checkin/<locationId>?date=yyyy-MM-dd` — **rejected in release**
///   after standee cutover (P1). Debug/profile still accept legacy for local QA.
ResolvedCheckInSession? resolveCheckInSession({
  required String? pathSegment,
  String? queryDate,
  String? queryAdminId,
  String? queryLocationId,
  String? secretOverride,
  bool? rejectLegacy,
}) {
  final segment = pathSegment?.trim() ?? '';
  final blockLegacy = rejectLegacy ?? kReleaseMode;

  if (CheckInSessionToken.looksLikeToken(segment)) {
    final claims = CheckInSessionToken.tryParse(
      segment,
      secretOverride: secretOverride,
    );
    if (claims == null) return null;
    return ResolvedCheckInSession(
      locationId: claims.locationId,
      sessionDateStr: claims.sessionDateStr,
      adminId: claims.adminId ?? _trimOrNull(queryAdminId),
      sessionToken: segment,
      isLegacy: false,
    );
  }

  // Legacy path: /checkin/location_x?date=YYYY-MM-DD
  if (blockLegacy) return null;

  final legacyLocation = CheckInSessionToken.looksLikeLegacyLocationId(segment)
      ? segment
      : _trimOrNull(queryLocationId);
  if (legacyLocation == null) return null;

  final date = _trimOrNull(queryDate);
  final admin = _trimOrNull(queryAdminId);
  String? token;
  if (date != null) {
    try {
      token = CheckInSessionToken.create(
        locationId: legacyLocation,
        sessionDate: date,
        adminId: admin,
        secretOverride: secretOverride,
      );
    } catch (_) {
      token = null;
    }
  }

  return ResolvedCheckInSession(
    locationId: legacyLocation,
    sessionDateStr: date,
    adminId: admin,
    sessionToken: token,
    isLegacy: true,
  );
}

String? _trimOrNull(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
