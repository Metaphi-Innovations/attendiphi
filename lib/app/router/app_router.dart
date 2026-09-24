import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/metaphi_loading_indicator.dart';
import '../../features/admin/presentation/providers/admin_auth_provider.dart';
import '../../features/admin/presentation/screens/admin_dashboard_screen.dart';
import '../../features/admin/presentation/screens/admin_forgot_password_reset_screen.dart';
import '../../features/admin/presentation/screens/admin_forgot_password_screen.dart';
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
import 'auth_redirect.dart';
import 'route_names.dart';

/// Robust helper to extract query parameters on Native and Flutter Web.
///
/// Path URLs (`/checkin-permission?date=`) are the source of truth. Legacy
/// hash URLs (`#/checkin-permission?date=`) are still parsed for old QR codes.
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

/// Sends Firebase password-reset action links to [RouteNames.adminResetPassword].
///
/// Keeps [oobCode] in the query. Does not redirect when the app is already on
/// that screen (or the legacy `/reset-password` alias).
String? _firebasePasswordResetLocation(GoRouterState state) {
  final mode = _extractQueryParam(state, 'mode');
  final oobCode = _extractQueryParam(state, 'oobCode');
  if (mode != 'resetPassword' || oobCode == null || oobCode.isEmpty) {
    return null;
  }
  if (state.uri.path == RouteNames.adminResetPassword ||
      state.uri.path == RouteNames.adminForgotPasswordReset) {
    return null;
  }
  final apiKey = _extractQueryParam(state, 'apiKey');
  return Uri(
    path: RouteNames.adminResetPassword,
    queryParameters: {
      'mode': mode,
      'oobCode': oobCode,
      if (apiKey != null && apiKey.isNotEmpty) 'apiKey': apiKey,
    },
  ).toString();
}

/// Key for the root navigator.
final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Provider for the application's [GoRouter] configuration.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(adminAuthProvider, (_, _) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: RouteNames.adminLogin,
    debugLogDiagnostics: kDebugMode,
    refreshListenable: refresh,
    redirect: (context, state) {
      final resetLocation = _firebasePasswordResetLocation(state);
      if (resetLocation != null) return resetLocation;
      final auth = ref.read(adminAuthProvider);
      final oobCode = _extractQueryParam(state, 'oobCode');
      final token = _extractQueryParam(state, 'token');
      final hasPasswordResetCode =
          (oobCode != null && oobCode.isNotEmpty) ||
          (token != null && token.isNotEmpty);
      return AuthRedirect.location(
        path: state.uri.path,
        sessionResolved: auth.sessionResolved,
        isAuthenticated: auth.isAuthenticated,
        mustResetPassword: auth.currentAdmin?.mustResetPassword ?? false,
        hasPasswordResetCode: hasPasswordResetCode,
      );
    },
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
        builder: (context, state) {
          final token = _extractQueryParam(state, 'token');
          final oobCode = _extractQueryParam(state, 'oobCode');
          final mode = _extractQueryParam(state, 'mode');
          final hasEmailReset = (oobCode != null && oobCode.isNotEmpty) ||
              (token != null && token.isNotEmpty);
          if (hasEmailReset) {
            return PageLoadingTransitionWrapper(
              child: AdminForgotPasswordResetScreen(
                token: token,
                oobCode: oobCode,
                mode: mode,
              ),
            );
          }
          return const PageLoadingTransitionWrapper(
            child: AdminResetPasswordScreen(),
          );
        },
      ),
      GoRoute(
        path: RouteNames.adminForgotPassword,
        name: 'admin_forgot_password',
        builder: (context, state) => const PageLoadingTransitionWrapper(
          child: AdminForgotPasswordScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.adminForgotPasswordReset,
        name: 'admin_forgot_password_reset',
        redirect: (context, state) {
          final params = state.uri.queryParameters;
          if (params.isEmpty) {
            return RouteNames.adminResetPassword;
          }
          return Uri(
            path: RouteNames.adminResetPassword,
            queryParameters: params,
          ).toString();
        },
      ),
      GoRoute(
        path: '/__/auth/action',
        redirect: (context, state) {
          return _firebasePasswordResetLocation(state) ??
              RouteNames.adminLogin;
        },
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
          final submission = state.extra is CheckInSubmission
              ? state.extra as CheckInSubmission
              : null;
          final memberId =
              _extractQueryParam(state, 'memberId') ?? submission?.memberId;
          final checkInId =
              _extractQueryParam(state, 'checkInId') ?? submission?.id;
          return CheckInResultScreen(
            submission: submission,
            memberId: memberId,
            checkInId: checkInId,
          );
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
          ProximityResult? proximityResult;
          LocationConfig? initialLocation;
          if (state.extra is ProximityResult) {
            proximityResult = state.extra as ProximityResult;
          } else if (state.extra is LocationConfig) {
            initialLocation = state.extra as LocationConfig;
          } else if (state.extra is Map) {
            final map = state.extra as Map;
            if (map['proximity'] is ProximityResult) {
              proximityResult = map['proximity'] as ProximityResult;
            }
            if (map['location'] is LocationConfig) {
              initialLocation = map['location'] as LocationConfig;
            }
          }
          return CheckInFormScreen(
            key: ValueKey('checkin-$locationId-$queryDate-$queryAdminId'),
            locationId: locationId,
            initialLocation: initialLocation,
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
