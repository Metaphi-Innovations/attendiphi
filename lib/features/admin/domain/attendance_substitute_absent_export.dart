import '../../checkin/domain/entities/check_in_submission.dart';

/// Keeps first + last name tokens only (single-token names stay as-is).
String firstAndLastName(String fullName) {
  final parts = fullName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '${parts.first} ${parts.last}';
}

/// Filename for the substitute/absent export: `yyyy-MM-dd.txt`.
String attendanceExportTxtFilename(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d.txt';
}

/// Covered member display name for a substitute row (never invents).
String? _coveredMemberName(CheckInSubmission record) {
  if (!record.type.isSubstitute) return null;
  final fromField = record.substituteForMember?.trim() ?? '';
  if (fromField.isNotEmpty) return firstAndLastName(fromField);
  final fromUser = record.userName.trim();
  if (fromUser.isEmpty) return null;
  final sub = record.substituteName?.trim() ?? '';
  // Mapped rows set userName to the member; skip if it equals the attendee.
  if (sub.isNotEmpty &&
      fromUser.toLowerCase() == sub.toLowerCase()) {
    return null;
  }
  return firstAndLastName(fromUser);
}

/// One Substitute export line: `Sub (for Member)` when both names exist.
String? substituteExportLine(CheckInSubmission record) {
  if (!record.type.isSubstitute) return null;
  final fromSub = record.substituteName?.trim() ?? '';
  if (fromSub.isEmpty) return null;
  final subName = firstAndLastName(fromSub);
  if (subName.isEmpty) return null;

  final memberName = _coveredMemberName(record);
  if (memberName == null || memberName.isEmpty) return subName;
  if (memberName.toLowerCase() == subName.toLowerCase()) return subName;
  return '$subName (for $memberName)';
}

/// Absent member name from a dashboard row (first + last).
String? absentMemberName(CheckInSubmission record) {
  if (!record.type.isAbsent) return null;
  final name = record.userName.trim();
  if (name.isEmpty) return null;
  return firstAndLastName(name);
}

/// Builds the `.txt` body for Daily Attendance substitute + absent export.
///
/// Format:
/// ```
/// Substitute
/// First Last (for Member Name)
/// ...
///
/// Absent
/// First Last
/// ...
/// ```
String buildSubstituteAbsentAttendanceTxt({
  required List<CheckInSubmission> records,
}) {
  final substitutes =
      records
          .map(substituteExportLine)
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final absents =
      records
          .map(absentMemberName)
          .whereType<String>()
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final buffer = StringBuffer()..writeln('Substitute');
  if (substitutes.isEmpty) {
    buffer.writeln('(none)');
  } else {
    for (final name in substitutes) {
      buffer.writeln(name);
    }
  }

  buffer
    ..writeln()
    ..writeln('Absent');
  if (absents.isEmpty) {
    buffer.writeln('(none)');
  } else {
    for (final name in absents) {
      buffer.writeln(name);
    }
  }

  return buffer.toString();
}
