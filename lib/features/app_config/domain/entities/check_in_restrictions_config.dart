/// Live configuration for production check-in restrictions.
///
/// Stored at `appConfig/checkInRestrictions`. When the document is missing,
/// clients treat [restrictionsEnabled] as `true` (safe default).
class CheckInRestrictionsConfig {
  const CheckInRestrictionsConfig({
    required this.restrictionsEnabled,
    this.updatedAt,
    this.updatedBy,
    this.updatedByEmail,
  });

  /// When true: Thursday-only, QR date must match today, one device = one check-in.
  /// When false: test mode — any day, any QR date, multi check-in per device.
  final bool restrictionsEnabled;

  final DateTime? updatedAt;
  final String? updatedBy;
  final String? updatedByEmail;

  static const CheckInRestrictionsConfig defaults = CheckInRestrictionsConfig(
    restrictionsEnabled: true,
  );

  CheckInRestrictionsConfig copyWith({
    bool? restrictionsEnabled,
    DateTime? updatedAt,
    String? updatedBy,
    String? updatedByEmail,
  }) {
    return CheckInRestrictionsConfig(
      restrictionsEnabled: restrictionsEnabled ?? this.restrictionsEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByEmail: updatedByEmail ?? this.updatedByEmail,
    );
  }
}
