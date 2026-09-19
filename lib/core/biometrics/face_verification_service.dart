/// Result of a biometric face verification against chapter member templates.
class FaceVerificationResult {
  const FaceVerificationResult({
    required this.matched,
    this.memberId,
    this.memberName,
    this.confidence,
    this.similarity,
    this.margin,
    this.reason,
    this.faceDetected = true,
    this.qualityPassed = true,
    this.livenessPassed = true,
    this.candidatesEvaluated = 0,
  });

  final bool matched;
  final String? memberId;
  final String? memberName;
  final double? confidence;
  final double? similarity;
  final double? margin;
  final String? reason;
  final bool faceDetected;
  final bool qualityPassed;
  final bool livenessPassed;
  final int candidatesEvaluated;

  factory FaceVerificationResult.notMatched({
    String? reason,
    bool faceDetected = true,
    bool qualityPassed = true,
    bool livenessPassed = true,
  }) {
    return FaceVerificationResult(
      matched: false,
      reason: reason ?? 'Face not recognized.',
      faceDetected: faceDetected,
      qualityPassed: qualityPassed,
      livenessPassed: livenessPassed,
    );
  }
}

/// Result of evaluating face quality in an image frame.
class FaceQualityResult {
  const FaceQualityResult({
    required this.isValid,
    this.facesDetected = 0,
    this.sharpness = 0.0,
    this.brightness = 0.0,
    this.yaw = 0.0,
    this.roll = 0.0,
    this.errorMessage,
  });

  final bool isValid;
  final int facesDetected;
  final double sharpness;
  final double brightness;
  final double yaw;
  final double roll;
  final String? errorMessage;
}

/// Result of enrolling a member face template on backend.
class FaceEnrollmentResultDto {
  const FaceEnrollmentResultDto({
    required this.success,
    required this.memberId,
    required this.message,
    this.faceModel,
    this.faceModelVersion,
  });

  final bool success;
  final String memberId;
  final String message;
  final String? faceModel;
  final String? faceModelVersion;
}

/// Abstract contract for production face verification and enrollment.
abstract class FaceVerificationService {
  /// Verifies a live selfie against active members in [chapterId].
  Future<FaceVerificationResult> verify({
    required String photoBase64,
    required String chapterId,
    String? locationId,
  });

  /// Evaluates real-time face presence, blur, and lighting.
  Future<FaceQualityResult> checkQuality(String photoBase64);

  /// Enrolls a member's face into protected biometric storage.
  Future<FaceEnrollmentResultDto> enroll({
    required String memberId,
    required String chapterId,
    required String photoBase64,
    String? memberName,
  });
}
