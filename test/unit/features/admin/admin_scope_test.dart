import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_management_provider.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_scope_provider.dart';

void main() {
  group('AdminScopeNotifier Unit Tests', () {
    const regularAdmin = AdminUser(
      id: 'adm-123',
      name: 'Regular Admin',
      email: 'admin@example.com',
      phone: '9999999999',
      role: AdminRole.admin,
      isActive: true,
    );

    const anotherAdmin = AdminUser(
      id: 'adm-456',
      name: 'Another Admin',
      email: 'another@example.com',
      phone: '8888888888',
      role: AdminRole.admin,
      isActive: true,
    );

    test('Regular Admin starts scoped to their own account', () {
      final container = ProviderContainer(
        overrides: [
          currentAdminUserProvider.overrideWithValue(regularAdmin),
          isSuperAdminProvider.overrideWithValue(false),
          allAdminsStreamProvider.overrideWith(
            (ref) => Stream.value([regularAdmin, anotherAdmin]),
          ),
        ],
      );

      final activeScope = container.read(activeAdminScopeProvider);
      expect(activeScope, isNotNull);
      expect(activeScope?.id, equals('adm-123'));
      expect(container.read(isInspectingAdminWorkspaceProvider), isFalse);
    });

    test(
        'Super Admin starts with null scope and can explicitly inspect an admin',
        () async {
      final container = ProviderContainer(
        overrides: [
          currentAdminUserProvider.overrideWithValue(SuperAdminConfig.user),
          isSuperAdminProvider.overrideWithValue(true),
          allAdminsStreamProvider.overrideWith(
            (ref) => Stream.value([regularAdmin, anotherAdmin]),
          ),
        ],
      );

      // Listen to keep provider alive and await stream emission
      container.listen(activeAdminScopeProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      // SA starts with NO workspace selected
      expect(container.read(activeAdminScopeProvider), isNull);
      expect(container.read(isInspectingAdminWorkspaceProvider), isFalse);

      // SA explicitly opens a workspace
      container
          .read(activeAdminScopeProvider.notifier)
          .inspectAdmin(regularAdmin);
      expect(container.read(activeAdminScopeProvider)?.id, equals('adm-123'));
      expect(container.read(isInspectingAdminWorkspaceProvider), isTrue);

      // SA can switch to another admin workspace
      container
          .read(activeAdminScopeProvider.notifier)
          .inspectAdmin(anotherAdmin);
      expect(container.read(activeAdminScopeProvider)?.id, equals('adm-456'));
      expect(container.read(isInspectingAdminWorkspaceProvider), isTrue);

      // SA exits back to Admins Directory view (null scope)
      container.read(activeAdminScopeProvider.notifier).exitInspection();
      expect(container.read(activeAdminScopeProvider), isNull);
      expect(container.read(isInspectingAdminWorkspaceProvider), isFalse);

      // clearScope() is an alias for exitInspection()
      container
          .read(activeAdminScopeProvider.notifier)
          .inspectAdmin(regularAdmin);
      container.read(activeAdminScopeProvider.notifier).clearScope();
      expect(container.read(activeAdminScopeProvider), isNull);
    });

    test('Super Admin with empty admin list starts with null scope', () async {
      final container = ProviderContainer(
        overrides: [
          currentAdminUserProvider.overrideWithValue(SuperAdminConfig.user),
          isSuperAdminProvider.overrideWithValue(true),
          allAdminsStreamProvider.overrideWith(
            (ref) => Stream.value([]),
          ),
        ],
      );

      container.listen(activeAdminScopeProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(container.read(activeAdminScopeProvider), isNull);
      expect(container.read(isInspectingAdminWorkspaceProvider), isFalse);
    });
  });
}



