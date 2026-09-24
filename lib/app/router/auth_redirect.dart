import 'route_names.dart';

/// Pure redirect helper. Router UX only — Firestore rules are authorization.
class AuthRedirect {
  AuthRedirect._();

  static const adminShellPaths = <String>{
    RouteNames.adminDashboard,
    RouteNames.adminAttendanceOverview,
    RouteNames.adminVisitors,
    RouteNames.adminMembers,
    RouteNames.venueQr,
    RouteNames.adminAdmins,
    RouteNames.attendiphiNamespace,
    RouteNames.legacyAttendiphiDashboard,
    RouteNames.legacyAttendiphiAttendanceOverview,
    RouteNames.legacyAttendiphiVisitors,
    RouteNames.legacyAttendiphiMembers,
    RouteNames.legacyAttendiphiVenueQr,
    RouteNames.legacyAttendiphiAdmins,
    RouteNames.legacyAdminDashboard,
    RouteNames.legacyAdminAttendanceOverview,
    RouteNames.legacyAdminVisitors,
    RouteNames.legacyAdminMembers,
    RouteNames.legacyVenueQr,
    RouteNames.legacyAdminAdmins,
  };

  static bool isPublicPath(
    String path, {
    required bool hasPasswordResetCode,
  }) {
    if (path == RouteNames.adminLogin) return true;
    if (path == RouteNames.adminForgotPassword) return true;
    if (path == RouteNames.adminForgotPasswordReset) return true;
    if (path == '/__/auth/action') return true;
    if (path == RouteNames.qrScanner) return true;
    if (path == RouteNames.locationPermission) return true;
    if (path == RouteNames.checkinResult) return true;
    if (path == RouteNames.photoCapture) return true;
    if (path.startsWith('/checkin/')) return true;
    if (path == RouteNames.adminResetPassword) {
      return hasPasswordResetCode;
    }
    return false;
  }

  static bool isAdminShellPath(String path) {
    if (adminShellPaths.contains(path)) return true;
    if (path.startsWith('${RouteNames.adminDashboard}/')) return true;
    return false;
  }

  /// Returns a new location or null to stay.
  static String? location({
    required String path,
    required bool sessionResolved,
    required bool isAuthenticated,
    required bool mustResetPassword,
    required bool hasPasswordResetCode,
  }) {
    if (!sessionResolved) return null;

    if (path == RouteNames.adminResetPassword && hasPasswordResetCode) {
      return null;
    }

    if (!isAuthenticated) {
      if (isPublicPath(path, hasPasswordResetCode: hasPasswordResetCode)) {
        return null;
      }
      return RouteNames.adminLogin;
    }

    if (mustResetPassword &&
        path != RouteNames.adminResetPassword &&
        !hasPasswordResetCode) {
      return RouteNames.adminResetPassword;
    }

    if (isAuthenticated &&
        path == RouteNames.adminLogin &&
        !mustResetPassword) {
      return RouteNames.adminDashboard;
    }

    return null;
  }
}
