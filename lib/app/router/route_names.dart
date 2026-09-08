/// Named route constants for the application.
///
/// All route paths are defined here to avoid scattered string literals.
class RouteNames {
  RouteNames._();

  // ── Entry / Admin Flow ────────────────────────────────────────────────
  static const adminLogin = '/';
  static const adminResetPassword = '/admin-reset-password';
  static const venueQr = '/venue-qr';
  static const adminDashboard = '/admin-dashboard';
  static const adminAttendanceOverview = '/admin-attendance-overview';
  static const adminVisitors = '/admin-visitors';
  static const adminMembers = '/admin-members';
  static const adminUsers = '/admin-members';
  static const adminAdmins = '/admin-admins';
  static const checkinDetail = '/admin-dashboard/:checkInId';

  // ── Mobile Check-In Flow ──────────────────────────────────────────────
  static const qrScanner = '/scanner';
  static const locationPermission = '/checkin-permission';
  static const checkinResult = '/checkin-result';
  static const photoCapture = '/photo-capture';
  static const checkinForm = '/checkin/:locationId';

  // ── Helpers ──────────────────────────────────────────────────────────

  /// Builds the check-in form path for a specific location.
  static String checkinFormPath(String locationId) =>
      '/checkin/$locationId';

  /// Builds the photo capture path.
  static String photoCapturePath(String locationId) =>
      RouteNames.photoCapture;

  /// Builds the check-in detail path for a specific check-in.
  static String checkinDetailPath(String checkInId) =>
      '/admin-dashboard/$checkInId';
}
