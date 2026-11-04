/// Centralized user-facing strings for the QR Check-In application.
///
/// All user-visible text is defined here to support future localization.
/// No user-facing strings should be scattered throughout business logic.
class AppStrings {
  AppStrings._();

  // ── App ──────────────────────────────────────────────────────────────────
  static const appName = 'Attendiphi by Metaphi';
  static const appTagline = 'Scan. Verify. Check In.';

  // ── QR Scanner ───────────────────────────────────────────────────────────
  static const qrScannerTitle = 'Scan QR Code';
  static const qrScannerInstruction =
      'Point your camera at the location QR code to begin check-in.';
  static const qrScannerProcessing = 'Processing QR code...';
  static const qrInvalidCode = 'This QR code is not valid for check-in.';
  static const qrMalformedPayload =
      'The QR code could not be read. Please try scanning again.';
  static const qrLocationNotFound =
      'This check-in location was not found. Please contact your administrator.';
  static const qrLocationInactive =
      'This check-in location is currently inactive.';
  static const qrScanAnother = 'Scan Another';

  // ── Location Permission ──────────────────────────────────────────────────
  static const locationPermissionTitle = 'Location Access Required';
  static const locationPermissionRationale =
      'Location permission is required to verify that you are at the check-in location.';
  static const locationPermissionGrant = 'Grant Permission';
  static const locationPermissionOpenSettings = 'Open Settings';
  static const locationPermissionAllow = 'Allow Location';
  // Single screen CTA (permission not decided yet). No in-app Allow dialog —
  // the CTA itself is the user gesture that opens the browser/OS prompt.
  static const locationPermissionAwaitingAllow =
      'Tap Allow Location so we can verify you are at the venue. Your browser '
      'will ask for permission.';

  // Permission not granted, cause ambiguous (dismissed prompt, or the phone's
  // Location was off). Must not claim either one.
  static const locationPermissionDenied =
      "Location access wasn't granted. Tap Allow Location and choose Allow when "
      'asked. If Location is turned off on your phone, turn it on first.';

  // Blocked for this site.
  static const locationPermissionBlockedTitle = 'Location Permission Blocked';
  static const locationPermissionPermanentlyDenied =
      "Location access is blocked for this website. Please update your browser's "
      'site settings to continue.';
  static const locationPermissionBlockedNative =
      'Location access is blocked for Attendiphi. Open Settings, allow Location, '
      'then return to Attendiphi — check-in will continue automatically.';
  static const locationBlockedAndroidHeading = 'Android Chrome';
  static const locationBlockedAndroidSteps = [
    'Open Chrome.',
    'Tap the site information/settings icon beside the URL.',
    'Open Site Settings.',
    'Select Location.',
    'Change it to Allow.',
    'Return to Attendiphi — check-in will continue automatically.',
  ];
  static const locationBlockedIosHeading = 'iPhone Safari';
  static const locationBlockedIosSteps = [
    'Tap the page settings (aA) icon in the address bar.',
    'Open Website Settings.',
    'Set Location to Allow.',
    'Return to Attendiphi — check-in will continue automatically.',
  ];
  static const locationBlockedDesktopHeading = 'Desktop browser';
  static const locationBlockedDesktopSteps = [
    'Click the site information icon beside the address bar.',
    'Open Site settings (or Permissions).',
    'Set Location to Allow.',
    'Return to this tab — check-in will continue automatically.',
  ];

  // Device Location (GPS) off — short, user-centric copy.
  static const locationServiceOffTitle = 'Location is Turned Off';
  static const locationServiceOffBody =
      'Please turn on Location on your phone, then tap Allow Location to '
      'continue check-in.';
  static const locationServiceDisabled =
      'Please turn on Location on your phone, then tap Allow Location to '
      'continue check-in.';

  // Progress.
  static const locationCheckingService = 'Checking location settings...';
  static const locationRequestingPermission =
      'Requesting location permission...';
  static const locationFetchingPosition = 'Fetching your location...';
  static const locationVerifyingVenue = 'Verifying your venue...';

  // Acquisition failures.
  static const locationTimeout =
      'Getting your location is taking longer than expected. Move near a window '
      'or outdoors, then tap Retry.';
  static const locationUnavailable =
      "We couldn't determine your location. Make sure Location is turned on for "
      'this device, then tap Retry.';
  static const locationAccuracyTooLow =
      'Your location is not precise enough to verify you are at the venue. '
      'Turn on precise / high-accuracy location, move near a window or '
      'outdoors, then tap Retry.';
  static const locationVerificationRequired =
      'Please verify your location at the venue before checking in.';

  // ── Location Validation ──────────────────────────────────────────────────
  static String locationTooFar(double distanceMeters) {
    final distance = distanceMeters.round();
    return 'You are approximately $distance meters away from the check-in location.\n\n'
        'Please move closer and try again.';
  }

  /// [allowedLabel] should already be friendly, e.g. `50 km` or `700 m`.
  static String locationOutsideAllowedRadius({
    required double distanceMeters,
    required String allowedLabel,
  }) {
    final distance = distanceMeters.round();
    return 'You are currently ~$distance meters away from this venue. '
        'Check-in is only permitted within $allowedLabel.';
  }

  static String locationValid(double distanceMeters) {
    final distance = distanceMeters.round();
    return 'Location verified. You are $distance meters from the check-in point.';
  }

  static const locationValidating = 'Validating your location...';
  static const locationRetry = 'Retry Location';
  static const locationRetryShort = 'Retry';

  // ── Venue check-in radius (admin restrictions) ───────────────────────────
  static const venueCheckInRadiusTitle = 'Venue check-in radius';
  static const venueCheckInRadiusHelper =
      'Members must be within this distance of the venue to check in.';
  static const venueCheckInRadiusUnitMeters = 'm';
  static const venueCheckInRadiusUnitKilometers = 'km';
  static const venueCheckInRadiusInvalid =
      'Enter a valid radius greater than 0.';
  static const venueCheckInRadiusSaved = 'Venue check-in radius updated';
  static const venueCheckInRadiusSave = 'Save radius';
  static String venueCheckInRadiusCurrent(String friendly) =>
      'Currently saved: $friendly';

  // ── Check-In Form ────────────────────────────────────────────────────────
  static const checkInFormTitle = 'Check In';
  static const checkInFieldName = 'Full Name';
  static const checkInFieldNameHint = 'Enter your full name';
  static const checkInFieldPhone = 'Phone Number';
  static const checkInFieldPhoneHint = 'Enter your 10-digit phone number';
  static const checkInFieldPhonePrefix = '+91';
  static const checkInFieldType = 'Attendance Type';
  static const checkInTypeMember = 'Member';
  static const checkInTypeSubstitute = 'Substitute';
  static const checkInSubmit = 'Check In';
  static const checkInSubmitting = 'Submitting your check-in...';

  // ── Form Validation ──────────────────────────────────────────────────────
  static const validationNameRequired = 'Name is required.';
  static const validationNameTooShort =
      'Name must be at least 2 characters long.';
  static const validationNameTooLong = 'Name must not exceed 100 characters.';
  static const validationNameInvalid = 'Name contains invalid characters.';
  static const validationPhoneRequired = 'Phone number is required.';
  static const validationPhoneInvalid =
      'Please enter a valid 10-digit Indian phone number.';
  static const validationTypeRequired = 'Please select an attendance type.';
  static const validationPhotoRequired =
      'A face photo is required for substitute check-in.';

  // ── Substitute / Camera ──────────────────────────────────────────────────
  static const cameraTitle = 'Take Face Photo';
  static const cameraInstruction =
      'Please take a clear photo of your face for verification.';
  static const cameraCapture = 'Take Photo';
  static const cameraRetake = 'Retake';
  static const cameraConfirm = 'Use This Photo';
  static const cameraPermissionDenied =
      'Camera permission is required to take a verification photo.';
  static const cameraFailed = 'Unable to access the camera. Please try again.';
  static const photoUploading = 'Uploading photo...';
  static const photoUploadFailed = 'Photo upload failed. Please try again.';

  // ── Submission ───────────────────────────────────────────────────────────
  static const submissionInProgress = 'Submitting your check-in...';
  static const submissionSuccess = 'Check-In Successful!';
  static const submissionSuccessMessage =
      'Your attendance has been recorded successfully.';
  static const submissionFailed = 'Check-in failed. Please try again.';
  static const submissionDuplicate =
      'You have already checked in. Duplicate submissions are not allowed.';
  static const submissionDone = 'Done';
  static const submissionScanAnother = 'Scan Another QR';

  // ── Network ──────────────────────────────────────────────────────────────
  static const networkUnavailable =
      'No internet connection. Please reconnect and try again.';
  static const networkRetry = 'Retry';

  // ── Admin ────────────────────────────────────────────────────────────────
  static const adminLoginTitle = 'Admin Login';
  static const adminLoginEmail = 'Email';
  static const adminLoginPassword = 'Password';
  static const adminLoginSubmit = 'Sign In';
  static const adminLoginFailed = 'Invalid email or password.';
  static const adminUnauthorized = 'You do not have administrator access.';
  static const adminLogout = 'Sign Out';

  // ── Dashboard ────────────────────────────────────────────────────────────
  static const dashboardTitle = 'Daily Attendance';
  static const dashboardSearchHint = 'Search by name or phone...';
  static const dashboardFilterAll = 'All';
  static const dashboardFilterMember = 'Members';
  static const dashboardFilterSubstitute = 'Substitutes';
  static const dashboardEmpty = 'No check-in records found.';
  static const dashboardLoadMore = 'Load More';
  static const dashboardLoading = 'Loading check-ins...';

  // ── Check-In Detail ──────────────────────────────────────────────────────
  static const detailTitle = 'Check-In Details';
  static const detailName = 'Name';
  static const detailPhone = 'Phone';
  static const detailType = 'Type';
  static const detailLocation = 'Location';
  static const detailDistance = 'Distance';
  static const detailAccuracy = 'GPS Accuracy';
  static const detailDate = 'Date';
  static const detailTime = 'Time';
  static const detailStatus = 'Status';
  static const detailPhoto = 'Verification Photo';

  // ── Generic ──────────────────────────────────────────────────────────────
  static const genericError = 'Something went wrong. Please try again.';
  static const genericCancel = 'Cancel';
  static const genericOk = 'OK';
  static const genericRetry = 'Retry';
  static const genericBack = 'Back';
  static const genericContinue = 'Continue';
  static const genericLoading = 'Loading...';
}
