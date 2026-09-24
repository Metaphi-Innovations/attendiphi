/// Centralized configuration parameters for the SFace client-side face verification pipeline.
class FaceMatchingConfig {
  const FaceMatchingConfig._();

  /// SFace model name and version metadata.
  static const String modelName = 'sface';
  static const String modelVersion = '2021dec';
  static const int embeddingDimension = 128;

  /// Cosine similarity floor for a genuine match after aligned SFace crops.
  static const double similarityThreshold = 0.58;

  /// Alias used by attendance matching. Same value as [similarityThreshold].
  static const double matchThreshold = similarityThreshold;

  /// Member-level gap between top and runner-up scores.
  static const double marginThreshold = 0.06;

  /// Share of *accepted* burst frames that must agree on the same member.
  static const double consistencyThreshold = 0.60;

  /// Number of live frames captured in a verification burst.
  static const int burstFrameCount = 5;

  /// Minimum aligned frames that actually matched a member.
  static const int minimumValidFrames = 2;

  /// Maximum allowed verification retries for borderline/ambiguous genuine attempts.
  static const int maxVerificationRetries = 2;

  /// Pairwise cosine floor used when scoring enrollment template diversity.
  static const double enrollmentConsistencyThreshold = 0.50;

  /// Fraction of enrollment pairs that must clear [enrollmentConsistencyThreshold].
  static const double enrollmentPairwisePassRatio = 0.60;

  /// Mean pairwise similarity below which a template is treated as an outlier.
  static const double enrollmentOutlierMeanThreshold = 0.40;

  /// Minimum number of high-quality templates required to persist a web enrollment.
  static const int minimumEnrollmentTemplates = 3;

  /// Quality validation thresholds for verification frames (looser than enroll).
  static const double minimumFaceSizeRatio = 0.12;
  static const double verifyMinimumFaceSizeRatio = 0.12;
  static const double enrollMinimumFaceSizeRatio = 0.16;
  static const double minimumSharpness = 18.0;
  static const double verifyMinimumSharpness = 18.0;
  static const double enrollMinimumSharpness = 28.0;
  static const double minimumBrightness = 35.0;
  static const double maximumBrightness = 230.0;
  static const double verifyMinimumImageSide = 160.0;
  static const double enrollMinimumImageSide = 240.0;

  static double minimumSharpnessFor({required bool forEnrollment}) =>
      forEnrollment ? enrollMinimumSharpness : verifyMinimumSharpness;

  static double minimumFaceSizeRatioFor({required bool forEnrollment}) =>
      forEnrollment ? enrollMinimumFaceSizeRatio : verifyMinimumFaceSizeRatio;

  /// Returns a user-facing rejection reason, or null if quality is acceptable.
  /// Sharpness / face-size of 0 are treated as unknown (skip that check).
  static String? qualityRejectionReason({
    required bool forEnrollment,
    double sharpness = 0.0,
    double brightness = 0.0,
    double faceSizeRatio = 0.0,
  }) {
    if (faceSizeRatio > 0 &&
        faceSizeRatio < minimumFaceSizeRatioFor(forEnrollment: forEnrollment)) {
      return 'Please move closer to the camera so your face fills the frame.';
    }
    if (sharpness > 0 &&
        sharpness < minimumSharpnessFor(forEnrollment: forEnrollment)) {
      return 'Image is blurry. Please hold steady and try again.';
    }
    if (brightness > 0 && brightness < minimumBrightness) {
      return 'Lighting is too dark. Please move to a brighter area.';
    }
    if (brightness > maximumBrightness) {
      return 'Lighting is too bright or washed out. Please avoid strong backlight.';
    }
    return null;
  }
}

/// Canonical attendance face-recognition settings.
/// Thresholds live in one place so they are not hard-coded across UI/services.
typedef FaceRecognitionConfig = FaceMatchingConfig;
