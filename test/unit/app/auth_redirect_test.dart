import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/router/auth_redirect.dart';
import 'package:qr_checkin/app/router/route_names.dart';

void main() {
  test('logged-out visitor is sent from /admins to login', () {
    expect(
      AuthRedirect.location(
        path: RouteNames.adminAdmins,
        sessionResolved: true,
        isAuthenticated: false,
        mustResetPassword: false,
        hasPasswordResetCode: false,
      ),
      RouteNames.adminLogin,
    );
  });

  test('logged-out visitor cannot open the admin shell', () {
    for (final path in AuthRedirect.adminShellPaths) {
      expect(
        AuthRedirect.location(
          path: path,
          sessionResolved: true,
          isAuthenticated: false,
          mustResetPassword: false,
          hasPasswordResetCode: false,
        ),
        RouteNames.adminLogin,
        reason: path,
      );
    }
  });

  test(
    'password reset with oobCode stays public and does not authenticate',
    () {
      expect(
        AuthRedirect.location(
          path: RouteNames.adminResetPassword,
          sessionResolved: true,
          isAuthenticated: false,
          mustResetPassword: false,
          hasPasswordResetCode: true,
        ),
        isNull,
      );
    },
  );

  test('password reset without oobCode does not open an admin session', () {
    expect(
      AuthRedirect.location(
        path: RouteNames.adminResetPassword,
        sessionResolved: true,
        isAuthenticated: false,
        mustResetPassword: false,
        hasPasswordResetCode: false,
      ),
      RouteNames.adminLogin,
    );
  });

  test('check-in routes stay public', () {
    expect(
      AuthRedirect.location(
        path: '/checkin/location_x',
        sessionResolved: true,
        isAuthenticated: false,
        mustResetPassword: false,
        hasPasswordResetCode: false,
      ),
      isNull,
    );
  });

  test('unresolved session does not redirect', () {
    expect(
      AuthRedirect.location(
        path: RouteNames.adminAdmins,
        sessionResolved: false,
        isAuthenticated: false,
        mustResetPassword: false,
        hasPasswordResetCode: false,
      ),
      isNull,
    );
  });
}
