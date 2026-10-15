import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/check_in_type.dart';

/// Maps Supabase `check_ins` rows (snake_case) ↔ [CheckInSubmission].
class SupabaseCheckInMapper {
  SupabaseCheckInMapper._();

  /// Lean projection for admin streams / overview matrix.
  ///
  /// Excludes `photo_base64` (often hundreds of KB per row) — that alone was
  /// making Attendance Overview REST payloads ~1MB every poll.
  /// Lean projection for admin streams / overview — never includes photo bytes.
  static const listSelect =
      'id,type,location_id,location_name,user_name,user_phone,user_email,'
      'user_latitude,user_longitude,gps_accuracy,distance_meters,member_id,'
      'substitute_for_member,substitute_name,substitute_phone,company_name,'
      'category,invited_by_member,admin_id,device_id,is_verified,verified_at,'
      'verified_by,is_edited,edited_at,is_flagged,flag_reason,face_verified,'
      'verification_method,session_date,attended_at,timestamp,created_at,'
      'updated_at,has_photo,photo_path';

  /// Explicit photo fetch only (legacy base64 + path).
  static const photoSelect = 'id,photo_path,has_photo,photo_base64';

  static CheckInType _parseType(dynamic raw) {
    final t = raw?.toString() ?? 'member';
    switch (t) {
      case 'substitute':
        return CheckInType.substitute;
      case 'visitor':
        return CheckInType.visitor;
      case 'absent':
        return CheckInType.absent;
      case 'notCheckedIn':
        return CheckInType.notCheckedIn;
      default:
        return CheckInType.member;
    }
  }

  static String _sessionDateYmd(DateTime timestamp) {
    final m = timestamp.month.toString().padLeft(2, '0');
    final d = timestamp.day.toString().padLeft(2, '0');
    return '${timestamp.year}-$m-$d';
  }

  static CheckInSubmission fromRow(Map<String, dynamic> row) {
    return CheckInSubmission.fromMap({
      'id': row['id'],
      'locationId': row['location_id'] ?? '',
      'locationName': row['location_name'] ?? '',
      'userName': row['user_name'] ?? '',
      'userPhone': row['user_phone'] ?? '',
      'type': _parseType(row['type']).name,
      'userLatitude': row['user_latitude'] ?? 0,
      'userLongitude': row['user_longitude'] ?? 0,
      'gpsAccuracy': row['gps_accuracy'] ?? 0,
      'distanceMeters': row['distance_meters'] ?? 0,
      'timestamp': row['timestamp'] ?? row['attended_at'] ?? row['created_at'],
      'userEmail': row['user_email'],
      'substituteForMember': row['substitute_for_member'],
      'substituteName': row['substitute_name'],
      'substitutePhone': row['substitute_phone'],
      'companyName': row['company_name'],
      'category': row['category'],
      'invitedByMember': row['invited_by_member'],
      'photoBase64': row['photo_base64'],
      'photoPath': row['photo_path'],
      'hasPhoto': row['has_photo'] == true,
      'adminId': row['admin_id'],
      'deviceId': row['device_id'],
      'isVerified': row['is_verified'] == true,
      'verifiedAt': row['verified_at'],
      'verifiedBy': row['verified_by'],
      'isEdited': row['is_edited'] == true,
      'editedAt': row['edited_at'],
      'createdAt': row['created_at'],
      'isFlagged': row['is_flagged'] == true,
      'flagReason': row['flag_reason'],
      'memberId': row['member_id'],
      'verificationMethod': row['verification_method'],
      'faceVerified': row['face_verified'] == true,
    });
  }

  static Map<String, dynamic> toRow(CheckInSubmission s) {
    final attended = (s.createdAt ?? s.timestamp).toUtc().toIso8601String();
    final sessionDate = _sessionDateYmd(s.timestamp);
    return {
      'id': s.id,
      'type': s.type.name,
      'location_id': s.locationId,
      'location_name': s.locationName,
      'user_name': s.userName,
      'user_phone': s.userPhone,
      'user_email': s.userEmail,
      'user_latitude': s.userLatitude,
      'user_longitude': s.userLongitude,
      'gps_accuracy': s.gpsAccuracy,
      'distance_meters': s.distanceMeters,
      'member_id': s.memberId,
      'substitute_for_member': s.substituteForMember,
      'substitute_name': s.substituteName,
      'substitute_phone': s.substitutePhone,
      'company_name': s.companyName,
      'category': s.category,
      'invited_by_member': s.invitedByMember,
      // P1: photos live in Storage; never write base64 into Postgres.
      'photo_path': s.photoPath,
      'has_photo':
          s.hasPhoto ||
          (s.photoPath?.trim().isNotEmpty ?? false) ||
          (s.photoBase64?.trim().isNotEmpty ?? false),
      'admin_id': s.adminId,
      'device_id': s.deviceId,
      'is_verified': s.isVerified,
      'verified_at': s.verifiedAt?.toUtc().toIso8601String(),
      'verified_by': s.verifiedBy,
      'is_edited': s.isEdited,
      'edited_at': s.editedAt?.toUtc().toIso8601String(),
      'is_flagged': s.isFlagged,
      'flag_reason': s.flagReason,
      'face_verified': s.faceVerified,
      'verification_method': s.verificationMethod,
      'session_date': sessionDate,
      'attended_at': attended,
      'timestamp': s.timestamp.toUtc().toIso8601String(),
      'created_at': attended,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }..removeWhere((_, v) => v == null);
  }
}
