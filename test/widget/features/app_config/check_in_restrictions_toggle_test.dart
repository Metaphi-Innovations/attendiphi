import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/app_config/presentation/widgets/check_in_restrictions_toggle.dart';

void main() {
  const superAdmin = AdminUser(
    id: 'uid-super',
    name: 'Super Admin',
    email: 'super@example.com',
    phone: '9999999999',
    role: AdminRole.superAdmin,
    isActive: true,
  );

  const regularAdmin = AdminUser(
    id: 'uid-admin',
    name: 'Rahul Sharma',
    email: 'rahul@example.com',
    phone: '9876543210',
    role: AdminRole.admin,
    isActive: true,
    createdBy: 'uid-super',
  );

  testWidgets('Super Admin sees compact Restrictions toggle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSuperAdminProvider.overrideWithValue(true),
          currentAdminUserProvider.overrideWithValue(superAdmin),
          checkInRestrictionsConfigProvider.overrideWith(
            (ref) => Stream.value(
              const CheckInRestrictionsConfig(restrictionsEnabled: true),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CheckInRestrictionsToggle()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Check-in Restrictions'), findsNothing);
    expect(find.textContaining('Test mode'), findsNothing);
    expect(find.textContaining('Last updated'), findsNothing);
    expect(find.text('Restrictions'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
  });

  testWidgets('Regular Admin does not see Restrictions toggle', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSuperAdminProvider.overrideWithValue(false),
          currentAdminUserProvider.overrideWithValue(regularAdmin),
          checkInRestrictionsConfigProvider.overrideWith(
            (ref) => Stream.value(
              const CheckInRestrictionsConfig(restrictionsEnabled: true),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CheckInRestrictionsToggle()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Restrictions'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });
}
