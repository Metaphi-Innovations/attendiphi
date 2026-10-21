import '../../features/checkin/domain/entities/check_in_submission.dart';
import '../../features/employee/domain/entities/employee.dart';

/// Cheap id-keyed equality for admin roster / Daily Attendance rebuilds.
///
/// Compares fields the UI depends on — not face embedding vectors.
bool employeesSnapshotUnchanged(List<Employee> previous, List<Employee> next) {
  if (identical(previous, next)) return true;
  if (previous.length != next.length) return false;

  final byId = <String, Employee>{
    for (final e in next) e.id: e,
  };
  if (byId.length != next.length) return false;

  for (final a in previous) {
    final b = byId[a.id];
    if (b == null) return false;
    if (a.name != b.name ||
        a.phone != b.phone ||
        a.email != b.email ||
        a.role != b.role ||
        a.designation != b.designation ||
        a.isActive != b.isActive ||
        a.photoUrl != b.photoUrl ||
        a.faceEnrolled != b.faceEnrolled ||
        a.faceModel != b.faceModel ||
        a.faceModelVersion != b.faceModelVersion ||
        a.updatedAt?.millisecondsSinceEpoch !=
            b.updatedAt?.millisecondsSinceEpoch) {
      return false;
    }
  }
  return true;
}

/// Face-candidate lists: include template counts so enrollment changes emit.
bool faceCandidatesSnapshotUnchanged(
  List<Employee> previous,
  List<Employee> next,
) {
  if (identical(previous, next)) return true;
  if (previous.length != next.length) return false;

  final byId = <String, Employee>{
    for (final e in next) e.id: e,
  };
  if (byId.length != next.length) return false;

  for (final a in previous) {
    final b = byId[a.id];
    if (b == null) return false;
    if (a.name != b.name ||
        a.isActive != b.isActive ||
        a.faceEnrolled != b.faceEnrolled ||
        a.faceModel != b.faceModel ||
        a.sfaceTemplates.length != b.sfaceTemplates.length ||
        a.updatedAt?.millisecondsSinceEpoch !=
            b.updatedAt?.millisecondsSinceEpoch) {
      return false;
    }
  }
  return true;
}

/// Cheap id-keyed equality for live check-in dashboards.
bool checkInsSnapshotUnchanged(
  List<CheckInSubmission> previous,
  List<CheckInSubmission> next,
) {
  if (identical(previous, next)) return true;
  if (previous.length != next.length) return false;

  final byId = <String, CheckInSubmission>{
    for (final c in next) c.id: c,
  };
  if (byId.length != next.length) return false;

  for (final a in previous) {
    final b = byId[a.id];
    if (b == null) return false;
    if (a.memberId != b.memberId ||
        a.userName != b.userName ||
        a.userPhone != b.userPhone ||
        a.type != b.type ||
        a.locationId != b.locationId ||
        a.timestamp.millisecondsSinceEpoch !=
            b.timestamp.millisecondsSinceEpoch ||
        a.isVerified != b.isVerified ||
        a.isFlagged != b.isFlagged ||
        a.flagReason != b.flagReason ||
        a.hasPhoto != b.hasPhoto ||
        a.photoPath != b.photoPath ||
        a.gpsAccuracy != b.gpsAccuracy ||
        a.distanceMeters != b.distanceMeters ||
        a.substituteForMember != b.substituteForMember ||
        a.substituteName != b.substituteName ||
        a.substitutePhone != b.substitutePhone ||
        a.isEdited != b.isEdited ||
        a.editedAt?.millisecondsSinceEpoch !=
            b.editedAt?.millisecondsSinceEpoch ||
        a.faceVerified != b.faceVerified ||
        a.verificationMethod != b.verificationMethod) {
      return false;
    }
  }
  return true;
}

bool stringSetSnapshotUnchanged(Set<String> previous, Set<String> next) {
  if (identical(previous, next)) return true;
  if (previous.length != next.length) return false;
  return previous.containsAll(next);
}
