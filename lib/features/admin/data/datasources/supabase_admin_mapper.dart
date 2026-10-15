import '../../domain/entities/admin_user.dart';

/// Maps Supabase `admins` rows (snake_case) ↔ [AdminUser].
class SupabaseAdminMapper {
  SupabaseAdminMapper._();

  /// Safe projection — never requests password_hash / password_salt.
  static const listSelect =
      'id,uid,auth_user_id,name,email,phone,role,must_reset_password,'
      'is_active,created_at,created_by,last_login_at,password_updated_at,'
      'assigned_location_ids,updated_at';

  static AdminUser fromRow(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    // Prefer auth_user_id (Supabase Auth UUID). Legacy `uid` may still be a
    // Firebase-style id and must not be used for Auth Admin API calls.
    final authUserId = (row['auth_user_id']?.toString() ?? '').trim();
    final legacyUid = (row['uid']?.toString() ?? '').trim();
    return AdminUser.fromMap({
      'name': row['name'],
      'email': row['email'],
      'phone': row['phone'],
      'role': row['role'],
      'passwordHash': row['password_hash'] ?? '',
      'passwordSalt': row['password_salt'] ?? '',
      'mustResetPassword': row['must_reset_password'] == true,
      'isActive': row['is_active'] != false,
      'createdAt': row['created_at'],
      'createdBy': row['created_by'],
      'lastLoginAt': row['last_login_at'],
      'passwordUpdatedAt': row['password_updated_at'],
      'assignedLocationIds': row['assigned_location_ids'] ?? const [],
      'uid': authUserId.isNotEmpty
          ? authUserId
          : (legacyUid.isNotEmpty ? legacyUid : id),
    }, id: id);
  }

  static Map<String, dynamic> toUpdate(AdminUser admin) {
    return {
      'name': admin.name.trim(),
      'email': admin.email.trim().toLowerCase(),
      'phone': admin.phone.trim(),
      'role': admin.role.value,
      'must_reset_password': admin.mustResetPassword,
      'is_active': admin.isActive,
      'created_by': admin.createdBy,
      'assigned_location_ids': admin.assignedLocationIds,
      'uid': admin.uid.isNotEmpty ? admin.uid : admin.id,
      'last_login_at': admin.lastLoginAt?.toUtc().toIso8601String(),
      'password_updated_at': admin.passwordUpdatedAt?.toUtc().toIso8601String(),
      // password_hash/salt only via complete_own_password_reset RPC.
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((_, v) => v == null);
  }

  static Map<String, dynamic> toInsert(AdminUser admin) {
    return {
      'id': admin.id,
      'uid': admin.uid.isNotEmpty ? admin.uid : admin.id,
      'name': admin.name.trim(),
      'email': admin.email.trim().toLowerCase(),
      'phone': admin.phone.trim(),
      'role': admin.role.value,
      'must_reset_password': admin.mustResetPassword,
      'is_active': admin.isActive,
      'created_by': admin.createdBy,
      'assigned_location_ids': admin.assignedLocationIds,
      'created_at': (admin.createdAt ?? DateTime.now())
          .toUtc()
          .toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
