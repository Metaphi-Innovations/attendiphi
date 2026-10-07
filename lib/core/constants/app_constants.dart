/// Application-wide constants.
class AppConstants {
  AppConstants._();

  // ── GPS / Location ────────────────────────────────────────────────────
  /// Maximum acceptable GPS accuracy in meters.
  /// Readings with accuracy above this threshold are rejected.
  static const double maxGpsAccuracyMeters = 100;

  /// Default check-in radius in meters.
  /// Overridden per-location from Firestore configuration.
  static const double defaultRadiusMeters = 500;

  /// GPS position timeout in seconds.
  static const int gpsTimeoutSeconds = 30;

  // ── Image ─────────────────────────────────────────────────────────────
  /// Maximum dimension for compressed face photos (optimized for fast upload).
  static const int maxPhotoPixels = 480;

  /// JPEG compression quality (0-100).
  static const int photoCompressionQuality = 65;

  /// Maximum file size for uploaded photos (5 MB).
  static const int maxPhotoSizeBytes = 5 * 1024 * 1024;

  // ── Form Validation ───────────────────────────────────────────────────
  /// Minimum length for a valid name.
  static const int nameMinLength = 2;

  /// Maximum length for a valid name.
  static const int nameMaxLength = 100;

  /// Expected length of an Indian phone number (without country code).
  static const int phoneNumberLength = 10;

  /// Indian country code prefix.
  static const String phoneCountryCode = '+91';

  // ── Pagination ────────────────────────────────────────────────────────
  /// Number of check-in records per page in the dashboard.
  static const int dashboardPageSize = 20;

  // ── Firebase Paths ────────────────────────────────────────────────────
  static const String locationsCollection = 'locations';
  static const String checkInsCollection = 'checkIns';
  /// Public create-once locks: one device may check in once per session date.
  static const String deviceSessionLocksCollection = 'deviceSessionLocks';
  static const String adminsCollection = 'admins';
  static const String employeesCollection = 'employees';
  static const String adminDevicesCollection = 'admin_devices';
  static const String adminNotificationsCollection = 'admin_notifications';
  static const String adminMailDispatchCollection = 'admin_mail_dispatch';
  /// Live app settings (e.g. check-in restriction master toggle).
  static const String appConfigCollection = 'appConfig';
  static const String checkInRestrictionsDocId = 'checkInRestrictions';
  static const String substitutePhotosPath = 'substitute_photos';

  // ── Push Notifications ────────────────────────────────────────────────
  static const String notificationChannelId = 'admin_attendance_channel';
  static const String notificationChannelName = 'Admin Attendance Alerts';
  static const String notificationChannelDescription =
      'Notifications delivered to Admin when an attendance check-in is submitted';

  // ── Cloud Function Names ──────────────────────────────────────────────
  static const String submitCheckInFunction = 'submitCheckIn';
}
