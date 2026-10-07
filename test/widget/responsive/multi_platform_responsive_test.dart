import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/theme/app_theme.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_management_provider.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_scope_provider.dart';
import 'package:qr_checkin/features/admin/presentation/widgets/admin_inspection_banner.dart';
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/checkin/presentation/screens/checkin_result_screen.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:qr_checkin/features/employee/presentation/providers/employee_providers.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/presentation/screens/location_permission_screen.dart';
import 'package:qr_checkin/features/qr_checkin/presentation/widgets/qr_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  const testAdmin1 = AdminUser(
    id: 'adm-1',
    name: 'Omkar Anarse 2',
    email: 'attendiphi.metaphi@gmail.com',
    phone: '8356011246',
    role: AdminRole.admin,
    isActive: true,
  );

  const testAdmin2 = AdminUser(
    id: 'adm-2',
    name: 'Omkar Anarse',
    email: 'omkaranarse1906@gmail.com',
    phone: '8356011246',
    role: AdminRole.admin,
    isActive: true,
  );

  const testLocation = LocationConfig(
    id: 'loc-1',
    name: 'Jade Luxury Banquets, Mumbai',
    latitude: 18.9888622,
    longitude: 72.8152475,
    radiusMeters: 500.0,
    isActive: true,
    address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
  );

  group('Multi-Platform Viewport & Orientation Tests', () {
    testWidgets('AdminInspectionBanner renders cleanly on Phone Portrait (375x812) without overflowing', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSuperAdminProvider.overrideWithValue(true),
            activeAdminScopeProvider.overrideWith(() => _MockScopeNotifier(testAdmin1)),
            allAdminsStreamProvider.overrideWith((ref) => Stream.value([testAdmin1, testAdmin2])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: AdminInspectionBanner(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminInspectionBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('AdminInspectionBanner renders cleanly on Tablet Landscape (1024x768)', (tester) async {
      tester.view.physicalSize = const Size(1024, 768);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            isSuperAdminProvider.overrideWithValue(true),
            activeAdminScopeProvider.overrideWith(() => _MockScopeNotifier(testAdmin1)),
            allAdminsStreamProvider.overrideWith((ref) => Stream.value([testAdmin1, testAdmin2])),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const Scaffold(
              body: AdminInspectionBanner(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AdminInspectionBanner), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('QrOverlay renders centered viewfinder on Phone Landscape (812x375)', (tester) async {
      tester.view.physicalSize = const Size(812, 375);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: QrOverlay(scanWindowSize: 220),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QrOverlay), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('LocationPermissionScreen renders responsive layout on Tablet Portrait (768x1024)', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            restrictionsEnabledProvider.overrideWithValue(true),
            checkInRestrictionsConfigProvider.overrideWith(
              (ref) => Stream.value(
                const CheckInRestrictionsConfig(restrictionsEnabled: true),
              ),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: LocationPermissionScreen(
              location: testLocation,
              sessionDateStr: '2026-09-03',
              nowProvider: () => DateTime(2026, 9, 3, 10, 0),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Jade Luxury Banquets, Mumbai'), findsOneWidget);
      expect(find.textContaining('Allowed Perimeter:'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('CheckInResultScreen renders celebratory confirmation on Phone Portrait (375x812)', (tester) async {
      tester.view.physicalSize = const Size(375, 812);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            employeesStreamProvider.overrideWith(
              (ref) => Stream<List<Employee>>.value(const []),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light,
            home: const CheckInResultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Attendance Recorded'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

class _MockScopeNotifier extends AdminScopeNotifier {
  _MockScopeNotifier(this._initial);
  final AdminUser _initial;

  @override
  AdminUser? build() => _initial;
}
