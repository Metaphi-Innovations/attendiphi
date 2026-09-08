import 'package:cloud_firestore/cloud_firestore.dart';

/// Role identifier for administrator accounts.
enum AdminRole {
  superAdmin('superadmin', 'Super Admin'),
  admin('admin', 'Admin');

  const AdminRole(this.value, this.label);
  final String value;
  final String label;

  static AdminRole fromString(String? val) {
    if (val == null) return AdminRole.admin;
    final clean = val.trim().toLowerCase();
    if (clean == 'superadmin' || clean == 'super_admin' || clean == 'super admin') {
      return AdminRole.superAdmin;
    }
    return AdminRole.admin;
  }

  bool get isSuperAdmin => this == AdminRole.superAdmin;
}

/// Entity representing an administrator user account.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.role = AdminRole.admin,
    this.passwordHash = '',
    this.plainPassword = '',
    this.mustResetPassword = false,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.lastLoginAt,
    this.assignedLocationIds = const [],
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final AdminRole role;
  final String passwordHash;
  final String plainPassword;
  final bool mustResetPassword;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? lastLoginAt;
  final List<String> assignedLocationIds;

  bool get isSuperAdmin => role.isSuperAdmin;

  factory AdminUser.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return AdminUser.fromMap(data, id: doc.id);
  }

  factory AdminUser.fromMap(Map<String, dynamic> data, {required String id}) {
    DateTime? parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      return null;
    }

    return AdminUser(
      id: id,
      name: data['name'] as String? ?? 'Admin',
      email: (data['email'] as String? ?? '').trim().toLowerCase(),
      phone: data['phone'] as String? ?? '',
      role: AdminRole.fromString(data['role'] as String?),
      passwordHash: data['passwordHash'] as String? ?? '',
      plainPassword: data['plainPassword'] as String? ?? '',
      mustResetPassword: data['mustResetPassword'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      createdBy: data['createdBy'] as String?,
      lastLoginAt: parseDate(data['lastLoginAt']),
      assignedLocationIds: List<String>.from(data['assignedLocationIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email.trim().toLowerCase(),
      'phone': phone,
      'role': role.value,
      'passwordHash': passwordHash,
      'plainPassword': plainPassword,
      'mustResetPassword': mustResetPassword,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'assignedLocationIds': assignedLocationIds,
    };
  }

  AdminUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    AdminRole? role,
    String? passwordHash,
    String? plainPassword,
    bool? mustResetPassword,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
    DateTime? lastLoginAt,
    List<String>? assignedLocationIds,
  }) {
    return AdminUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      plainPassword: plainPassword ?? this.plainPassword,
      mustResetPassword: mustResetPassword ?? this.mustResetPassword,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      assignedLocationIds: assignedLocationIds ?? this.assignedLocationIds,
    );
  }
}
