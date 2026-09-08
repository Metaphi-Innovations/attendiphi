import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/entities/admin_user.dart';

void main() {
  group('AdminUser Entity Tests', () {
    test('AdminRole parsing works correctly', () {
      expect(AdminRole.fromString('superadmin'), AdminRole.superAdmin);
      expect(AdminRole.fromString('super_admin'), AdminRole.superAdmin);
      expect(AdminRole.fromString('SUPER ADMIN'), AdminRole.superAdmin);
      expect(AdminRole.fromString('admin'), AdminRole.admin);
      expect(AdminRole.fromString(null), AdminRole.admin);
    });

    test('AdminUser fromMap and toMap serialize accurately', () {
      final now = DateTime(2026, 9, 5, 12, 0);
      final admin = AdminUser(
        id: 'admin_123',
        name: 'Test Admin',
        email: 'test@admin.com',
        phone: '9876543210',
        role: AdminRole.admin,
        passwordHash: 'Pass@123',
        plainPassword: 'Pass@123',
        isActive: true,
        createdAt: now,
        createdBy: 'Super Admin',
      );

      final map = admin.toMap();
      expect(map['name'], 'Test Admin');
      expect(map['email'], 'test@admin.com');
      expect(map['phone'], '9876543210');
      expect(map['role'], 'admin');
      expect(map['plainPassword'], 'Pass@123');
      expect(map['isActive'], true);

      final deserialized = AdminUser.fromMap(map, id: 'admin_123');
      expect(deserialized.id, 'admin_123');
      expect(deserialized.name, 'Test Admin');
      expect(deserialized.email, 'test@admin.com');
      expect(deserialized.role, AdminRole.admin);
      expect(deserialized.isActive, true);
    });
  });
}
