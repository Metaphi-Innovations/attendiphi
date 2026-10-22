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
  static const locationPermissionDenied =
      'Location was denied. Enable location for this site to verify you are at the venue.';
  static const locationPermissionPermanentlyDenied =
      'Location is blocked for this site. Enable it in the browser, then reload or scan the QR again to continue check-in.';
  static const locationPermissionOpenSettings = 'Open Settings';
  static const locationPermissionAllow = 'Allow Location';
  static const locationPermissionWebHelp =
      'On web: tap the lock/tune icon next to the URL → Site settings → Location → Allow (or Ask), then reload this page or scan the QR again.';
  static const locationServiceDisabled =
      'Location services are turned off. Please enable them to continue.';
  static const locationFetchingPosition = 'Getting your location...';
  static const locationTimeout =
      'Unable to determine your location. Please check your GPS and try again.';
  static const locationAccuracyTooLow =
      'Your GPS signal is too weak for accurate verification. '
      'Please move to an open area and try again.';

  // ── Location Validation ──────────────────────────────────────────────────
  static String locationTooFar(double distanceMeters) {
    final distance = distanceMeters.round();
    return 'You are approximately $distance meters away from the check-in location.\n\n'
        'Please move closer and try again.';
  }

  static String locationValid(double distanceMeters) {
    final distance = distanceMeters.round();
    return 'Location verified. You are $distance meters from the check-in point.';
  }

  static const locationValidating = 'Validating your location...';
  static const locationRetry = 'Retry Location';

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
