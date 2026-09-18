import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/metaphi_loading_indicator.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_login_screen.dart';
import '../../features/admin/presentation/screens/admin_management_screen.dart';
import '../../features/admin/presentation/screens/admin_reset_password_screen.dart';
import '../../features/admin/presentation/screens/attendance_overview_screen.dart';
import '../../features/admin/presentation/screens/user_management_screen.dart';
import '../../features/admin/presentation/screens/visitor_management_screen.dart';
import '../../features/admin/presentation/widgets/admin_shell_layout.dart';
import '../../features/checkin/domain/entities/check_in_submission.dart';
import '../../features/checkin/presentation/screens/checkin_form_screen.dart';
import '../../features/checkin/presentation/screens/checkin_result_screen.dart';
import '../../features/location/domain/entities/location_config.dart';
import '../../features/location/domain/usecases/validate_user_proximity.dart';
import '../../features/location/presentation/screens/location_permission_screen.dart';
import '../../features/qr_checkin/presentation/screens/qr_scanner_screen.dart';
import '../../features/qr_checkin/presentation/screens/venue_qr_display_screen.dart';
import '../../features/substitute/presentation/screens/photo_capture_screen.dart';
import 'route_names.dart';

/// Robust helper to extract query parameters on both Native and Flutter Web (with hash routing).
String? _extractQueryParam(GoRouterState state, String key) {
  final val = state.uri.queryParameters[key];
  if (val != null && val.trim().isNotEmpty) return val.trim();

  if (kIsWeb) {
    if (Uri.base.queryParameters.containsKey(key)) {
      final baseVal = Uri.base.queryParameters[key];
      if (baseVal != null && baseVal.trim().isNotEmpty) return baseVal.trim();
    }
    if (Uri.base.hasFragment && Uri.base.fragment.contains('?')) {
      final fragIndex = Uri.base.fragment.indexOf('?');
      final queryStr = Uri.base.fragment.substring(fragIndex + 1);
      final parsed = Uri.splitQueryString(queryStr);
      if (parsed.containsKey(key) && parsed[key]!.trim().isNotEmpty) {
        return parsed[key]!.trim();
      }
    }
  }
  return null;
}

/// Key for the root navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Provider for the application's [GoRouter] configuration.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.adminLogin,
    debugLogDiagnostics: kDebugMode,
    routes: [
      // ── 1. Superadmin & Sub-admin Entry Point ──────────────────────────────
      GoRoute(
        path: RouteNames.adminLogin,
        name: 'admin_login',
        builder: (context, state) => const PageLoadingTransitionWrapper(
          child: AdminLoginScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminResetPassword,
        name: 'admin_reset_password',
        builder: (context, state) => const PageLoadingTransitionWrapper(
          child: AdminResetPasswordScreen(),
        ),
      ),

      // ── Redirects: attendiphi namespace root & legacy routes ───────────────
      GoRoute(
        path: RouteNames.attendiphiNamespace,
        redirect: (context, state) => RouteNames.adminDashboard,
      ),
      GoRoute(
        path: RouteNames.legacyAttendiphiDashboard,
        redirect: (context, state) => RouteNames.adminDashboard,
      ),
      GoRoute(
        path: RouteNames.legacyAttendiphiAttendanceOverview,
        redirect: (context, state) => RouteNames.adminAttendanceOverview,
      ),
      GoRoute(
        path: RouteNames.legacyAttendiphiVisitors,
        redirect: (context, state) => RouteNames.adminVisitors,
      ),
      GoRoute(
        path: RouteNames.legacyAttendiphiMembers,
        redirect: (context, state) => RouteNames.adminMembers,
      ),
      GoRoute(
        path: RouteNames.legacyAttendiphiVenueQr,
        redirect: (context, state) => RouteNames.venueQr,
      ),
      GoRoute(
        path: RouteNames.legacyAttendiphiAdmins,
        redirect: (context, state) => RouteNames.adminAdmins,
      ),
      GoRoute(
        path: RouteNames.legacyAdminDashboard,
        redirect: (context, state) => RouteNames.adminDashboard,
      ),
      GoRoute(
        path: RouteNames.legacyAdminAttendanceOverview,
        redirect: (context, state) => RouteNames.adminAttendanceOverview,
      ),
      GoRoute(
        path: RouteNames.legacyAdminVisitors,
        redirect: (context, state) => RouteNames.adminVisitors,
      ),
      GoRoute(
        path: RouteNames.legacyAdminMembers,
        redirect: (context, state) => RouteNames.adminMembers,
      ),
      GoRoute(
        path: RouteNames.legacyVenueQr,
        redirect: (context, state) => RouteNames.venueQr,
      ),
      GoRoute(
        path: RouteNames.legacyAdminAdmins,
        redirect: (context, state) => RouteNames.adminAdmins,
      ),

      // ── 2. Admin Portal Persistent Shell (Dashboard, Members, QR Standee) ───
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AdminShellLayout(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Attendance Dashboard
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.adminDashboard,
                name: 'admin_dashboard',
                builder: (context, state) => const AdminDashboardScreen(),
              ),
            ],
          ),

          // Branch 1: Attendance Overview Matrix
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.adminAttendanceOverview,
                name: 'admin_attendance_overview',
                builder: (context, state) => const AttendanceOverviewScreen(),
              ),
            ],
          ),

          // Branch 2: Visitors Management & Records
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.adminVisitors,
                name: 'admin_visitors',
                builder: (context, state) => const VisitorManagementScreen(),
              ),
            ],
          ),

          // Branch 3: Member / Employee Management
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.adminMembers,
                name: 'admin_members',
                builder: (context, state) => const UserManagementScreen(),
              ),
            ],
          ),

          // Branch 4: Venue QR Standee Display
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.venueQr,
                name: 'venue_qr',
                builder: (context, state) => const VenueQrDisplayScreen(),
              ),
            ],
          ),

          // Branch 5: Admins Management
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.adminAdmins,
                name: 'admin_admins',
                builder: (context, state) => const AdminManagementScreen(),
              ),
            ],
          ),
        ],
      ),

      // ── 4. Mobile Attendee Check-In Flow ───────────────────────────────────
      GoRoute(
        path: RouteNames.locationPermission,
        name: 'location_permission',
        builder: (context, state) {
          final queryAdminId = _extractQueryParam(state, 'adminId');
          final queryDate = _extractQueryParam(state, 'date');
          final location =
              state.extra as LocationConfig? ??
              const LocationConfig(
                id: 'location_x',
                name: 'Excel Plaza, Ghatkopar',
                latitude: 19.083462,
                longitude: 72.914026,
                radiusMeters: 500.0,
                isActive: true,
                address: 'EXCEL PLAZA, Pant Nagar, Ghatkopar East, Mumbai, Maharashtra 400075',
              );
          return LocationPermissionScreen(
            location: location,
            adminId: queryAdminId,
            sessionDateStr: queryDate,
          );
        },
      ),
      GoRoute(
        path: RouteNames.checkinResult,
        name: 'checkin_result',
        builder: (context, state) {
          final submission = state.extra as CheckInSubmission?;
          return CheckInResultScreen(submission: submission);
        },
      ),
      GoRoute(
        path: RouteNames.photoCapture,
        name: 'photo_capture',
        builder: (context, state) => const PhotoCaptureScreen(),
      ),
      GoRoute(
        path: RouteNames.checkinForm,
        name: 'checkin_form',
        builder: (context, state) {
          final locationId = state.pathParameters['locationId'] ??
              _extractQueryParam(state, 'locationId') ??
              'location_x';
          final queryAdminId = _extractQueryParam(state, 'adminId');
          final queryDate = _extractQueryParam(state, 'date');
          final proximityResult = state.extra as ProximityResult?;
          return CheckInFormScreen(
            key: ValueKey('checkin-${state.pageKey}'),
            locationId: locationId,
            proximityResult: proximityResult,
            adminId: queryAdminId,
            sessionDateStr: queryDate,
          );
        },
      ),
      GoRoute(
        path: RouteNames.qrScanner,
        name: 'qr_scanner',
        builder: (context, state) => const PageLoadingTransitionWrapper(
          child: QrScannerScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page Not Found')),
      body: Center(
        child: Text(
          'Error 404: ${state.error?.message ?? "Page not found"}',
          textAlign: TextAlign.center,
        ),
      ),
    ),
  );
});
