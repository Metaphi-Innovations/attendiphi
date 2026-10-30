/// Result of a liveness / anti-spoofing check.
class LivenessCheckResult {
  const LivenessCheckResult({
    required this.passed,
    this.reason,
    this.implemented = false,
  });

  final bool passed;
  final String? reason;

  /// False until a real liveness provider is wired in.
  final bool implemented;
}

/// Integration point for production anti-spoofing.
///
/// **P2 policy:** liveness is a **soft signal** only until a real provider is
/// wired. [CloudFaceRecognitionService] must not hard-fail check-in / match
/// when [LivenessCheckResult.implemented] is false or when a future provider
/// returns `passed: false` — log and continue with descriptor match.
///
/// Face matching alone cannot stop a printed photo or screen replay.
/// Do not invent random/fake liveness scores here.
///
/// Future work: integrate a production liveness provider (challenge-response
/// blink, depth, or a dedicated anti-spoofing model) after face detection and
/// before descriptor matching. Only then consider a hard gate behind a
/// feature flag.
abstract class LivenessService {
  Future<LivenessCheckResult> evaluateLiveCapture();
}

/// Placeholder that does not claim a live person was proven.
class UnimplementedLivenessService implements LivenessService {
  const UnimplementedLivenessService();

  @override
  Future<LivenessCheckResult> evaluateLiveCapture() async {
    return const LivenessCheckResult(
      passed: true,
      implemented: false,
      reason:
          'Liveness/anti-spoofing is not implemented (soft signal). '
          'Matching proceeds on descriptors only.',
    );
  }
}
