import 'dart:math';
import '../../features/employee/domain/entities/employee.dart';

/// Result of matching a live face against enrolled member database.
class FaceMatchResult {
  const FaceMatchResult({
    required this.candidate,
    required this.distance,
    required this.confidence,
    required this.isMatch,
  });

  final Employee candidate;
  final double distance;
  final double confidence;
  final bool isMatch;
}

/// Service for mathematical biometric vector comparison and nearest-neighbor
/// matching for members.
class FaceMatchingService {
  /// Standard Euclidean distance threshold for MobileFaceNet normalized embeddings.
  /// Distance <= 0.75 indicates the exact same person.
  static const double defaultMatchThreshold = 0.75;

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

  /// Converts Euclidean distance to a user-friendly confidence percentage (0% – 100%).
  /// A distance of 0.0 = 100% confidence.
  /// A distance equal to [threshold] (~0.75) = ~75% confidence.
  /// A distance >= 1.25 = 0% confidence.
  double distanceToConfidence(double distance, {double threshold = defaultMatchThreshold}) {
    if (distance <= 0.0) return 100.0;
    if (distance >= 1.25) return 0.0;

    // Linear mapping with threshold anchor
    final confidence = (1.0 - (distance / 1.25)) * 100.0;
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
        minDistance = distance;
        bestCandidate = candidate;
      }
    }

    if (bestCandidate == null) {
      return null;
    }

    final isMatch = minDistance <= threshold;
    final confidence = distanceToConfidence(minDistance, threshold: threshold);

    return FaceMatchResult(
      candidate: bestCandidate,
      distance: minDistance,
      confidence: double.parse(confidence.toStringAsFixed(1)),
      isMatch: isMatch,
    );
  }
}
