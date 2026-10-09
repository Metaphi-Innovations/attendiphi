import 'package:cloud_firestore/cloud_firestore.dart';

import '../admin_password_hasher.dart';

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
    this.passwordSalt = '',
    this.plainPassword = '',
    this.mustResetPassword = false,
    this.isActive = true,
    this.createdAt,
    this.createdBy,
    this.lastLoginAt,
    this.passwordUpdatedAt,
    this.assignedLocationIds = const [],
    this.uid = '',
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final AdminRole role;
  final String passwordHash;
  final String passwordSalt;
  final String plainPassword;
  final bool mustResetPassword;
  final bool isActive;
  final DateTime? createdAt;
  final String? createdBy;
  final DateTime? lastLoginAt;
  final DateTime? passwordUpdatedAt;
  final List<String> assignedLocationIds;

  /// Firebase Auth UID. Same as [id] when the admin doc is keyed by UID.
  final String uid;

  bool get isSuperAdmin => role.isSuperAdmin;

  /// Verifies [candidate] against salted [passwordHash] only.
  ///
  /// Login uses Firebase Auth. This helper remains for password-reset /
  /// metadata sync checks. Legacy plaintext and hash-as-password equality
  /// are intentionally unsupported.
  bool matchesPassword(String candidate) {
    final password = candidate.trim();
    if (password.isEmpty) return false;
    if (passwordSalt.isEmpty || passwordHash.isEmpty) return false;
    return AdminPasswordHasher.hash(password, passwordSalt) == passwordHash;
  }

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
      passwordSalt: data['passwordSalt'] as String? ?? '',
      plainPassword: data['plainPassword'] as String? ?? '',
      mustResetPassword: data['mustResetPassword'] as bool? ?? false,
      isActive: data['isActive'] as bool? ?? true,
      createdAt: parseDate(data['createdAt']),
      createdBy: data['createdBy'] as String?,
      lastLoginAt: parseDate(data['lastLoginAt']),
      passwordUpdatedAt: parseDate(data['passwordUpdatedAt']),
      assignedLocationIds: List<String>.from(data['assignedLocationIds'] ?? []),
      uid: (data['uid'] as String? ?? id).trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email.trim().toLowerCase(),
      'phone': phone,
      'role': role.value,
      'passwordHash': passwordHash,
      'passwordSalt': passwordSalt,
      'mustResetPassword': mustResetPassword,
      'isActive': isActive,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'lastLoginAt': lastLoginAt != null ? Timestamp.fromDate(lastLoginAt!) : null,
      'assignedLocationIds': assignedLocationIds,
      'uid': (uid.isNotEmpty ? uid : id),
    };
  }

  AdminUser copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    AdminRole? role,
    String? passwordHash,
    String? passwordSalt,
    String? plainPassword,
    bool? mustResetPassword,
    bool? isActive,
    DateTime? createdAt,
    String? createdBy,
    DateTime? lastLoginAt,
    DateTime? passwordUpdatedAt,
    List<String>? assignedLocationIds,
    String? uid,
  }) {
    return AdminUser(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      plainPassword: plainPassword ?? this.plainPassword,
      mustResetPassword: mustResetPassword ?? this.mustResetPassword,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      passwordUpdatedAt: passwordUpdatedAt ?? this.passwordUpdatedAt,
      assignedLocationIds: assignedLocationIds ?? this.assignedLocationIds,
      uid: uid ?? this.uid,
    );
  }
}
