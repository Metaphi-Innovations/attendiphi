import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/biometrics/face_matching_service.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  late FaceMatchingService service;

  setUp(() {
    service = FaceMatchingService();
  });

  List<double> createMockEmbedding(double seed) {
    final list = List.generate(192, (i) => sin(seed + i));
    final norm = sqrt(list.fold<double>(0.0, (sum, val) => sum + val * val));
    return list.map((val) => val / norm).toList();
  }

  group('FaceMatchingService', () {
    test('Identical embeddings have 0.0 distance and 100% confidence', () {
      final emb = createMockEmbedding(1.0);
      final distance = service.calculateEuclideanDistance(emb, emb);
      final confidence = service.distanceToConfidence(distance);

      expect(distance, closeTo(0.0, 0.0001));
      expect(confidence, equals(100.0));
    });

    test('Throws ArgumentError when embedding lengths do not match', () {
      final emb1 = [1.0, 2.0, 3.0];
      final emb2 = [1.0, 2.0];

      expect(
        () => service.calculateEuclideanDistance(emb1, emb2),
        throwsArgumentError,
      );
    });

    test('findBestMatch returns correct member when match exists', () {
      final probe = createMockEmbedding(5.0);
      // Create a candidate with nearly identical embedding (slight noise)
      final matchedEmbedding = List<double>.from(probe);
      matchedEmbedding[0] += 0.01;

      final candidates = [
        Employee(
          id: 'emp_1',
          name: 'Alice Wonder',
          phone: '9876543210',
          faceEmbedding: createMockEmbedding(1.0),
        ),
        Employee(
          id: 'emp_2',
          name: 'Bob Builder',
          phone: '9876543211',
          faceEmbedding: matchedEmbedding,
        ),
        const Employee(
          id: 'emp_3',
          name: 'Charlie Brown',
          phone: '9876543212',
          faceEmbedding: null, // No face enrolled
        ),
      ];

      final result = service.findBestMatch(
        probeEmbedding: probe,
        candidates: candidates,
        threshold: 0.75,
      );

      expect(result, isNotNull);
      expect(result!.candidate.id, equals('emp_2'));
      expect(result.candidate.name, equals('Bob Builder'));
      expect(result.isMatch, isTrue);
      expect(result.confidence, greaterThan(90.0));
    });

    test('findBestMatch returns isMatch = false when distance exceeds threshold', () {
      final probe = createMockEmbedding(10.0);
      final candidateEmb = createMockEmbedding(20.0);

      final candidates = [
        Employee(
          id: 'emp_1',
          name: 'David Miller',
          phone: '9876543210',
          faceEmbedding: candidateEmb,
        ),
      ];

      final result = service.findBestMatch(
        probeEmbedding: probe,
        candidates: candidates,
        threshold: 0.20, // Very strict threshold
      );

      expect(result, isNotNull);
      expect(result!.isMatch, isFalse);
    });

    test('findBestMatch returns null when no candidate has an embedding', () {
      final probe = createMockEmbedding(1.0);
      final candidates = [
        const Employee(id: 'emp_1', name: 'No Face 1'),
        const Employee(id: 'emp_2', name: 'No Face 2', faceEmbedding: []),
      ];

      final result = service.findBestMatch(
        probeEmbedding: probe,
        candidates: candidates,
      );

      expect(result, isNull);
    });
  });
}
