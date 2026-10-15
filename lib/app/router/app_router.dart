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
import '../../features/admin/presentation/screens/substitute_detail_screen.dart';
import '../../features/admin/presentation/screens/substitutes_overview_screen.dart';
import '../../features/admin/presentation/screens/user_management_screen.dart';
import '../../features/admin/presentation/screens/visitor_management_screen.dart';
import '../../features/admin/presentation/widgets/admin_shell_layout.dart';
import '../../features/checkin/domain/entities/check_in_submission.dart';
import '../../features/checkin/presentation/screens/checkin_form_screen.dart';
import '../../features/checkin/presentation/screens/checkin_result_screen.dart';
import '../../features/location/domain/entities/location_config.dart';
import '../../features/location/domain/usecases/validate_user_proximity.dart';
import '../../features/location/presentation/screens/location_permission_screen.dart';
import '../../features/qr_checkin/domain/resolve_check_in_session.dart';
import '../../features/qr_checkin/presentation/screens/qr_scanner_screen.dart';
import '../../features/qr_checkin/presentation/screens/venue_qr_display_screen.dart';
import '../../features/substitute/presentation/screens/photo_capture_screen.dart';
import 'auth_redirect.dart';
import 'route_names.dart';

/// Robust helper to extract query parameters on Native and Flutter Web.
///
/// Path URLs (`/checkin-permission?date=`) are still parsed for legacy QR
/// codes. Preferred public entry is `/checkin/<opaque-token>`.
String? _extractQueryParam(GoRouterState state, String key) {
  final val = state.uri.queryParameters[key];
  if (val != null && val.trim().isNotEmpty) return val.trim();

  if (kIsWeb) {
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

/// Parses the URL hash fragment (`#access_token=…&type=recovery`) used by
/// Supabase implicit-flow recovery links. Returns an empty map when absent.
Map<String, String> _recoveryFragmentParams() {
  if (!kIsWeb || !Uri.base.hasFragment) return const {};
  var fragment = Uri.base.fragment;
  if (fragment.startsWith('/')) return const {};
  if (fragment.startsWith('?')) fragment = fragment.substring(1);
  if (!fragment.contains('=')) return const {};
  try {
    return Uri.splitQueryString(fragment);
  } catch (_) {
    return const {};
  }
}

/// True when the current URL is a Supabase password-recovery landing: either
/// a hash fragment with `type=recovery` / an auth error, or a PKCE `?code=`
/// redirect on the reset-password path.
bool _isSupabaseRecoveryLanding(GoRouterState state) {
  final frag = _recoveryFragmentParams();
  if (frag['type'] == 'recovery') return true;
  if (frag.containsKey('error_code') || frag.containsKey('error')) {
    return state.uri.path == RouteNames.adminResetPassword;
  }
  if (state.uri.path == RouteNames.adminResetPassword) {
    final code = _extractQueryParam(state, 'code');
    if (code != null && code.isNotEmpty) return true;
  }
  return false;
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
      final isRecovery = _isSupabaseRecoveryLanding(state);
      // Supabase may land recovery links on the site root; send them to the
      // reset screen (the recovery session is already established by then).
      if (isRecovery &&
          state.uri.path != RouteNames.adminResetPassword &&
          _recoveryFragmentParams()['type'] == 'recovery') {
        return RouteNames.adminResetPassword;
      }
      final auth = ref.read(adminAuthProvider);
      final oobCode = _extractQueryParam(state, 'oobCode');
      final token = _extractQueryParam(state, 'token');
      final hasPasswordResetCode =
          isRecovery ||
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
        builder: (context, state) =>
            const PageLoadingTransitionWrapper(child: AdminLoginScreen()),
      ),
      GoRoute(
        path: RouteNames.adminResetPassword,
        name: 'admin_reset_password',
        builder: (context, state) {
          final token = _extractQueryParam(state, 'token');
          final oobCode = _extractQueryParam(state, 'oobCode');
          var mode = _extractQueryParam(state, 'mode');
          final isRecovery = _isSupabaseRecoveryLanding(state);
          if (isRecovery) mode = 'recovery';
          final hasEmailReset =
              isRecovery ||
              (oobCode != null && oobCode.isNotEmpty) ||
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
        path: RouteNames.legacyAttendiphiSubstitutes,
        redirect: (context, state) => RouteNames.adminSubstitutes,
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
        path: RouteNames.legacyAdminSubstitutes,
        redirect: (context, state) => RouteNames.adminSubstitutes,
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

          // Branch 4: Substitutes attendance analytics
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.adminSubstitutes,
                name: 'admin_substitutes',
                builder: (context, state) => const SubstitutesOverviewScreen(),
                routes: [
                  GoRoute(
                    path: ':identityKey',
                    name: 'admin_substitute_detail',
                    builder: (context, state) {
                      final raw = state.pathParameters['identityKey'] ?? '';
                      return SubstituteDetailScreen(
                        identityKey: Uri.decodeComponent(raw),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),

          // Branch 5: Venue QR Standee Display
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: RouteNames.venueQr,
                name: 'venue_qr',
                builder: (context, state) => const VenueQrDisplayScreen(),
              ),
            ],
          ),

          // Branch 6: Admins Management
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
                name: 'Jade Luxury Banquets, Mumbai',
                latitude: 18.9888622,
                longitude: 72.8152475,
                radiusMeters: 500.0,
                isActive: true,
                address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
              );
          // Include full URI so a fresh QR open remounts and re-prompts location
          // instead of keeping a prior Deny state.
          return LocationPermissionScreen(
            key: ValueKey(state.uri.toString()),
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
          final pathSegment = state.pathParameters['sessionToken'];
          final queryAdminId = _extractQueryParam(state, 'adminId');
          final queryDate = _extractQueryParam(state, 'date');
          final queryLocationId = _extractQueryParam(state, 'locationId');

          final resolved = resolveCheckInSession(
            pathSegment: pathSegment,
            queryDate: queryDate,
            queryAdminId: queryAdminId,
            queryLocationId: queryLocationId,
          );
          if (resolved == null) {
            return const _InvalidCheckInSessionScreen();
          }

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

          final location =
              initialLocation ??
              LocationConfig(
                id: resolved.locationId,
                name: resolved.locationId == 'location_x'
                    ? 'Jade Luxury Banquets, Mumbai'
                    : resolved.locationId,
                latitude: 18.9888622,
                longitude: 72.8152475,
                radiusMeters: 500.0,
                isActive: true,
                address: resolved.locationId == 'location_x'
                    ? 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018'
                    : '',
              );

          // Deep link / QR open: run GPS gate first, then form.
          if (proximityResult == null) {
            return LocationPermissionScreen(
              key: ValueKey(
                'perm-${resolved.sessionToken ?? resolved.locationId}-${resolved.sessionDateStr}',
              ),
              location: location,
              adminId: resolved.adminId,
              sessionDateStr: resolved.sessionDateStr,
              sessionToken: resolved.sessionToken,
            );
          }

          return CheckInFormScreen(
            key: ValueKey(
              'checkin-${resolved.locationId}-${resolved.sessionDateStr}-${resolved.adminId}',
            ),
            locationId: resolved.locationId,
            initialLocation: location,
            proximityResult: proximityResult,
            adminId: resolved.adminId,
            sessionDateStr: resolved.sessionDateStr,
            sessionToken: resolved.sessionToken,
          );
        },
      ),
      GoRoute(
        path: RouteNames.qrScanner,
        name: 'qr_scanner',
        builder: (context, state) =>
            const PageLoadingTransitionWrapper(child: QrScannerScreen()),
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

/// Shown when `/checkin/<segment>` is not a valid opaque token or legacy link.
class _InvalidCheckInSessionScreen extends StatelessWidget {
  const _InvalidCheckInSessionScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invalid Check-In Link')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'This check-in link is invalid or has been tampered with.\n'
            'Please scan the official QR standee for today’s session.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
