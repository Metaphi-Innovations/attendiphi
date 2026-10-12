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

/// Soft-wraps substitute attendee name from a dashboard (mapped) row.
String? substitutePresentName(CheckInSubmission record) {
  if (!record.type.isSubstitute) return null;
  final fromSub = record.substituteName?.trim() ?? '';
  if (fromSub.isNotEmpty) return firstAndLastName(fromSub);
  return null;
}

/// Soft-wraps absent member name from a dashboard row.
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
/// First Last
/// ...
///
/// Absent
/// First Last
/// ...
/// ```
String buildSubstituteAbsentAttendanceTxt({
  required List<CheckInSubmission> records,
}) {
  final substitutes = records
      .map(substitutePresentName)
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final absents = records
      .map(absentMemberName)
      .whereType<String>()
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  final buffer = StringBuffer()
    ..writeln('Substitute');
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
