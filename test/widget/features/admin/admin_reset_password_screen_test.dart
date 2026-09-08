import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/widgets/app_button.dart';
import 'package:qr_checkin/core/widgets/app_text_field.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/screens/admin_reset_password_screen.dart';

class MockAdminAuthNotifier extends AdminAuthNotifier {
  final AdminUser? initialAdmin;
  MockAdminAuthNotifier([this.initialAdmin]);

  @override
  AdminAuthState build() {
    return AdminAuthState(
      isAuthenticated: true,
      currentAdmin: initialAdmin,
    );
  }
}

void main() {
  group('AdminResetPasswordScreen Widget Tests', () {
    const testAdmin = AdminUser(
      id: 'test-adm-1',
      name: 'Rohan Deshmukh',
      email: 'rohan@example.com',
      phone: '9876543210',
      role: AdminRole.admin,
      plainPassword: 'TempPass@123',
      mustResetPassword: true,
      isActive: true,
    );

    testWidgets('renders reset password screen with info card and form fields',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith(() => MockAdminAuthNotifier(testAdmin)),
          ],
          child: const MaterialApp(
            home: AdminResetPasswordScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Set Your Permanent Password'), findsOneWidget);
      expect(find.text('Rohan Deshmukh'), findsOneWidget);
      expect(find.text('rohan@example.com'), findsOneWidget);
      expect(find.text('Enter new permanent password'), findsOneWidget);
      expect(find.text('Re-enter your new password'), findsOneWidget);
      expect(find.text('Password Requirements:'), findsOneWidget);
      expect(find.text('Save Password & Enter Portal'), findsOneWidget);
    });

    testWidgets('validates password minimum length and mismatch',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith(() => MockAdminAuthNotifier(testAdmin)),
          ],
          child: const MaterialApp(
            home: AdminResetPasswordScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap submit with empty fields
      final submitBtn = find.widgetWithText(AppButton, 'Save Password & Enter Portal');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please enter a new password'), findsOneWidget);

      // Enter short password
      final textFields = find.byType(AppTextField);
      await tester.enterText(textFields.at(0), 'short');
      await tester.enterText(textFields.at(1), 'mismatch');
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Password must be at least 8 characters'), findsOneWidget);
    });
  });
}
