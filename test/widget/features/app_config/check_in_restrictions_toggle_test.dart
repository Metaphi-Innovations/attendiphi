import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/constants/app_constants.dart';
import 'package:qr_checkin/core/l10n/app_strings.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/domain/substitute_check_in_mapping.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/app_config/data/repositories/app_config_repository_impl.dart';
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/app_config/presentation/widgets/check_in_restrictions_toggle.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/domain/repositories/location_repository.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_providers.dart';

import '../admin/admin_widget_auth_mocks.dart';

class _FakeLocationRepository implements LocationRepository {
  _FakeLocationRepository({this.radiusMeters = 500});

  double radiusMeters;
  String? lastUpdatedLocationId;
  double? lastUpdatedRadiusMeters;
  int invalidateReads = 0;

  @override
  Future<LocationConfig> getLocationConfig(String locationId) async {
    invalidateReads++;
    return LocationConfig(
      id: locationId,
      name: 'Test Venue',
      latitude: 19.08,
      longitude: 72.91,
      radiusMeters: radiusMeters,
    );
  }

  @override
  Stream<List<LocationConfig>> getLocations() => const Stream.empty();

  @override
  Future<void> updateRadiusMeters({
    required String locationId,
    required double radiusMeters,
  }) async {
    lastUpdatedLocationId = locationId;
    lastUpdatedRadiusMeters = radiusMeters;
    this.radiusMeters = radiusMeters;
  }
}

List<dynamic> _locationOverrides(_FakeLocationRepository repo) => [
  locationRepositoryProvider.overrideWithValue(repo),
  locationConfigFamilyProvider.overrideWith((ref, locationId) async {
    return repo.getLocationConfig(locationId);
  }),
];

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
    final locationRepo = _FakeLocationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSuperAdminProvider.overrideWithValue(true),
          currentAdminUserProvider.overrideWithValue(superAdmin),
          ..._locationOverrides(locationRepo),
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
    final locationRepo = _FakeLocationRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSuperAdminProvider.overrideWithValue(true),
          currentAdminUserProvider.overrideWithValue(superAdmin),
          ..._locationOverrides(locationRepo),
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
    expect(find.text(AppStrings.venueCheckInRadiusTitle), findsOneWidget);
    expect(find.text(AppStrings.venueCheckInRadiusUnitMeters), findsWidgets);
    expect(
      find.text(AppStrings.venueCheckInRadiusUnitKilometers),
      findsWidgets,
    );
  });

  testWidgets(
    'Location restriction OFF hides venue radius controls',
    (tester) async {
      final locationRepo = _FakeLocationRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSuperAdminProvider.overrideWithValue(true),
            currentAdminUserProvider.overrideWithValue(superAdmin),
            ..._locationOverrides(locationRepo),
            checkInRestrictionsConfigProvider.overrideWith(
              (ref) => Stream.value(
                const CheckInRestrictionsConfig(
                  locationRestrictionEnabled: false,
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

      expect(find.text(AppStrings.venueCheckInRadiusTitle), findsNothing);
      expect(find.text(AppStrings.venueCheckInRadiusSave), findsNothing);
    },
  );

  testWidgets(
    'saving 30 km persists 30000 meters and refreshes location config',
    (tester) async {
      final locationRepo = _FakeLocationRepository(
        radiusMeters: AppConstants.defaultRadiusMeters,
      );
      final appRepo = _FakeAppConfigRepository(
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
            appConfigRepositoryProvider.overrideWithValue(appRepo),
            checkInRestrictionsConfigProvider.overrideWith(
              (ref) => appRepo.watchCheckInRestrictions(),
            ),
            ..._locationOverrides(locationRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CheckInRestrictionsToggle()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text(AppStrings.venueCheckInRadiusUnitKilometers),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '30');
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.venueCheckInRadiusSave));
      await tester.pumpAndSettle();

      expect(locationRepo.lastUpdatedLocationId, kDefaultAdminLocationId);
      expect(locationRepo.lastUpdatedRadiusMeters, 30000);
      expect(find.textContaining(AppStrings.venueCheckInRadiusSaved), findsOneWidget);
      expect(find.textContaining('30 km'), findsOneWidget);
    },
  );

  testWidgets(
    'typing 50 then selecting km saves 50000 m (not 50 m)',
    (tester) async {
      final locationRepo = _FakeLocationRepository(
        radiusMeters: AppConstants.defaultRadiusMeters,
      );
      final appRepo = _FakeAppConfigRepository(
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
            appConfigRepositoryProvider.overrideWithValue(appRepo),
            checkInRestrictionsConfigProvider.overrideWith(
              (ref) => appRepo.watchCheckInRestrictions(),
            ),
            ..._locationOverrides(locationRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CheckInRestrictionsToggle()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Type first while still on meters, then flip to km — digits must stay 50.
      await tester.enterText(find.byType(TextField), '50');
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(AppStrings.venueCheckInRadiusUnitKilometers),
      );
      await tester.pumpAndSettle();

      expect(tester.widget<TextField>(find.byType(TextField)).controller?.text, '50');

      await tester.tap(find.text(AppStrings.venueCheckInRadiusSave));
      await tester.pumpAndSettle();

      expect(locationRepo.lastUpdatedRadiusMeters, 50000);
      expect(find.textContaining('50 km'), findsOneWidget);
    },
  );

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
      final locationRepo = _FakeLocationRepository();

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
            ..._locationOverrides(locationRepo),
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
      final locationRepo = _FakeLocationRepository();

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
            ..._locationOverrides(locationRepo),
          ],
          child: const MaterialApp(
            home: Scaffold(body: CheckInRestrictionsToggle()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();

      // Device switch is below the radius editor — scroll it into view.
      final deviceTile = find.text('One device = one check-in');
      await tester.ensureVisible(deviceTile);
      await tester.pumpAndSettle();

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
