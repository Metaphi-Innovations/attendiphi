/// Named route constants for the application.
///
/// All route paths are defined here to avoid scattered string literals.
class RouteNames {
  RouteNames._();

  // ── Entry / Admin Flow ────────────────────────────────────────────────
  static const adminLogin = '/';
  static const adminResetPassword = '/admin-reset-password';
  static const adminForgotPassword = '/forgot-password';
  static const adminForgotPasswordReset = '/reset-password';

  // ── Admin Portal Tabs ─────────────────────────────────────────────────
  static const adminDashboard = '/daily-attendance';
  static const adminAttendanceOverview = '/attendance-overview';
  static const adminVisitors = '/visitors';
  static const adminMembers = '/members';
  static const adminSubstitutes = '/substitutes';
  static const venueQr = '/qr-standee';
  static const adminAdmins = '/admins';

  // ── Legacy Routes (for seamless backwards compatibility) ──────────────
  static const attendiphiNamespace = '/attendiphi-by-metaphi';
  static const legacyAttendiphiDashboard =
      '/attendiphi-by-metaphi/daily-attendance';
  static const legacyAttendiphiAttendanceOverview =
      '/attendiphi-by-metaphi/attendance-overview';
  static const legacyAttendiphiVisitors = '/attendiphi-by-metaphi/visitors';
  static const legacyAttendiphiMembers = '/attendiphi-by-metaphi/members';
  static const legacyAttendiphiSubstitutes =
      '/attendiphi-by-metaphi/substitutes';
  static const legacyAttendiphiVenueQr = '/attendiphi-by-metaphi/qr-standee';
  static const legacyAttendiphiAdmins = '/attendiphi-by-metaphi/admins';
  static const legacyAdminDashboard = '/admin-dashboard';
  static const legacyAdminAttendanceOverview = '/admin-attendance-overview';
  static const legacyAdminVisitors = '/admin-visitors';
  static const legacyAdminMembers = '/admin-members';
  static const legacyAdminSubstitutes = '/admin-substitutes';
  static const legacyVenueQr = '/venue-qr';
  static const legacyAdminAdmins = '/admin-admins';

  /// Detail path for a substitute identity key (`p:…` / `n:…` / `id:…`).
  static String substituteDetailPath(String identityKey) =>
      '$adminSubstitutes/${Uri.encodeComponent(identityKey)}';

  // ── Mobile Check-In Flow ──────────────────────────────────────────────
  static const qrScanner = '/scanner';
  static const locationPermission = '/checkin-permission';
  static const checkinResult = '/checkin-result';
  static const photoCapture = '/photo-capture';

  /// Public check-in entry: `/checkin/<opaque-token>` (legacy: `/checkin/<locationId>`).
  static const checkinForm = '/checkin/:sessionToken';

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Builds the Successful screen path with stable identity query params.
  static String checkinResultPath({String? checkInId, String? memberId}) {
    final params = <String, String>{};
    final id = checkInId?.trim() ?? '';
    final mid = memberId?.trim() ?? '';
    if (id.isNotEmpty) params['checkInId'] = id;
    if (mid.isNotEmpty) params['memberId'] = mid;
    if (params.isEmpty) return checkinResult;
    return Uri(path: checkinResult, queryParameters: params).toString();
  }

  /// Builds the check-in path for an opaque session token (preferred).
  ///
  /// Pass a token from `CheckInSessionToken.create(...)`. Legacy call sites
  /// may still pass a locationId for dual-read (`/checkin/location_x?date=`).
  static String checkinFormPath(String sessionTokenOrLocationId) =>
      '/checkin/${sessionTokenOrLocationId.trim()}';

  /// Builds the photo capture path.
  static String photoCapturePath() => RouteNames.photoCapture;
}
