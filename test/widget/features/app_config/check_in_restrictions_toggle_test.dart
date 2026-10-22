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

  testWidgets('Super Admin sees menu icon only (no master switch) on staging/dev', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSuperAdminProvider.overrideWithValue(true),
          currentAdminUserProvider.overrideWithValue(superAdmin),
          checkInRestrictionsConfigProvider.overrideWith(
            (ref) => Stream.value(
              const CheckInRestrictionsConfig(
                locationRestrictionEnabled: true,
                dateRestrictionEnabled: true,
        deviceRestrictionEnabled: true,
              ),
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
    expect(find.byIcon(Icons.menu), findsOneWidget);
  });

  testWidgets('Super Admin menu opens Location, Date, and Device toggles', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSuperAdminProvider.overrideWithValue(true),
          currentAdminUserProvider.overrideWithValue(superAdmin),
          checkInRestrictionsConfigProvider.overrideWith(
            (ref) => Stream.value(
              const CheckInRestrictionsConfig(
                locationRestrictionEnabled: true,
                dateRestrictionEnabled: true,
                deviceRestrictionEnabled: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: CheckInRestrictionsToggle()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    expect(find.text('Location restriction'), findsOneWidget);
    expect(find.text('Date restriction'), findsOneWidget);
    expect(find.text('One device = one check-in'), findsOneWidget);
  });

  testWidgets('Regular Admin does not see Restrictions control', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSuperAdminProvider.overrideWithValue(false),
          currentAdminUserProvider.overrideWithValue(regularAdmin),
          checkInRestrictionsConfigProvider.overrideWith(
            (ref) => Stream.value(
              const CheckInRestrictionsConfig(
                locationRestrictionEnabled: true,
                dateRestrictionEnabled: true,
        deviceRestrictionEnabled: true,
              ),
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
    expect(find.byIcon(Icons.menu), findsNothing);
  });
}
