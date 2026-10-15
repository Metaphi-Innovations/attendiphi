import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_management_provider.dart';

void main() {
  test('Super Admin profiles are hidden from Admin Management list', () async {
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

    final container = ProviderContainer(
      overrides: [
        isSuperAdminProvider.overrideWithValue(true),
        currentAdminUserProvider.overrideWithValue(superAdmin),
        allAdminsStreamProvider.overrideWith(
          (ref) => Stream.value([superAdmin, regularAdmin]),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Keep stream provider alive until first emission.
    container.listen(allAdminsStreamProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final visible = container
        .read(visibleAdminsProvider)
        .maybeWhen(data: (admins) => admins, orElse: () => <AdminUser>[]);
    expect(visible.map((a) => a.id), ['uid-admin']);
    expect(visible.any((a) => a.isSuperAdmin), isFalse);
  });
}
