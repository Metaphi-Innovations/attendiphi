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
  static const adminUsers = '/members';
  static const venueQr = '/qr-standee';
  static const adminAdmins = '/admins';
  static const checkinDetail = '/daily-attendance/:checkInId';

  // ── Legacy Routes (for seamless backwards compatibility) ──────────────
  static const attendiphiNamespace = '/attendiphi-by-metaphi';
  static const legacyAttendiphiDashboard =
      '/attendiphi-by-metaphi/daily-attendance';
  static const legacyAttendiphiAttendanceOverview =
      '/attendiphi-by-metaphi/attendance-overview';
  static const legacyAttendiphiVisitors = '/attendiphi-by-metaphi/visitors';
  static const legacyAttendiphiMembers = '/attendiphi-by-metaphi/members';
  static const legacyAttendiphiVenueQr = '/attendiphi-by-metaphi/qr-standee';
  static const legacyAttendiphiAdmins = '/attendiphi-by-metaphi/admins';
  static const legacyAdminDashboard = '/admin-dashboard';
  static const legacyAdminAttendanceOverview = '/admin-attendance-overview';
  static const legacyAdminVisitors = '/admin-visitors';
  static const legacyAdminMembers = '/admin-members';
  static const legacyVenueQr = '/venue-qr';
  static const legacyAdminAdmins = '/admin-admins';

  // ── Mobile Check-In Flow ──────────────────────────────────────────────
  static const qrScanner = '/scanner';
  static const locationPermission = '/checkin-permission';
  static const checkinResult = '/checkin-result';
  static const photoCapture = '/photo-capture';
  static const checkinForm = '/checkin/:locationId';

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

  /// Builds the check-in form path for a specific location.
  static String checkinFormPath(String locationId) =>
      '/checkin/$locationId';

  /// Builds the photo capture path.
  static String photoCapturePath(String locationId) =>
      RouteNames.photoCapture;

  /// Builds the check-in detail path for a specific check-in.
  static String checkinDetailPath(String checkInId) =>
      '/daily-attendance/$checkInId';
}
