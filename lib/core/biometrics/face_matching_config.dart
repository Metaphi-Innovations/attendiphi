/// Centralized configuration parameters for the SFace client-side face verification pipeline.
class FaceMatchingConfig {
  const FaceMatchingConfig._();

  /// SFace model name and version metadata.
  static const String modelName = 'sface';
  static const String modelVersion = '2021dec';
  static const int embeddingDimension = 128;

  /// Cosine similarity threshold for a genuine match.
  /// For SFace L2-normalized 128-d vectors, cosine similarity >= 0.65 indicates
  /// strong biometric evidence of the same individual.
  static const double similarityThreshold = 0.65;

  /// Minimum margin separation required between the top candidate and the runner-up:
  /// (bestScore - secondBestScore) >= marginThreshold.
  /// Enforces rejection of ambiguous near-misses (e.g. 0.84 vs 0.82) to prevent
  /// cross-employee misidentification (such as Devendra -> Omkar).
  static const double marginThreshold = 0.10;

  /// Consistency threshold across multi-frame verification bursts.
  /// At least 60% of valid frames must identify the exact same winning candidate.
  static const double consistencyThreshold = 0.60;

  /// Number of live frames captured in a verification burst.
  static const int burstFrameCount = 5;

  /// Minimum number of high-quality valid frames required in a burst.
  static const int minimumValidFrames = 3;

  /// Maximum allowed verification retries for borderline/ambiguous genuine attempts.
  static const int maxVerificationRetries = 2;

  /// Pairwise cosine similarity floor for enrollment frames.
  /// All 3-5 enrollment frames captured for a member must cross-match with >= 0.75
  /// to ensure consistent, reliable biometric templates are stored.
  static const double enrollmentConsistencyThreshold = 0.75;

  /// Quality validation thresholds for input frames.
  static const double minimumFaceSizeRatio = 0.20; // Face box relative to frame width
  static const double minimumSharpness = 25.0;     // Blur rejection floor (Laplacian variance)
  static const double minimumBrightness = 40.0;    // Minimum luma
  static const double maximumBrightness = 230.0;   // Maximum luma (overexposure check)
}
