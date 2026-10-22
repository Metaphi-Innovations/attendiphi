import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_auth_provider.dart';

/// Avoids [AdminAuthNotifier]'s Supabase bootstrap in widget tests.
class MockLoggedOutAdminAuthNotifier extends AdminAuthNotifier {
  @override
  AdminAuthState build() => const AdminAuthState(sessionResolved: true);
}

/// Authenticated admin session for admin dashboard widget tests.
class MockAuthenticatedAdminAuthNotifier extends AdminAuthNotifier {
  MockAuthenticatedAdminAuthNotifier(this.admin);

  final AdminUser admin;

  @override
  AdminAuthState build() {
    return AdminAuthState(
      isAuthenticated: true,
      sessionResolved: true,
      currentAdmin: admin,
      authUid: admin.uid.isNotEmpty ? admin.uid : admin.id,
    );
  }
}

const kWidgetTestSuperAdmin = AdminUser(
  id: 'adm-super-test',
  name: 'Super Admin',
  email: 'super@test.example',
  phone: '9000000000',
  role: AdminRole.superAdmin,
  isActive: true,
);

const kWidgetTestRegularAdmin = AdminUser(
  id: 'adm-regular-test',
  name: 'Regular Admin',
  email: 'admin@test.example',
  phone: '9000000001',
  role: AdminRole.admin,
  isActive: true,
);
