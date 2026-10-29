import '../../checkin/domain/entities/check_in_submission.dart';
import '../../checkin/domain/entities/check_in_type.dart';
import '../../employee/domain/employee_lookup.dart';
import '../../employee/domain/entities/employee.dart';

/// Default venue used when materializing a Not Checked In placeholder.
const String kDefaultAdminLocationId = 'location_x';
const String kDefaultAdminLocationName = 'Jade Luxury Banquets, Mumbai';

/// True when [name] is empty or matches [memberName] (same person label).
bool isSamePersonName(String? name, String memberName) {
  final left = name?.trim() ?? '';
  final right = memberName.trim();
  if (left.isEmpty || right.isEmpty) return left.isEmpty;
  return EmployeeLookup.normalizeName(left) ==
      EmployeeLookup.normalizeName(right);
}

/// Substitute display name that is distinct from the covered member.
///
/// Returns null when missing or incorrectly collapsed to the member name
/// (so UI shows "—" instead of duplicating Member Name). Phone is resolved
/// separately and is never dropped for that reason.
String? distinctSubstituteAttendeeName({
  required String? substituteName,
  required String memberName,
  String? fallbackAttendeeName,
}) {
  final primary = substituteName?.trim() ?? '';
  if (primary.isNotEmpty && !isSamePersonName(primary, memberName)) {
    return primary;
  }
  final fallback = fallbackAttendeeName?.trim() ?? '';
  if (fallback.isNotEmpty && !isSamePersonName(fallback, memberName)) {
    return fallback;
  }
  return null;
}

/// Resolves substitute attendee name + phone from check-in text-field data.
///
/// Source of truth (QR / form):
/// - name → [CheckInSubmission.substituteName], else original [userName]
///   when that value is not the covered member
/// - phone → dedicated [CheckInSubmission.substitutePhone] only (never
///   [userPhone], roster, or covered-member phone — those often equal the
///   member after dashboard remap)
/// - [displayLabel] → name if present; never phone (analytics uses
///   "Unknown substitute" when name is missing)
///
/// [raw] is the unmapped Firestore document when available (preferred over a
/// remapped dashboard row that already replaced userName with the member).
({String? name, String phone, String? displayLabel})
resolveSubstituteAttendeeFields({
  required CheckInSubmission displayed,
  CheckInSubmission? raw,
  String? coveredMemberName,
  String? coveredMemberPhone,
}) {
  final memberName = (coveredMemberName ?? displayed.userName).trim();
  // Prefer raw Firestore doc; also try displayed substituteName when raw was
  // already remapped in-memory without a separate raw copy.
  final primary = raw ?? displayed;
  final secondary = identical(primary, displayed) ? null : displayed;

  final name =
      distinctSubstituteAttendeeName(
        substituteName: primary.substituteName,
        memberName: memberName,
        fallbackAttendeeName: primary.userName,
      ) ??
      (secondary == null
          ? null
          : distinctSubstituteAttendeeName(
              substituteName: secondary.substituteName,
              memberName: memberName,
              fallbackAttendeeName: secondary.userName,
            ));

  final phone = _resolveSubstitutePhone(
    primary: primary,
    secondary: secondary,
    displayed: displayed,
  );

  // Never use phone as the display name — analytics shows "Unknown substitute".
  final displayLabel =
      (name != null && name.isNotEmpty) ? name : null;

  return (name: name, phone: phone, displayLabel: displayLabel);
}

/// Dedicated [CheckInSubmission.substitutePhone] only — never [userPhone]
/// or member roster (coveredMemberPhone is intentionally unused).
String _resolveSubstitutePhone({
  required CheckInSubmission primary,
  CheckInSubmission? secondary,
  required CheckInSubmission displayed,
}) {
  String? pick(CheckInSubmission source) {
    final dedicated = source.substitutePhone?.trim() ?? '';
    if (dedicated.isNotEmpty) return dedicated;
    return null;
  }

  return pick(primary) ??
      (secondary != null ? pick(secondary) : null) ??
      pick(displayed) ??
      '';
}

/// Maps a raw substitute Firestore check-in onto a Daily Attendance member row.
///
/// Dashboard convention for substitute rows:
/// - [CheckInSubmission.userName] / [CheckInSubmission.memberId] → member covered
/// - [CheckInSubmission.substituteName] → person who attended
/// - [CheckInSubmission.photoBase64] → substitute selfie
/// - [CheckInSubmission.userPhone] → attending substitute phone
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

  // Never surface the covered member name as the substitute attendee label.
  final attendingName = distinctSubstituteAttendeeName(
    substituteName: persistedSub,
    memberName: memberName,
    fallbackAttendeeName: rawUser,
  );

  // Always keep the check-in phone (substitutePhone / userPhone). Do not drop
  // it when it happens to match the member roster number.
  final dedicatedPhone = raw.substitutePhone?.trim() ?? '';
  final rawPhone = raw.userPhone.trim();
  final attendingPhone = dedicatedPhone.isNotEmpty ? dedicatedPhone : rawPhone;

  return raw.copyWith(
    userName: memberName,
    // Attending substitute phone (form text field), never member roster.
    userPhone: attendingPhone.isNotEmpty ? attendingPhone : raw.userPhone,
    userEmail: raw.userEmail ?? member.email,
    substituteName: attendingName,
    // copyWith cannot null-out via `substituteName: null` alone.
    clearSubstituteName: attendingName == null,
    substitutePhone: attendingPhone.isNotEmpty ? attendingPhone : null,
    clearSubstitutePhone: attendingPhone.isEmpty,
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

  final memberId = (raw.memberId ?? '').trim();
  if (memberId.isNotEmpty) {
    // Exclusive: never phone/name fan-out when member_id is set.
    return EmployeeLookup.byId([member], memberId) != null;
  }

  if (EmployeeLookup.forNamedMember([member], raw.substituteForMember) !=
      null) {
    return true;
  }

  // Admin-converted / legacy rows: type flipped to substitute without
  // memberId or substituteForMember. Still attach via name or phone so the
  // member does not fall through to "Not Checked In".
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

/// Wall-clock time to persist when an admin materializes a Not Checked In row.
///
/// Placeholders use session-day midnight only for list sorting / display as
/// "—". Once Verify or Edit writes a real check-in, use [stamped] so Daily
/// Attendance never shows 12:00 AM. Real QR rows keep [original.timestamp].
DateTime adminPersistedTimestamp({
  required CheckInSubmission original,
  required DateTime stamped,
}) {
  if (isAdminPlaceholderCheckIn(original)) return stamped;
  return original.timestamp;
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
  final persistedTimestamp = adminPersistedTimestamp(
    original: original,
    stamped: stamped,
  );

  late CheckInSubmission edited;
  if (effectiveType.isSubstitute) {
    // Explicit form input wins. If empty, recover a distinct name from the
    // existing record — never fall back to covered member name.
    final resolvedSubName = attendingName.isNotEmpty
        ? attendingName
        : distinctSubstituteAttendeeName(
            substituteName: original.substituteName,
            memberName: coveredName,
          );
    final resolvedPhone = phone.isNotEmpty
        ? phone
        : (original.substitutePhone ?? original.userPhone);
    edited = original.copyWith(
      // Dashboard remap convention: userName = covered member.
      userName: coveredName,
      userPhone: resolvedPhone,
      locationName: _resolvedVenueName(
        venueField: venue,
        original: original,
        fallbackLocationName: fallbackLocationName,
      ),
      type: CheckInType.substitute,
      substituteForMember: coveredName,
      substituteName: resolvedSubName,
      clearSubstituteName: resolvedSubName == null,
      substitutePhone: resolvedPhone.isNotEmpty ? resolvedPhone : null,
      clearSubstitutePhone: resolvedPhone.isEmpty,
      memberId: (coveredId != null && coveredId.isNotEmpty) ? coveredId : null,
      isVerified: keepVerified,
      clearVerificationMeta: !keepVerified,
      verifiedAt: keepVerified ? (original.verifiedAt ?? stamped) : null,
      verifiedBy: keepVerified ? (original.verifiedBy ?? 'Admin') : null,
      isEdited: true,
      editedAt: stamped,
      timestamp: persistedTimestamp,
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
      timestamp: persistedTimestamp,
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
  final needsNewId =
      isAdminPlaceholderCheckIn(submission) ||
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
