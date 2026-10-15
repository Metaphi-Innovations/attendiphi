import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_checkin/app/router/auth_redirect.dart';
import 'package:qr_checkin/app/router/route_names.dart';

GoRouter _router({
  required String initialLocation,
  required bool isAuthenticated,
  bool mustResetPassword = false,
  bool hasPasswordResetCode = false,
  bool sessionResolved = true,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    redirect: (context, state) {
      return AuthRedirect.location(
        path: state.uri.path,
        sessionResolved: sessionResolved,
        isAuthenticated: isAuthenticated,
        mustResetPassword: mustResetPassword,
        hasPasswordResetCode: hasPasswordResetCode,
      );
    },
    routes: [
      GoRoute(
        path: RouteNames.adminLogin,
        builder: (context, state) => const Text('LOGIN'),
      ),
      GoRoute(
        path: RouteNames.adminAdmins,
        builder: (context, state) => const Text('ADMIN SHELL'),
      ),
      GoRoute(
        path: RouteNames.adminDashboard,
        builder: (context, state) => const Text('ADMIN SHELL'),
      ),
      GoRoute(
        path: RouteNames.adminResetPassword,
        builder: (context, state) => const Text('PASSWORD RESET'),
      ),
    ],
  );
}

void main() {
  testWidgets('logged-out visitor cannot enter the admin shell', (
    tester,
  ) async {
    final router = _router(
      initialLocation: RouteNames.adminDashboard,
      isAuthenticated: false,
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('ADMIN SHELL'), findsNothing);
  });

  testWidgets('logged-out visitor visiting /admins redirects to login', (
    tester,
  ) async {
    final router = _router(
      initialLocation: RouteNames.adminAdmins,
      isAuthenticated: false,
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('LOGIN'), findsOneWidget);
    expect(find.text('ADMIN SHELL'), findsNothing);
  });

  testWidgets('password reset with oobCode stays on the reset screen', (
    tester,
  ) async {
    final router = _router(
      initialLocation: RouteNames.adminResetPassword,
      isAuthenticated: false,
      hasPasswordResetCode: true,
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('PASSWORD RESET'), findsOneWidget);
    expect(find.text('ADMIN SHELL'), findsNothing);
  });

  testWidgets(
    'password reset without oobCode does not create an admin session',
    (tester) async {
      final router = _router(
        initialLocation: RouteNames.adminResetPassword,
        isAuthenticated: false,
        hasPasswordResetCode: false,
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.text('LOGIN'), findsOneWidget);
      expect(find.text('ADMIN SHELL'), findsNothing);
    },
  );
}
