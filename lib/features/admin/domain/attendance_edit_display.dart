import '../../../core/extensions/date_extensions.dart';
import '../../checkin/domain/entities/check_in_submission.dart';

/// Clock time shown on Daily Attendance tiles.
///
/// Prefer [CheckInSubmission.editedAt] when the row was edited; otherwise the
/// original check-in [CheckInSubmission.timestamp]. Never invents a time.
DateTime attendanceDisplayClock(CheckInSubmission record) {
  if (record.isEdited) {
    final edited = record.editedAt;
    if (edited != null) return edited;
  }
  return record.timestamp;
}

/// Date used next to the tile clock (same source as [attendanceDisplayClock]).
DateTime attendanceDisplayDate(CheckInSubmission record) =>
    attendanceDisplayClock(record);

/// Detail-panel Timestamp value for Daily Attendance.
///
/// Edited rows show original check-in and edit time; legacy edited rows without
/// [CheckInSubmission.editedAt] keep the original time + Edited label.
String attendanceDetailTimestampLabel(CheckInSubmission record) {
  if (record.type.isNotCheckedIn) return '-';

  final checkedIn = record.timestamp.formattedDateTime;
  if (!record.isEdited) return checkedIn;

  final edited = record.editedAt;
  if (edited == null) {
    return '$checkedIn (Edited by Admin)';
  }
  return 'Checked in: $checkedIn\n'
      'Edited: ${edited.formattedDateTime} (by Admin)';
}
