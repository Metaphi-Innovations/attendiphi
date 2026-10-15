import '../../domain/entities/employee.dart';

/// Maps Supabase `members` rows (snake_case) ↔ [Employee].
class SupabaseEmployeeMapper {
  SupabaseEmployeeMapper._();

  /// Lean projection for roster streams (no face embedding blobs).
  static const listSelect =
      'id,name,email,phone,role,designation,is_active,admin_id,photo_url,'
      'face_enrolled,face_registered,face_model,face_model_version,'
      'created_at,updated_at';

  static Employee fromRow(Map<String, dynamic> row) {
    return Employee.fromMap({
      'id': row['id'],
      'name': row['name'],
      'email': row['email'],
      'phone': row['phone'],
      'role': row['role'],
      'designation': row['designation'],
      'isActive': row['is_active'],
      'adminId': row['admin_id'],
      'photoUrl': row['photo_url'],
      'faceEnrolled': row['face_enrolled'],
      'faceRegistered': row['face_registered'],
      'faceModel': row['face_model'],
      'faceModelVersion': row['face_model_version'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    }, docId: row['id']?.toString());
  }

  static Map<String, dynamic> toInsert({
    required String id,
    required String name,
    String email = '',
    String phone = '',
    String role = 'Member',
    String designation = '',
    bool isActive = true,
    String? adminId,
    String? photoUrl,
    bool faceEnrolled = false,
    String? faceModel,
    String? faceModelVersion,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': id,
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role.trim().isEmpty ? 'Member' : role.trim(),
      'designation': designation.trim(),
      'is_active': isActive,
      'admin_id': adminId,
      'photo_url': photoUrl,
      'face_enrolled': faceEnrolled,
      'face_registered': faceEnrolled,
      'face_model': faceModel,
      'face_model_version': faceModelVersion,
      'created_at': now,
      'updated_at': now,
    };
  }

  static Map<String, dynamic> toUpdate({
    required String name,
    String email = '',
    String phone = '',
    String role = 'Member',
    String designation = '',
    bool isActive = true,
    String? adminId,
    String? photoUrl,
    bool? faceEnrolled,
    String? faceModel,
    String? faceModelVersion,
  }) {
    return {
      'name': name.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'role': role.trim().isEmpty ? 'Member' : role.trim(),
      'designation': designation.trim(),
      'is_active': isActive,
      'admin_id': ?adminId,
      'photo_url': ?photoUrl,
      if (faceEnrolled != null) ...{
        'face_enrolled': faceEnrolled,
        'face_registered': faceEnrolled,
      },
      'face_model': ?faceModel,
      'face_model_version': ?faceModelVersion,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }
}
