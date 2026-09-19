import 'dart:math';
import '../../features/employee/domain/entities/employee.dart';

/// Result of matching a live face against enrolled member database.
class FaceMatchResult {
  const FaceMatchResult({
    required this.candidate,
    required this.distance,
    required this.confidence,
    required this.isMatch,
    this.cosineSimilarity,
  });

  final Employee candidate;
  final double distance;
  final double confidence;
  final bool isMatch;
  final double? cosineSimilarity;
}

/// Service for mathematical biometric vector comparison and nearest-neighbor
/// matching for members.
class FaceMatchingService {
  /// Standard Euclidean distance threshold for MobileFaceNet normalized embeddings.
  /// Distance <= 0.75 indicates the exact same person.
  static const double defaultMatchThreshold = 0.75;

  /// Standard Cosine similarity threshold for hyperspherical face embeddings.
  /// Cosine similarity >= 0.72 indicates high biometric certainty.
  static const double defaultCosineThreshold = 0.72;

  /// Calculates Euclidean distance between two 192-dimension normalized embeddings.
  /// Returns 0.0 for identical vectors, ~1.414 for orthogonal vectors.
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

  /// Calculates Cosine similarity between two feature vectors.
  /// For L2-normalized vectors, this equals the dot product.
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

  /// Converts Euclidean distance to a calibrated confidence percentage (0% – 100%).
  /// A distance of 0.0 = 100% confidence.
  /// A distance equal to [threshold] (~0.75) = ~75% confidence.
  /// A distance >= 1.25 = 0% confidence.
  double distanceToConfidence(double distance, {double threshold = defaultMatchThreshold}) {
    if (distance <= 0.0) return 100.0;
    if (distance >= 1.25) return 0.0;

    final confidence = (1.0 - (distance / 1.25)) * 100.0;
    return confidence.clamp(0.0, 100.0);
  }

  /// Converts Cosine similarity to an intuitive confidence percentage (0% - 100%).
  /// Cosine 1.0 = 100%. Cosine 0.72 (threshold) = ~80%. Cosine <= 0.20 = 0%.
  double cosineToConfidence(double cosine) {
    if (cosine >= 1.0) return 100.0;
    if (cosine <= 0.20) return 0.0;
    final confidence = ((cosine - 0.20) / 0.80) * 100.0;
    return confidence.clamp(0.0, 100.0);
  }

  /// Scans a live [probeEmbedding] against a list of [candidates].
  /// Returns the closest matching [Employee] if distance <= [threshold].
  FaceMatchResult? findBestMatch({
    required List<double> probeEmbedding,
    required List<Employee> candidates,
    double threshold = defaultMatchThreshold,
  }) {
    Employee? bestCandidate;
    double minDistance = double.infinity;
    double secondMinDistance = double.infinity;
    double bestCosine = -1.0;

    for (final candidate in candidates) {
      final candidateEmbedding = candidate.faceEmbedding;
      if (candidateEmbedding == null || candidateEmbedding.isEmpty) {
        continue;
      }

      if (candidateEmbedding.length != probeEmbedding.length) {
        continue;
      }

      final distance = calculateEuclideanDistance(probeEmbedding, candidateEmbedding);
      if (distance < minDistance) {
        secondMinDistance = minDistance;
        minDistance = distance;
        bestCandidate = candidate;
      } else if (distance < secondMinDistance) {
        secondMinDistance = distance;
      }
    }

    if (bestCandidate == null) {
      return null;
    }

    if (bestCandidate.faceEmbedding != null) {
      bestCosine = calculateCosineSimilarity(
        probeEmbedding,
        bestCandidate.faceEmbedding!,
      );
    }

    // Require the nearest embedding to beat the runner-up, and to pass
    // both Euclidean (MobileFaceNet) and cosine checks.
    const minDistanceMargin = 0.12;
    const minCosine = 0.70;
    final isSeparated = secondMinDistance.isInfinite ||
        (secondMinDistance - minDistance) >= minDistanceMargin;
    final isMatch =
        minDistance <= threshold && bestCosine >= minCosine && isSeparated;
    final confidence = distanceToConfidence(minDistance, threshold: threshold);

    return FaceMatchResult(
      candidate: bestCandidate,
      distance: minDistance,
      confidence: double.parse(confidence.toStringAsFixed(1)),
      isMatch: isMatch,
      cosineSimilarity: bestCosine >= 0 ? double.parse(bestCosine.toStringAsFixed(3)) : null,
    );
  }
}
