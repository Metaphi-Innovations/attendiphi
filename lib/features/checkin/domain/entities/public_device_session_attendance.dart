import 'check_in_submission.dart';

/// Result of [get_public_device_session_attendance] for QR early gates.
class PublicDeviceSessionAttendance {
  const PublicDeviceSessionAttendance({
    required this.locked,
    this.submission,
    this.checkInId,
  });

  /// True when a `device_session_locks` row exists for this device + session.
  final bool locked;

  /// Prior check-in when the RPC could load it (preferred for success UI).
  final CheckInSubmission? submission;

  /// Lock's check_in_id when the row exists but full payload was unavailable.
  final String? checkInId;

  bool get alreadyCheckedIn => locked || submission != null;
}
