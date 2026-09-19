/// Result of single-frame SFace validation and embedding extraction.
class ValidatedFaceFrame {
  const ValidatedFaceFrame({
    required this.isValid,
    this.errorMessage,
    this.embedding,
    this.sharpness = 0.0,
    this.brightness = 0.0,
  });

  final bool isValid;
  final String? errorMessage;
  final List<double>? embedding;
  final double sharpness;
  final double brightness;
}

/// Stub for non-web platforms.
Future<List<double>?> extractFaceEmbeddingWeb(String photoBase64) async {
  return null;
}

/// Stub for non-web platforms.
Future<ValidatedFaceFrame> validateAndExtractFaceFrameWeb(String photoBase64) async {
  return const ValidatedFaceFrame(
    isValid: false,
    errorMessage: 'Web neural face verifier is only available on web.',
  );
}
