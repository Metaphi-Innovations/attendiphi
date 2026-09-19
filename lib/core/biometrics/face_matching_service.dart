import 'dart:math';

import '../../features/employee/domain/entities/employee.dart';
import 'face_matching_config.dart';

/// Status of a face matching attempt.
enum FaceMatchStatus {
  /// Strong biometric match meeting both similarity and margin thresholds.
  match,

  /// Face similarity is high but the separation from runner-up is too small.
  /// Trigger a retry rather than accepting or guessing.
  ambiguous,

  /// Probe does not match any candidate above the minimum similarity threshold.
  unknownPerson,

  /// No valid enrolled candidates available for this meeting session.
  noCandidates,
}

/// Result of matching a single live probe embedding against enrolled candidates.
class SingleFrameMatchResult {
  const SingleFrameMatchResult({
    required this.status,
    this.bestCandidate,
    this.bestScore = 0.0,
    this.secondBestCandidate,
    this.secondBestScore = 0.0,
    this.margin = 0.0,
    this.evaluatedCandidatesCount = 0,
  });

  final FaceMatchStatus status;
  final Employee? bestCandidate;
  final double bestScore;
  final Employee? secondBestCandidate;
  final double secondBestScore;
  final double margin;
  final int evaluatedCandidatesCount;

  bool get isMatch => status == FaceMatchStatus.match;
  bool get isAmbiguous => status == FaceMatchStatus.ambiguous;
}

/// Multi-frame aggregated decision across a short burst of verification frames.
class MultiFrameMatchDecision {
  const MultiFrameMatchDecision({
    required this.verified,
    this.matchedMember,
    required this.averageScore,
    required this.averageMargin,
    required this.consistencyRate,
    required this.validFramesCount,
    required this.totalFramesCount,
    required this.statusMessage,
    this.shouldRetry = false,
  });

  final bool verified;
  final Employee? matchedMember;
  final double averageScore;
  final double averageMargin;
  final double consistencyRate;
  final int validFramesCount;
  final int totalFramesCount;
  final String statusMessage;
  final bool shouldRetry;
}

/// Result of matching a live face against enrolled member database (backwards compatible).
class FaceMatchResult {
  const FaceMatchResult({
    required this.candidate,
    required this.distance,
    required this.confidence,
    required this.isMatch,
    this.cosineSimilarity,
    this.margin = 0.0,
    this.isAmbiguous = false,
  });

  final Employee candidate;
  final double distance;
  final double confidence;
  final bool isMatch;
  final double? cosineSimilarity;
  final double margin;
  final bool isAmbiguous;
}

/// Pure mathematical biometric vector comparison and nearest-neighbor
/// matching using SFace L2-normalized 128-d vectors and Cosine Similarity.
class FaceMatchingService {
  /// Cosine similarity threshold from centralized configuration.
  static const double defaultCosineThreshold =
      FaceMatchingConfig.similarityThreshold;

  /// Separation margin between #1 and #2 candidate from centralized configuration.
  static const double defaultMarginThreshold =
      FaceMatchingConfig.marginThreshold;

  /// Calculates Cosine similarity between two feature vectors.
  /// For L2-normalized vectors (||emb|| = 1.0), this is the dot product.
  /// Returns 1.0 for identical vectors, 0.0 for orthogonal vectors, -1.0 for opposites.
  double calculateCosineSimilarity(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) {
      throw ArgumentError(
        'Embedding lengths do not match: ${emb1.length} vs ${emb2.length}',
      );
    }

    double dot = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    for (int i = 0; i < emb1.length; i++) {
      dot += emb1[i] * emb2[i];
      norm1 += emb1[i] * emb1[i];
      norm2 += emb2[i] * emb2[i];
    }

    final denom = sqrt(norm1) * sqrt(norm2);
    if (denom <= 1e-12) return 0.0;
    return (dot / denom).clamp(-1.0, 1.0);
  }

  /// Calculates Euclidean distance between two vectors.
  double calculateEuclideanDistance(List<double> emb1, List<double> emb2) {
    if (emb1.length != emb2.length) {
      throw ArgumentError(
        'Embedding lengths do not match: ${emb1.length} vs ${emb2.length}',
      );
    }

    double sum = 0.0;
    for (int i = 0; i < emb1.length; i++) {
      final diff = emb1[i] - emb2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  /// Converts Euclidean distance to confidence percentage (0% to 100%).
  double distanceToConfidence(double distance, {double maxDistance = 1.2}) {
    final normalized = (1.0 - (distance / maxDistance)).clamp(0.0, 1.0);
    return double.parse((normalized * 100).toStringAsFixed(1));
  }

  /// Converts Cosine similarity to confidence percentage (0% to 100%).
  double cosineToConfidence(double similarity, {double baseThreshold = 0.20}) {
    if (similarity <= baseThreshold) return 0.0;
    final normalized =
        ((similarity - baseThreshold) / (1.0 - baseThreshold)).clamp(0.0, 1.0);
    return double.parse((normalized * 100).toStringAsFixed(1));
  }

  /// Backward-compatible single-match search method across candidates.
  FaceMatchResult? findBestMatch({
    required List<double> probeEmbedding,
    required List<Employee> candidates,
    double threshold = 0.75,
    double marginThreshold = 0.05,
  }) {
    final validCandidates = candidates
        .where((c) => c.allFaceTemplates.isNotEmpty)
        .toList();

    if (validCandidates.isEmpty) return null;

    Employee? bestCandidate;
    double bestDistance = double.infinity;
    double bestCosine = -1.0;

    Employee? secondBestCandidate;
    double secondBestDistance = double.infinity;

    for (final candidate in validCandidates) {
      for (final template in candidate.allFaceTemplates) {
        if (template.length != probeEmbedding.length) continue;
        final dist = calculateEuclideanDistance(probeEmbedding, template);
        final cosine = calculateCosineSimilarity(probeEmbedding, template);

        if (dist < bestDistance) {
          secondBestCandidate = bestCandidate;
          secondBestDistance = bestDistance;
          bestCandidate = candidate;
          bestDistance = dist;
          bestCosine = cosine;
        } else if (dist < secondBestDistance) {
          secondBestCandidate = candidate;
          secondBestDistance = dist;
        }
      }
    }

    if (bestCandidate == null) return null;

    final margin = (secondBestDistance.isFinite &&
            secondBestCandidate != null &&
            secondBestCandidate.id != bestCandidate.id)
        ? (secondBestDistance - bestDistance)
        : 1.0;

    final isAmbiguous = margin < marginThreshold && validCandidates.length > 1;
    final isMatch = bestDistance <= threshold && !isAmbiguous;
    final confidence = distanceToConfidence(bestDistance);

    return FaceMatchResult(
      candidate: bestCandidate,
      distance: bestDistance,
      confidence: confidence,
      isMatch: isMatch,
      cosineSimilarity: bestCosine,
      margin: margin,
      isAmbiguous: isAmbiguous,
    );
  }

  /// Validates consistency among 3–5 enrollment frames.
  /// Requires every pair of enrollment templates to have Cosine similarity >= [threshold].
  bool validateEnrollmentConsistency(
    List<List<double>> templates, {
    double threshold = FaceMatchingConfig.enrollmentConsistencyThreshold,
  }) {
    if (templates.length < 2) return false;

    for (int i = 0; i < templates.length; i++) {
      for (int j = i + 1; j < templates.length; j++) {
        final sim = calculateCosineSimilarity(templates[i], templates[j]);
        if (sim < threshold) {
          return false;
        }
      }
    }
    return true;
  }

  /// Matches a single probe embedding against [candidates] using multi-template scoring
  /// and best-vs-second-best margin enforcement.
  SingleFrameMatchResult matchProbeAgainstCandidates({
    required List<double> probeEmbedding,
    required List<Employee> candidates,
    double similarityThreshold = FaceMatchingConfig.similarityThreshold,
    double marginThreshold = FaceMatchingConfig.marginThreshold,
  }) {
    if (candidates.isEmpty) {
      return const SingleFrameMatchResult(status: FaceMatchStatus.noCandidates);
    }

    Employee? bestCandidate;
    double bestScore = -1.0;

    Employee? secondBestCandidate;
    double secondBestScore = -1.0;

    int evaluatedCount = 0;

    for (final candidate in candidates) {
      final templates = candidate.allFaceTemplates;
      if (templates.isEmpty) continue;

      evaluatedCount++;

      // Multi-template: Score for candidate is the max similarity across all enrolled templates
      double candidateBestScore = -1.0;
      for (final template in templates) {
        if (template.length != probeEmbedding.length) continue;
        final sim = calculateCosineSimilarity(probeEmbedding, template);
        if (sim > candidateBestScore) {
          candidateBestScore = sim;
        }
      }

      if (candidateBestScore > bestScore) {
        // Demote current best to second best
        secondBestScore = bestScore;
        secondBestCandidate = bestCandidate;

        bestScore = candidateBestScore;
        bestCandidate = candidate;
      } else if (candidateBestScore > secondBestScore) {
        secondBestScore = candidateBestScore;
        secondBestCandidate = candidate;
      }
    }

    if (bestCandidate == null || evaluatedCount == 0) {
      return const SingleFrameMatchResult(status: FaceMatchStatus.noCandidates);
    }

    final double margin = secondBestCandidate != null
        ? (bestScore - secondBestScore)
        : 1.0;

    // Strict decision logic:
    // 1. Must clear absolute similarity floor
    if (bestScore < similarityThreshold) {
      return SingleFrameMatchResult(
        status: FaceMatchStatus.unknownPerson,
        bestCandidate: bestCandidate,
        bestScore: bestScore,
        secondBestCandidate: secondBestCandidate,
        secondBestScore: secondBestScore,
        margin: margin,
        evaluatedCandidatesCount: evaluatedCount,
      );
    }

    // 2. Must clear margin separation threshold over the runner-up
    if (secondBestCandidate != null && margin < marginThreshold) {
      return SingleFrameMatchResult(
        status: FaceMatchStatus.ambiguous,
        bestCandidate: bestCandidate,
        bestScore: bestScore,
        secondBestCandidate: secondBestCandidate,
        secondBestScore: secondBestScore,
        margin: margin,
        evaluatedCandidatesCount: evaluatedCount,
      );
    }

    // 3. Both criteria satisfied
    return SingleFrameMatchResult(
      status: FaceMatchStatus.match,
      bestCandidate: bestCandidate,
      bestScore: bestScore,
      secondBestCandidate: secondBestCandidate,
      secondBestScore: secondBestScore,
      margin: margin,
      evaluatedCandidatesCount: evaluatedCount,
    );
  }

  /// Aggregates a burst of single-frame match results and returns a multi-frame decision.
  MultiFrameMatchDecision evaluateMultiFrameDecision({
    required List<SingleFrameMatchResult> frameMatches,
    int totalFramesCount = FaceMatchingConfig.burstFrameCount,
    int minValidFrames = FaceMatchingConfig.minimumValidFrames,
    double consistencyThreshold = FaceMatchingConfig.consistencyThreshold,
  }) {
    if (frameMatches.length < minValidFrames) {
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: 0.0,
        averageMargin: 0.0,
        consistencyRate: 0.0,
        validFramesCount: frameMatches.length,
        totalFramesCount: totalFramesCount,
        statusMessage:
            'Face quality insufficient. Please hold still in good lighting.',
        shouldRetry: true,
      );
    }

    // Count winning occurrences by candidate ID
    final Map<String, int> candidateWins = {};
    final Map<String, Employee> candidateMap = {};
    final Map<String, List<double>> candidateScores = {};
    final Map<String, List<double>> candidateMargins = {};

    for (final frame in frameMatches) {
      if (frame.bestCandidate != null) {
        final id = frame.bestCandidate!.id;
        candidateWins[id] = (candidateWins[id] ?? 0) + 1;
        candidateMap[id] = frame.bestCandidate!;
        candidateScores.putIfAbsent(id, () => []).add(frame.bestScore);
        candidateMargins.putIfAbsent(id, () => []).add(frame.margin);
      }
    }

    if (candidateWins.isEmpty) {
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: 0.0,
        averageMargin: 0.0,
        consistencyRate: 0.0,
        validFramesCount: frameMatches.length,
        totalFramesCount: totalFramesCount,
        statusMessage: 'Face not recognized in this chapter.',
        shouldRetry: false,
      );
    }

    // Find the candidate who won the most frames
    String topId = candidateWins.keys.first;
    int topWins = candidateWins[topId]!;
    for (final entry in candidateWins.entries) {
      if (entry.value > topWins) {
        topWins = entry.value;
        topId = entry.key;
      }
    }

    final topCandidate = candidateMap[topId]!;
    final consistencyRate = topWins / frameMatches.length;

    final scores = candidateScores[topId] ?? [];
    final avgScore = scores.isNotEmpty
        ? scores.reduce((a, b) => a + b) / scores.length
        : 0.0;

    final margins = candidateMargins[topId] ?? [];
    final avgMargin = margins.isNotEmpty
        ? margins.reduce((a, b) => a + b) / margins.length
        : 0.0;

    // Check multi-frame consistency
    if (consistencyRate < consistencyThreshold) {
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: avgScore,
        averageMargin: avgMargin,
        consistencyRate: consistencyRate,
        validFramesCount: frameMatches.length,
        totalFramesCount: totalFramesCount,
        statusMessage: 'Face verification inconsistent across frames. Please retry.',
        shouldRetry: true,
      );
    }

    // Check if frames were ambiguous
    final ambiguousFramesCount = frameMatches
        .where((f) => f.bestCandidate?.id == topId && f.isAmbiguous)
        .length;

    if (ambiguousFramesCount > frameMatches.length / 2 ||
        avgMargin < FaceMatchingConfig.marginThreshold) {
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: avgScore,
        averageMargin: avgMargin,
        consistencyRate: consistencyRate,
        validFramesCount: frameMatches.length,
        totalFramesCount: totalFramesCount,
        statusMessage:
            'Face match ambiguous. Please look directly at the camera and try again.',
        shouldRetry: true,
      );
    }

    // Check if score cleared similarity threshold
    if (avgScore < FaceMatchingConfig.similarityThreshold) {
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: avgScore,
        averageMargin: avgMargin,
        consistencyRate: consistencyRate,
        validFramesCount: frameMatches.length,
        totalFramesCount: totalFramesCount,
        statusMessage: 'Face not recognized in this chapter.',
        shouldRetry: false,
      );
    }

    // High genuine match verified
    return MultiFrameMatchDecision(
      verified: true,
      matchedMember: topCandidate,
      averageScore: avgScore,
      averageMargin: avgMargin,
      consistencyRate: consistencyRate,
      validFramesCount: frameMatches.length,
      totalFramesCount: totalFramesCount,
      statusMessage: 'Face Verified',
      shouldRetry: false,
    );
  }
}
