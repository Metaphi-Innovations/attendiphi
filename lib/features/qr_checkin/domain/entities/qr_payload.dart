/// Strongly typed representation of a scanned QR payload.
class QrPayload {
  const QrPayload({
    required this.locationId,
    this.sessionDateStr,
    this.adminId,
    this.timestamp,
    this.rawPayload,
  });

  /// The unique identifier of the check-in location.
  final String locationId;

  /// Optional specific session date (e.g. "2026-09-03") encoded in the QR.
  final String? sessionDateStr;

  /// Optional Admin identifier whose workspace this QR belongs to.
  final String? adminId;

  /// Optional generation timestamp if encoded in the QR.
  final DateTime? timestamp;

  /// The raw payload string as read by the scanner.
  final String? rawPayload;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QrPayload &&
          runtimeType == other.runtimeType &&
          locationId == other.locationId &&
          sessionDateStr == other.sessionDateStr &&
          adminId == other.adminId;

  @override
  int get hashCode => Object.hash(locationId, sessionDateStr, adminId);

  @override
  String toString() =>
      'QrPayload(locationId: $locationId, sessionDateStr: $sessionDateStr, adminId: $adminId)';
}
