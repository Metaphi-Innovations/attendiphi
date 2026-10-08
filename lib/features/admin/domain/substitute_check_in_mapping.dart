import '../../checkin/domain/entities/check_in_submission.dart';
import '../../checkin/domain/entities/check_in_type.dart';
import '../../employee/domain/employee_lookup.dart';
import '../../employee/domain/entities/employee.dart';

/// Default venue used when materializing a Not Checked In placeholder.
const String kDefaultAdminLocationId = 'location_x';
const String kDefaultAdminLocationName = 'Jade Luxury Banquets, Mumbai';

/// Maps a raw substitute Firestore check-in onto a Daily Attendance member row.
///
/// Dashboard convention for substitute rows:
/// - [CheckInSubmission.userName] / [CheckInSubmission.memberId] → member covered
/// - [CheckInSubmission.substituteName] → person who attended
/// - [CheckInSubmission.photoBase64] → substitute selfie
/// - [CheckInSubmission.userPhone] → attending substitute phone (not member phone)
///
/// Important: after verify/edit write-back, Firestore may already have
/// `userName == member` and a populated `substituteName`. Remapping must
/// **prefer existing [CheckInSubmission.substituteName]** and never set
/// `substituteName` from `userName` when that would collapse both to the member.
CheckInSubmission mapSubstituteCheckInForMember({
  required CheckInSubmission raw,
  required Employee member,
}) {
  final persistedSub = raw.substituteName?.trim() ?? '';
  final rawUser = raw.userName.trim();
  final memberName = member.name.trim();

  final String attendingName;
  if (persistedSub.isNotEmpty) {
    attendingName = persistedSub;
  } else if (rawUser.isNotEmpty &&
      EmployeeLookup.normalizeName(rawUser) !=
          EmployeeLookup.normalizeName(memberName)) {
    // Fresh QR write: userName is the attending substitute.
    attendingName = rawUser;
  } else if (rawUser.isNotEmpty &&
      (raw.substituteForMember ?? '').trim().isEmpty) {
    // Admin flipped Member → Substitute without a separate substitute name.
    attendingName = rawUser;
  } else {
    // Remapped write-back without substituteName — identity lost.
    attendingName = persistedSub;
  }

  return raw.copyWith(
    userName: memberName,
    // Prefer attending substitute phone (raw QR). Do not overwrite with member.
    userPhone: raw.userPhone,
    userEmail: raw.userEmail ?? member.email,
    substituteName: attendingName.isEmpty ? null : attendingName,
    substituteForMember: memberName,
    photoBase64: raw.photoBase64,
    type: CheckInType.substitute,
    memberId: member.id,
  );
}

/// Whether [raw] is a substitute check-in covering [member].
bool substituteCheckInCoversMember({
  required CheckInSubmission raw,
  required Employee member,
}) {
  if (!raw.type.isSubstitute) return false;

  final byId = EmployeeLookup.byId([member], raw.memberId);
  if (byId != null) return true;

  if (EmployeeLookup.forNamedMember(
        [member],
        raw.substituteForMember,
      ) !=
      null) {
    return true;
  }

  // Admin-converted / legacy rows: type flipped to substitute without
  // substituteForMember. Still attach via name or phone so the member does
  // not fall through to "Not Checked In".
  if ((raw.substituteForMember ?? '').trim().isEmpty) {
    if (EmployeeLookup.phonesMatch(raw.userPhone, member.phone)) return true;
    if (EmployeeLookup.normalizeName(raw.userName) ==
        EmployeeLookup.normalizeName(member.name)) {
      return true;
    }
  }

  return false;
}

/// True when the dashboard row is a synthetic placeholder (no Firestore doc).
bool isAdminPlaceholderCheckIn(CheckInSubmission submission) {
  return submission.type.isNotCheckedIn ||
      CheckInSubmission.isPlaceholderId(submission.id);
}

/// Builds the Firestore payload when an admin edits a Daily Attendance row.
///
/// Supports Member ↔ Substitute ↔ Absent and Not Checked In → any.
/// Member → Substitute must always set [substituteForMember], [memberId], and
/// [substituteName] so [baseDashboardRecordsProvider] can still match the row.
///
/// Placeholder / empty-[locationId] rows are materialized with [newCheckInId]
/// and [fallbackLocationId] so Firestore create rules succeed.
CheckInSubmission prepareAdminEditedCheckIn({
  required CheckInSubmission original,
  required CheckInType selectedType,
  required String nameField,
  required String phoneField,
  required String venueField,
  required String coveredMemberName,
  String? coveredMemberId,
  bool isVerified = false,
  DateTime? now,
  String? newCheckInId,
  String? fallbackLocationId,
  String? fallbackLocationName,
}) {
  final stamped = now ?? DateTime.now();
  final attendingName = nameField.trim();
  final phone = phoneField.trim();
  final venue = venueField.trim();
  final coveredName = coveredMemberName.trim().isNotEmpty
      ? coveredMemberName.trim()
      : original.userName.trim();
  final coveredId = (coveredMemberId ?? original.memberId)?.trim();
  final isMarkedAbsent = selectedType == CheckInType.absent;
  // Never persist the synthetic Not Checked In type.
  final effectiveType = selectedType.isNotCheckedIn
      ? CheckInType.member
      : selectedType;
  final keepVerified = isVerified && !isMarkedAbsent;

  late CheckInSubmission edited;
  if (effectiveType.isSubstitute) {
    final substituteName =
        attendingName.isNotEmpty ? attendingName : coveredName;
    edited = original.copyWith(
      // Dashboard remap convention: userName = covered member.
      userName: coveredName,
      userPhone: phone.isNotEmpty ? phone : original.userPhone,
      locationName: _resolvedVenueName(
        venueField: venue,
        original: original,
        fallbackLocationName: fallbackLocationName,
      ),
      type: CheckInType.substitute,
      substituteForMember: coveredName,
      substituteName: substituteName,
      memberId: (coveredId != null && coveredId.isNotEmpty) ? coveredId : null,
      isVerified: keepVerified,
      clearVerificationMeta: !keepVerified,
      verifiedAt: keepVerified ? (original.verifiedAt ?? stamped) : null,
      verifiedBy: keepVerified ? (original.verifiedBy ?? 'Admin') : null,
      isEdited: true,
      editedAt: stamped,
      timestamp: original.timestamp,
    );
  } else {
    // Absent always keeps the covered member identity (not the substitute name
    // left in the dialog when flipping Substitute → Absent).
    final resolvedName = isMarkedAbsent
        ? (coveredName.isNotEmpty ? coveredName : original.userName)
        : (attendingName.isNotEmpty ? attendingName : original.userName);
    edited = original.copyWith(
      userName: resolvedName,
      userPhone: phone.isNotEmpty ? phone : original.userPhone,
      locationName: _resolvedVenueName(
        venueField: venue,
        original: original,
        fallbackLocationName: fallbackLocationName,
      ),
      type: effectiveType,
      clearSubstituteFields: true,
      memberId: (coveredId != null && coveredId.isNotEmpty)
          ? coveredId
          : original.memberId,
      isVerified: keepVerified,
      clearVerificationMeta: !keepVerified,
      verifiedAt: keepVerified ? (original.verifiedAt ?? stamped) : null,
      verifiedBy: keepVerified ? (original.verifiedBy ?? 'Admin') : null,
      isEdited: true,
      editedAt: stamped,
      timestamp: original.timestamp,
    );
  }

  return materializeAdminCheckInForWrite(
    edited,
    newCheckInId: newCheckInId,
    fallbackLocationId: fallbackLocationId,
    fallbackLocationName: fallbackLocationName,
  );
}

/// Ensures a dashboard row can be written to Firestore (real id + locationId).
CheckInSubmission materializeAdminCheckInForWrite(
  CheckInSubmission submission, {
  String? newCheckInId,
  String? fallbackLocationId,
  String? fallbackLocationName,
}) {
  final needsNewId = isAdminPlaceholderCheckIn(submission) ||
      CheckInSubmission.isPlaceholderId(submission.id);
  final locationId = submission.locationId.trim().isNotEmpty
      ? submission.locationId.trim()
      : (fallbackLocationId?.trim().isNotEmpty == true
          ? fallbackLocationId!.trim()
          : kDefaultAdminLocationId);
  final locationName = _resolvedVenueName(
    venueField: submission.locationName,
    original: submission,
    fallbackLocationName: fallbackLocationName,
  );
  final type = submission.type.isNotCheckedIn
      ? CheckInType.member
      : submission.type;

  return submission.copyWith(
    id: needsNewId
        ? (newCheckInId?.trim().isNotEmpty == true
            ? newCheckInId!.trim()
            : 'admin_${DateTime.now().microsecondsSinceEpoch}')
        : submission.id,
    locationId: locationId,
    locationName: locationName,
    type: type,
    userPhone: submission.userPhone.trim().isNotEmpty
        ? submission.userPhone
        : '0000000000',
  );
}

String _resolvedVenueName({
  required String venueField,
  required CheckInSubmission original,
  String? fallbackLocationName,
}) {
  final venue = venueField.trim();
  if (venue.isNotEmpty && venue != '—') return venue;
  final originalName = original.locationName.trim();
  if (originalName.isNotEmpty && originalName != '—') return originalName;
  final fallback = fallbackLocationName?.trim() ?? '';
  if (fallback.isNotEmpty && fallback != '—') return fallback;
  return kDefaultAdminLocationName;
}
