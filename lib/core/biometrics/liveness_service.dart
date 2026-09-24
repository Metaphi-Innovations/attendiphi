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
/// Face matching alone cannot stop a printed photo or screen replay.
/// Do not invent random/fake liveness scores here.
///
/// TODO: Integrate a production liveness provider (challenge-response blink,
/// depth, or a dedicated anti-spoofing model) and call it after face detection
/// and before descriptor matching.
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
          'Liveness/anti-spoofing is not implemented for Flutter Web yet. Matching proceeds on descriptors only.',
    );
  }
}
