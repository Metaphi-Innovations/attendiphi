/// Live configuration for check-in restrictions.
///
/// Stored at `appConfig/checkInRestrictions`. When the document is missing,
/// clients treat granular flags as `true` (safe default).
///
/// Staging Super Admin can toggle [locationRestrictionEnabled],
/// [dateRestrictionEnabled], and [deviceRestrictionEnabled] independently.
/// Production keeps a single master switch that sets all three together via
/// [restrictionsEnabled].
class CheckInRestrictionsConfig {
  const CheckInRestrictionsConfig({
    required this.locationRestrictionEnabled,
    required this.dateRestrictionEnabled,
    required this.deviceRestrictionEnabled,
    this.updatedAt,
    this.updatedBy,
    this.updatedByEmail,
  });

  /// When true: GPS permission + proximity/radius may block check-in.
  /// When false: do not block on deny / outside radius, but still fetch GPS
  /// coordinates for audit when the browser allows.
  final bool locationRestrictionEnabled;

  /// When true: Thursday-only QR + session-day gate (QR must match today).
  /// When false: everyday QR / check-in and daily attendance for any day.
  final bool dateRestrictionEnabled;

  /// When true: each device may submit only one check-in per session day.
  /// When false: shared phones/tablets can check in multiple members
  /// (venue standee mode).
  final bool deviceRestrictionEnabled;

  final DateTime? updatedAt;
  final String? updatedBy;
  final String? updatedByEmail;

  /// Legacy combined flag: true when any restriction is enabled.
  /// Prefer the granular fields at new call sites.
  bool get restrictionsEnabled =>
      locationRestrictionEnabled ||
      dateRestrictionEnabled ||
      deviceRestrictionEnabled;

  static const CheckInRestrictionsConfig defaults = CheckInRestrictionsConfig(
    locationRestrictionEnabled: true,
    dateRestrictionEnabled: true,
    deviceRestrictionEnabled: true,
  );

  /// Maps a legacy single-boolean document into all granular flags.
  factory CheckInRestrictionsConfig.fromLegacyMaster(bool enabled) {
    return CheckInRestrictionsConfig(
      locationRestrictionEnabled: enabled,
      dateRestrictionEnabled: enabled,
      deviceRestrictionEnabled: enabled,
    );
  }

  CheckInRestrictionsConfig copyWith({
    bool? locationRestrictionEnabled,
    bool? dateRestrictionEnabled,
    bool? deviceRestrictionEnabled,
    DateTime? updatedAt,
    String? updatedBy,
    String? updatedByEmail,
  }) {
    return CheckInRestrictionsConfig(
      locationRestrictionEnabled:
          locationRestrictionEnabled ?? this.locationRestrictionEnabled,
      dateRestrictionEnabled:
          dateRestrictionEnabled ?? this.dateRestrictionEnabled,
      deviceRestrictionEnabled:
          deviceRestrictionEnabled ?? this.deviceRestrictionEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByEmail: updatedByEmail ?? this.updatedByEmail,
    );
  }
}
