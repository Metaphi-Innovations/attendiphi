import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/domain/admin_password_hasher.dart';
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
      const salt = 'unit-test-salt';
      const password = 'Pass@123';
      final hash = AdminPasswordHasher.hash(password, salt);
      final admin = AdminUser(
        id: 'admin_123',
        name: 'Test Admin',
        email: 'test@admin.com',
        phone: '9876543210',
        role: AdminRole.admin,
        passwordHash: hash,
        passwordSalt: salt,
        plainPassword: password,
        isActive: true,
        createdAt: now,
        createdBy: 'Super Admin',
      );

      final map = admin.toMap();
      expect(map['name'], 'Test Admin');
      expect(map['email'], 'test@admin.com');
      expect(map['phone'], '9876543210');
      expect(map['role'], 'admin');
      expect(map.containsKey('plainPassword'), isFalse);
      expect(map['isActive'], true);

      final deserialized = AdminUser.fromMap({
        ...map,
        'plainPassword': password,
        'passwordHash': hash,
        'passwordSalt': salt,
      }, id: 'admin_123');
      expect(deserialized.id, 'admin_123');
      expect(deserialized.name, 'Test Admin');
      expect(deserialized.email, 'test@admin.com');
      expect(deserialized.role, AdminRole.admin);
      expect(deserialized.isActive, true);
      expect(deserialized.matchesPassword(password), isTrue);
      expect(deserialized.matchesPassword('wrong'), isFalse);
    });

    test('matchesPassword rejects plaintext and hash-as-password legacy forms', () {
      const admin = AdminUser(
        id: 'adm-legacy',
        name: 'Legacy',
        email: 'legacy@example.com',
        phone: '9876543211',
        plainPassword: 'TempPass@123',
        passwordHash: 'TempPass@123',
      );
      expect(admin.matchesPassword('TempPass@123'), isFalse);
      expect(admin.matchesPassword(admin.passwordHash), isFalse);
    });
  });
}
