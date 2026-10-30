import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/app_config/data/repositories/app_config_repository_impl.dart';
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/app_config/presentation/widgets/check_in_restrictions_toggle.dart';

import '../admin/admin_widget_auth_mocks.dart';

class _FakeAppConfigRepository implements AppConfigRepository {
  _FakeAppConfigRepository(this._config);

  CheckInRestrictionsConfig _config;
  bool? lastLocationWrite;
  bool? lastDeviceWrite;

  final _controller = StreamController<CheckInRestrictionsConfig>.broadcast();

  @override
  Stream<CheckInRestrictionsConfig> watchCheckInRestrictions() async* {
    yield _config;
    yield* _controller.stream;
  }

  @override
  Future<void> setCheckInRestrictions({
    bool? restrictionsEnabled,
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    bool? deviceRestrictionEnabled,
    required String updatedBy,
    String? updatedByEmail,
  }) async {
    lastLocationWrite = locationRestrictionEnabled;
    lastDeviceWrite = deviceRestrictionEnabled;
    _config = CheckInRestrictionsConfig(
      locationRestrictionEnabled:
          locationRestrictionEnabled ?? _config.locationRestrictionEnabled,
      dateRestrictionEnabled:
          dateRestrictionEnabled ?? _config.dateRestrictionEnabled,
      deviceRestrictionEnabled:
          deviceRestrictionEnabled ?? _config.deviceRestrictionEnabled,
    );
    _controller.add(_config);
  }
}

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

  testWidgets('Super Admin sees menu icon only (no master switch)', (
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

  testWidgets(
    'Location toggle OFF writes immediately without confirmation pop-up',
    (tester) async {
      final repo = _FakeAppConfigRepository(
        const CheckInRestrictionsConfig(
          locationRestrictionEnabled: true,
          dateRestrictionEnabled: true,
          deviceRestrictionEnabled: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSuperAdminProvider.overrideWithValue(true),
            currentAdminUserProvider.overrideWithValue(superAdmin),
            adminAuthProvider.overrideWith(
              () => MockAuthenticatedAdminAuthNotifier(superAdmin),
            ),
            appConfigRepositoryProvider.overrideWithValue(repo),
            checkInRestrictionsConfigProvider.overrideWith(
              (ref) => repo.watchCheckInRestrictions(),
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

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(find.text('Turn off location restriction?'), findsNothing);
      expect(find.text('Turn OFF'), findsNothing);
      expect(repo.lastLocationWrite, isFalse);
      expect(find.textContaining('Updated — Location OFF'), findsOneWidget);
    },
  );

  testWidgets(
    'One device = one check-in toggle OFF writes and stays OFF',
    (tester) async {
      final repo = _FakeAppConfigRepository(
        const CheckInRestrictionsConfig(
          locationRestrictionEnabled: true,
          dateRestrictionEnabled: true,
          deviceRestrictionEnabled: true,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSuperAdminProvider.overrideWithValue(true),
            currentAdminUserProvider.overrideWithValue(superAdmin),
            adminAuthProvider.overrideWith(
              () => MockAuthenticatedAdminAuthNotifier(superAdmin),
            ),
            appConfigRepositoryProvider.overrideWithValue(repo),
            checkInRestrictionsConfigProvider.overrideWith(
              (ref) => repo.watchCheckInRestrictions(),
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

      // Third switch: Location, Date, Device.
      await tester.tap(find.byType(Switch).at(2));
      await tester.pumpAndSettle();

      expect(repo.lastDeviceWrite, isFalse);
      expect(find.textContaining('Device OFF'), findsOneWidget);

      // Switch must remain OFF (no snap-back to ON after reload).
      final deviceSwitch = tester.widget<Switch>(find.byType(Switch).at(2));
      expect(deviceSwitch.value, isFalse);
    },
  );

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
