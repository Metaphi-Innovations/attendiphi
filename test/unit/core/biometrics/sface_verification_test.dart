import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/biometrics/face_matching_config.dart';
import 'package:qr_checkin/core/biometrics/face_matching_service.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  late FaceMatchingService service;

  setUp(() {
    service = FaceMatchingService();
  });

  /// Helper to generate a synthetic L2-normalized 128-d SFace embedding vector
  List<double> createSFaceVector(double baseAngle, {double noise = 0.0}) {
    final list = List.generate(128, (i) {
      final angle = baseAngle + (i * 0.05);
      return sin(angle) + (noise * cos(i.toDouble()));
    });
    final normSq = list.fold<double>(0.0, (sum, v) => sum + v * v);
    final norm = sqrt(normSq);
    return list.map((v) => v / norm).toList();
  }

  group('SFace Cosine Similarity & Vector Math', () {
    test('Identical vectors produce Cosine similarity of 1.0', () {
      final vec = createSFaceVector(1.0);
      final sim = service.calculateCosineSimilarity(vec, vec);
      expect(sim, closeTo(1.0, 0.0001));
    });

    test('Orthogonal vectors produce Cosine similarity of 0.0', () {
      final vecA = [1.0, 0.0, 0.0, 0.0];
      final vecB = [0.0, 1.0, 0.0, 0.0];
      final sim = service.calculateCosineSimilarity(vecA, vecB);
      expect(sim, closeTo(0.0, 0.0001));
    });

    test('Opposite vectors produce Cosine similarity of -1.0', () {
      final vecA = [1.0, 0.0, 0.0];
      final vecB = [-1.0, 0.0, 0.0];
      final sim = service.calculateCosineSimilarity(vecA, vecB);
      expect(sim, closeTo(-1.0, 0.0001));
    });
  });

  group('Multi-Template Candidate Scoring', () {
    test('Candidate score is the maximum similarity across all enrolled templates', () {
      final t1 = createSFaceVector(1.0); // very different
      final t2 = createSFaceVector(2.5, noise: 0.02); // close to probe
      final t3 = createSFaceVector(4.0); // very different

      final probe = createSFaceVector(2.5);

      final candidate = Employee(
        id: 'emp_omkar',
        name: 'Omkar Anarse',
        faceTemplates: [t1, t2, t3],
      );

      final result = service.matchProbeAgainstCandidates(
        probeEmbedding: probe,
        candidates: [candidate],
      );

      expect(result.status, equals(FaceMatchStatus.match));
      expect(result.bestCandidate?.id, equals('emp_omkar'));
      expect(result.bestScore, greaterThan(0.95));
    });
  });

  group('Runner-Up Margin & Ambiguity Rejection', () {
    test('Accepts match when similarity >= 0.65 AND margin >= 0.10', () {
      final omkarTemplate = createSFaceVector(1.0);
      final otherTemplate = createSFaceVector(3.0); // significantly different
      final probe = createSFaceVector(1.0, noise: 0.02); // very close to Omkar

      final omkar = Employee(id: 'emp_omkar', name: 'Omkar', faceTemplates: [omkarTemplate]);
      final other = Employee(id: 'emp_other', name: 'Other', faceTemplates: [otherTemplate]);

      final result = service.matchProbeAgainstCandidates(
        probeEmbedding: probe,
        candidates: [omkar, other],
      );

      expect(result.status, equals(FaceMatchStatus.match));
      expect(result.bestCandidate?.id, equals('emp_omkar'));
      expect(result.margin, greaterThanOrEqualTo(FaceMatchingConfig.marginThreshold));
    });

    test('Rejects match as AMBIGUOUS when runner-up margin is below 0.10', () {
      // Candidate 1: Omkar
      final omkarTemplate = createSFaceVector(1.0);
      // Candidate 2: Very similar looking impostor or lighting condition
      final similarTemplate = createSFaceVector(1.0, noise: 0.04);

      final probe = createSFaceVector(1.0, noise: 0.02);

      final cand1 = Employee(id: 'emp_1', name: 'Omkar', faceTemplates: [omkarTemplate]);
      final cand2 = Employee(id: 'emp_2', name: 'Similar Face', faceTemplates: [similarTemplate]);

      final result = service.matchProbeAgainstCandidates(
        probeEmbedding: probe,
        candidates: [cand1, cand2],
        marginThreshold: 0.10,
      );

      expect(result.status, equals(FaceMatchStatus.ambiguous));
      expect(result.isMatch, isFalse);
      expect(result.isAmbiguous, isTrue);
      expect(result.margin, lessThan(0.10));
    });
  });

  group('Regression Test: Devendra Probe vs Omkar Candidate', () {
    test('Devendra probe NEVER matches Omkar candidate', () {
      // Create distinct biometric identities for Devendra and Omkar
      final omkarT1 = createSFaceVector(1.2);
      final omkarT2 = createSFaceVector(1.2, noise: 0.03);
      final omkarT3 = createSFaceVector(1.2, noise: 0.05);

      final devendraT1 = createSFaceVector(2.8);
      final devendraT2 = createSFaceVector(2.8, noise: 0.03);
      final devendraT3 = createSFaceVector(2.8, noise: 0.04);

      final omkar = Employee(
        id: 'emp_omkar',
        name: 'Omkar Anarse',
        faceTemplates: [omkarT1, omkarT2, omkarT3],
      );

      final devendra = Employee(
        id: 'emp_devendra',
        name: 'Devendra Patil',
        faceTemplates: [devendraT1, devendraT2, devendraT3],
      );

      final chapterMembers = [omkar, devendra];

      // 1. Devendra probe enters camera
      final devendraProbe = createSFaceVector(2.8, noise: 0.02);

      final result = service.matchProbeAgainstCandidates(
        probeEmbedding: devendraProbe,
        candidates: chapterMembers,
      );

      // Devendra probe must match Devendra, NEVER Omkar!
      expect(result.status, equals(FaceMatchStatus.match));
      expect(result.bestCandidate?.id, equals('emp_devendra'));
      expect(result.bestCandidate?.id, isNot(equals('emp_omkar')));
      expect(result.secondBestCandidate?.id, equals('emp_omkar'));
      expect(result.margin, greaterThan(FaceMatchingConfig.marginThreshold));

      // 2. Unenrolled / unknown person probe enters camera
      final unknownProbe = createSFaceVector(5.5);
      final unknownResult = service.matchProbeAgainstCandidates(
        probeEmbedding: unknownProbe,
        candidates: chapterMembers,
      );

      // Must be rejected as unknownPerson, NEVER matched to Omkar
      expect(unknownResult.status, equals(FaceMatchStatus.unknownPerson));
      expect(unknownResult.isMatch, isFalse);
    });
  });

  group('Multi-Frame Burst Aggregator', () {
    test('Decision verifies candidate when consistency >= 60% and margin is sound', () {
      final omkar = Employee(
        id: 'emp_omkar',
        name: 'Omkar Anarse',
        faceTemplates: [createSFaceVector(1.0)],
      );

      final frames = [
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: omkar,
          bestScore: 0.88,
          secondBestScore: 0.60,
          margin: 0.28,
        ),
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: omkar,
          bestScore: 0.86,
          secondBestScore: 0.62,
          margin: 0.24,
        ),
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: omkar,
          bestScore: 0.89,
          secondBestScore: 0.61,
          margin: 0.28,
        ),
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: omkar,
          bestScore: 0.85,
          secondBestScore: 0.58,
          margin: 0.27,
        ),
      ];

      final decision = service.evaluateMultiFrameDecision(
        frameMatches: frames,
        totalFramesCount: 5,
      );

      expect(decision.verified, isTrue);
      expect(decision.matchedMember?.id, equals('emp_omkar'));
      expect(decision.consistencyRate, equals(1.0));
      expect(decision.averageScore, greaterThan(0.85));
      expect(decision.averageMargin, greaterThan(0.20));
      expect(decision.shouldRetry, isFalse);
    });

    test('Decision requests retry when valid frames < minValidFrames', () {
      final decision = service.evaluateMultiFrameDecision(
        frameMatches: [], // 0 valid frames
        totalFramesCount: 5,
      );

      expect(decision.verified, isFalse);
      expect(decision.shouldRetry, isTrue);
      expect(decision.statusMessage, contains('Face quality insufficient'));
    });

    test('Decision requests retry when frames are inconsistent (< 60%)', () {
      const omkar = Employee(id: 'emp_1', name: 'Omkar');
      const personB = Employee(id: 'emp_2', name: 'Person B');

      const frames = [
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: omkar,
          bestScore: 0.70,
          margin: 0.15,
        ),
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: personB,
          bestScore: 0.71,
          margin: 0.15,
        ),
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: omkar,
          bestScore: 0.69,
          margin: 0.12,
        ),
        SingleFrameMatchResult(
          status: FaceMatchStatus.match,
          bestCandidate: personB,
          bestScore: 0.72,
          margin: 0.14,
        ),
      ];

      final decision = service.evaluateMultiFrameDecision(
        frameMatches: frames,
        totalFramesCount: 5,
        consistencyThreshold: 0.60,
      );

      expect(decision.verified, isFalse);
      expect(decision.shouldRetry, isTrue);
      expect(decision.statusMessage, contains('inconsistent across frames'));
    });
  });

  group('Enrollment Consistency Validation', () {
    test('Validates 3–5 consistent templates from the same face (similarity >= 0.75)', () {
      final t1 = createSFaceVector(1.0);
      final t2 = createSFaceVector(1.0, noise: 0.02);
      final t3 = createSFaceVector(1.0, noise: 0.03);
      final t4 = createSFaceVector(1.0, noise: 0.01);

      final isValid = service.validateEnrollmentConsistency([t1, t2, t3, t4]);
      expect(isValid, isTrue);
    });

    test('Rejects enrollment templates with pairwise divergence (< 0.75)', () {
      final t1 = createSFaceVector(1.0);
      final t2 = createSFaceVector(1.0, noise: 0.02);
      final tDifferent = createSFaceVector(3.5); // completely different person/pose

      final isValid = service.validateEnrollmentConsistency([t1, t2, tDifferent]);
      expect(isValid, isFalse);
    });
  });
}
