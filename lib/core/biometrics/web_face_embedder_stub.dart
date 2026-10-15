import 'face_matching_config.dart';

/// Result of single-frame SFace validation and embedding extraction.
class ValidatedFaceFrame {
  const ValidatedFaceFrame({
    required this.isValid,
    this.errorMessage,
    this.embedding,
    this.sharpness = 0.0,
    this.brightness = 0.0,
    this.faceSizeRatio = 0.0,
    this.faceCount = 0,
    this.poseYaw = 0.0,
    this.poseLabel,
  });

  final bool isValid;
  final String? errorMessage;
  final List<double>? embedding;
  final double sharpness;
  final double brightness;
  final double faceSizeRatio;
  final int faceCount;
  final double poseYaw;
  final String? poseLabel;

  bool meetsQuality({required bool forEnrollment}) =>
      FaceMatchingConfig.qualityRejectionReason(
        forEnrollment: forEnrollment,
        sharpness: sharpness,
        brightness: brightness,
        faceSizeRatio: faceSizeRatio,
      ) ==
      null;
}

/// Stub for non-web platforms.
Future<bool> initializeFaceRecognitionWeb() async => false;

/// Stub for non-web platforms.
Future<List<double>?> extractFaceEmbeddingWeb(String photoBase64) async {
  return null;
}

/// Stub for non-web platforms.
Future<ValidatedFaceFrame> validateAndExtractFaceFrameWeb(
  String photoBase64, {
  bool forEnrollment = false,
}) async {
  return const ValidatedFaceFrame(
    isValid: false,
    errorMessage: 'Web neural face verifier is only available on web.',
  );
}
