import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_checkin/app/router/route_names.dart';
import 'package:qr_checkin/core/widgets/app_button.dart';
import 'package:qr_checkin/features/admin/data/datasources/admin_password_reset_service.dart';
import 'package:qr_checkin/features/admin/domain/admin_password_hasher.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/screens/admin_forgot_password_reset_screen.dart';
import 'package:qr_checkin/features/admin/presentation/screens/admin_forgot_password_screen.dart';
import 'package:qr_checkin/features/admin/presentation/screens/admin_login_screen.dart';

void main() {
  testWidgets('login shows Forgot Password below the password field',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.adminLogin,
            routes: [
              GoRoute(
                path: RouteNames.adminLogin,
                builder: (_, _) => const AdminLoginScreen(),
              ),
              GoRoute(
                path: RouteNames.adminForgotPassword,
                builder: (_, _) => const AdminForgotPasswordScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Forgot Password?'), findsOneWidget);
    expect(find.text('Sign In to Portal'), findsOneWidget);
  });

  testWidgets('forgot password request shows generic success copy',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    var sentTo = '';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPasswordResetServiceProvider.overrideWith(
            (ref) => AdminPasswordResetService(
              sendPasswordResetEmailFn: (email) async {
                sentTo = email;
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.adminForgotPassword,
            routes: [
              GoRoute(
                path: RouteNames.adminLogin,
                builder: (_, _) => const AdminLoginScreen(),
              ),
              GoRoute(
                path: RouteNames.adminForgotPassword,
                builder: (_, _) => const AdminForgotPasswordScreen(),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'unknown@example.com');
    await tester.tap(find.widgetWithText(AppButton, 'Send Reset Link'));
    await tester.pumpAndSettle();

    expect(find.text('✓ Check your email'), findsOneWidget);
    expect(
      find.textContaining('If an account exists for this email'),
      findsOneWidget,
    );
    expect(find.textContaining('Email does not exist'), findsNothing);
    expect(find.textContaining('No account found'), findsNothing);
    expect(sentTo, 'unknown@example.com');
  });

  testWidgets('reset page shows expired state for an empty token',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.adminForgotPasswordReset,
            routes: [
              GoRoute(
                path: RouteNames.adminForgotPassword,
                builder: (_, _) => const AdminForgotPasswordScreen(),
              ),
              GoRoute(
                path: RouteNames.adminForgotPasswordReset,
                builder: (_, _) =>
                    const AdminForgotPasswordResetScreen(token: ''),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reset Link Expired'), findsOneWidget);
    expect(find.text('Request New Link'), findsOneWidget);
  });

  testWidgets('resetPassword mode without oobCode shows expired state',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.adminResetPassword,
            routes: [
              GoRoute(
                path: RouteNames.adminLogin,
                builder: (_, _) => const AdminLoginScreen(),
              ),
              GoRoute(
                path: RouteNames.adminResetPassword,
                builder: (_, _) => const AdminForgotPasswordResetScreen(
                  mode: 'resetPassword',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reset Link Expired'), findsOneWidget);
  });

  testWidgets('invalid oobCode shows expired reset link', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPasswordResetServiceProvider.overrideWith(
            (ref) => AdminPasswordResetService(
              verifyPasswordResetCodeFn: (code) async {
                throw Exception('invalid-action-code');
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.adminResetPassword,
            routes: [
              GoRoute(
                path: RouteNames.adminLogin,
                builder: (_, _) => const AdminLoginScreen(),
              ),
              GoRoute(
                path: RouteNames.adminResetPassword,
                builder: (_, _) => const AdminForgotPasswordResetScreen(
                  mode: 'resetPassword',
                  oobCode: 'invalid-oob',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Reset Link Expired'), findsOneWidget);
  });

  testWidgets('password mismatch is blocked on the reset form', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPasswordResetServiceProvider.overrideWith(
            (ref) => AdminPasswordResetService(
              verifyPasswordResetCodeFn: (code) async => 'admin@example.com',
              confirmPasswordResetFn: ({required code, required newPassword}) async {
                fail('confirm must not run when passwords mismatch');
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.adminResetPassword,
            routes: [
              GoRoute(
                path: RouteNames.adminLogin,
                builder: (_, _) => const AdminLoginScreen(),
              ),
              GoRoute(
                path: RouteNames.adminResetPassword,
                builder: (_, _) => const AdminForgotPasswordResetScreen(
                  mode: 'resetPassword',
                  oobCode: 'good-oob',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPass@12');
    await tester.enterText(fields.at(1), 'OtherPass@12');
    await tester.tap(find.widgetWithText(AppButton, 'Reset Password'));
    await tester.pumpAndSettle();

    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(find.textContaining('Password Reset Successfully'), findsNothing);
  });

  testWidgets('successful confirmPasswordReset shows success and login',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    var confirmed = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminPasswordResetServiceProvider.overrideWith(
            (ref) => AdminPasswordResetService(
              verifyPasswordResetCodeFn: (code) async => 'admin@example.com',
              confirmPasswordResetFn: ({required code, required newPassword}) async {
                confirmed = true;
                expect(code, 'good-oob');
                expect(newPassword, 'NewPass@12');
              },
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: GoRouter(
            initialLocation: RouteNames.adminResetPassword,
            routes: [
              GoRoute(
                path: RouteNames.adminLogin,
                builder: (_, _) => const AdminLoginScreen(),
              ),
              GoRoute(
                path: RouteNames.adminResetPassword,
                builder: (_, _) => const AdminForgotPasswordResetScreen(
                  mode: 'resetPassword',
                  oobCode: 'good-oob',
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'NewPass@12');
    await tester.enterText(fields.at(1), 'NewPass@12');
    await tester.tap(find.widgetWithText(AppButton, 'Reset Password'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.textContaining('Password Reset Successfully'), findsOneWidget);
    expect(find.text('Sign In to Portal'), findsOneWidget);
  });

  test('hashed passwords match the Cloud Function scheme and login helper', () {
    const salt = 'abc123';
    const password = 'NewPass@12';
    final hash = AdminPasswordHasher.hash(password, salt);
    expect(hash.length, 64);

    const admin = AdminUser(
      id: 'adm-1',
      name: 'Asha',
      email: 'asha@example.com',
      phone: '9876543210',
      passwordHash: 'will-replace',
      passwordSalt: salt,
    );
    final hashedAdmin = AdminUser(
      id: admin.id,
      name: admin.name,
      email: admin.email,
      phone: admin.phone,
      passwordHash: hash,
      passwordSalt: salt,
    );
    expect(hashedAdmin.matchesPassword(password), isTrue);
    expect(hashedAdmin.matchesPassword('wrong'), isFalse);
    expect(hashedAdmin.matchesPassword(hash), isFalse);
  });

  test('legacy plaintext admin passwords still match', () {
    const admin = AdminUser(
      id: 'adm-2',
      name: 'Legacy',
      email: 'legacy@example.com',
      phone: '9876543211',
      plainPassword: 'TempPass@123',
      passwordHash: 'TempPass@123',
    );
    expect(admin.matchesPassword('TempPass@123'), isTrue);
    expect(admin.matchesPassword('nope'), isFalse);
  });
}
