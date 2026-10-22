import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_management_provider.dart';
import 'package:qr_checkin/features/admin/presentation/screens/admin_management_screen.dart';

import 'admin_widget_auth_mocks.dart';

void main() {
  group('AdminManagementScreen Widget Tests', () {
    final mockAdmins = [
      AdminUser(
        id: 'adm-1',
        name: 'Rahul Sharma',
        email: 'rahul@example.com',
        phone: '9876543210',
        role: AdminRole.admin,
        isActive: true,
        createdAt: DateTime(2026, 9, 1),
      ),
      AdminUser(
        id: 'adm-2',
        name: 'Sneha Patil',
        email: 'sneha@example.com',
        phone: '9123456780',
        role: AdminRole.admin,
        isActive: false,
        createdAt: DateTime(2026, 9, 2),
      ),
    ];

    testWidgets(
      'renders Admin Management and allows admin to see only admins created by himself',
      (tester) async {
        const currentAdminUser = AdminUser(
          id: 'adm-omkar',
          name: 'Omkar Anarse',
          email: 'omkar@metaphi.com',
          phone: '9998887776',
          role: AdminRole.admin,
          createdBy: 'super_admin_master',
        );

        final adminsList = [
          const AdminUser(
            id: 'adm-super-created',
            name: 'Super Created Admin',
            email: 'super_created@example.com',
            phone: '9000000001',
            createdBy: 'super_admin_master',
          ),
          const AdminUser(
            id: 'adm-omkar-created',
            name: 'Omkar Sub Admin',
            email: 'omkar_sub@example.com',
            phone: '9000000002',
            createdBy: 'adm-omkar',
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminAuthProvider.overrideWith(
                () => MockAuthenticatedAdminAuthNotifier(currentAdminUser),
              ),
              allAdminsStreamProvider.overrideWith(
                (ref) => Stream.value(adminsList),
              ),
            ],
            child: const MaterialApp(home: AdminManagementScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Admin Management'), findsOneWidget);
        expect(find.text('Create Admin'), findsWidgets);

        // Can see admin created by himself
        expect(find.text('Omkar Sub Admin'), findsOneWidget);

        // Cannot see admin created by Super Admin
        expect(find.text('Super Created Admin'), findsNothing);
      },
    );

    testWidgets('renders Admin Management and admin table for Super Admin', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith(
              () => MockAuthenticatedAdminAuthNotifier(kWidgetTestSuperAdmin),
            ),
            allAdminsStreamProvider.overrideWith(
              (ref) => Stream.value(mockAdmins),
            ),
          ],
          child: const MaterialApp(home: AdminManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Admin Management'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Sneha Patil'), findsOneWidget);
    });

    testWidgets('clicking Create Admin opens dialog with form fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith(
              () => MockAuthenticatedAdminAuthNotifier(kWidgetTestSuperAdmin),
            ),
            allAdminsStreamProvider.overrideWith(
              (ref) => Stream.value(mockAdmins),
            ),
          ],
          child: const MaterialApp(home: AdminManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      final createBtn = find.widgetWithText(FilledButton, 'Create Admin').first;
      expect(createBtn, findsOneWidget);

      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      expect(find.text('Create New Admin'), findsOneWidget);
      expect(find.text('Full Name *'), findsOneWidget);
      expect(find.text('Phone Number *'), findsOneWidget);
      expect(find.textContaining('Email Address *'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Create Admin'), findsWidgets);
      expect(find.text('Open in Gmail'), findsNothing);
      expect(find.text('Create & Send Email'), findsNothing);
      expect(find.textContaining('Gmail will not open'), findsNothing);
    });

    testWidgets('renders action menus and info for each listed admin', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith(
              () => MockAuthenticatedAdminAuthNotifier(kWidgetTestSuperAdmin),
            ),
            allAdminsStreamProvider.overrideWith(
              (ref) => Stream.value(mockAdmins),
            ),
          ],
          child: const MaterialApp(home: AdminManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Open Workspace'), findsNothing);
      expect(find.byIcon(Icons.more_vert_rounded), findsNWidgets(2));
    });

    testWidgets(
      'renders persistent search input and table without stat cards',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminAuthProvider.overrideWith(
                () => MockAuthenticatedAdminAuthNotifier(kWidgetTestSuperAdmin),
              ),
              allAdminsStreamProvider.overrideWith(
                (ref) => Stream.value(mockAdmins),
              ),
            ],
            child: const MaterialApp(home: AdminManagementScreen()),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('Total Admins'), findsNothing);
        expect(find.text('Active Admins'), findsNothing);
        expect(find.text('Inactive Admins'), findsNothing);
        expect(find.text('SUPER ADMIN ONLY'), findsNothing);

        expect(find.byIcon(Icons.search), findsOneWidget);
        expect(find.text('Search admin by name, email...'), findsOneWidget);

        expect(find.text('ADMIN (2)'), findsOneWidget);
        expect(find.text('EMAIL'), findsOneWidget);
        expect(find.text('PHONE'), findsOneWidget);
        expect(find.text('STATUS'), findsOneWidget);
        expect(find.text('CREATED ON'), findsOneWidget);
        expect(find.text('ACTIONS'), findsOneWidget);
      },
    );

    testWidgets('does not list Super Admin profiles in the admin table', (
      tester,
    ) async {
      const superAdmin = AdminUser(
        id: 'uid-super',
        name: 'Super Admin',
        email: 'super@example.com',
        phone: '9999999999',
        role: AdminRole.superAdmin,
        isActive: true,
      );
      final listWithSuper = [...mockAdmins, superAdmin];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminAuthProvider.overrideWith(
              () => MockAuthenticatedAdminAuthNotifier(superAdmin),
            ),
            allAdminsStreamProvider.overrideWith(
              (ref) => Stream.value(listWithSuper),
            ),
          ],
          child: const MaterialApp(home: AdminManagementScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('super@example.com'), findsNothing);
      expect(find.text('ADMIN (2)'), findsOneWidget);
    });
  });
}
