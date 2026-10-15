import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/biometrics/cloud_face_recognition_service.dart';
import 'package:qr_checkin/core/biometrics/face_matching_config.dart';
import 'package:qr_checkin/core/biometrics/web_face_embedder.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  group('CloudFaceRecognitionService (SFace Client-Side Architecture)', () {
    // Helper to generate normalized 128-d SFace embedding with single active dimension
    List<double> createMockVector(int activeIndex) {
      final list = List.filled(128, 0.0);
      list[activeIndex % 128] = 1.0;
      return list;
    }

    final candidate1 = Employee(
      id: 'emp_101',
      name: 'Omkar Anarse',
      phone: '9876543210',
      faceTemplates: [createMockVector(0)],
    );

    final candidate2 = Employee(
      id: 'emp_102',
      name: 'Devendra Patil',
      phone: '9876543211',
      faceTemplates: [createMockVector(1)],
    );

    final candidate3 = Employee(
      id: 'emp_103',
      name: 'Rinku Saroj',
      phone: '9876543212',
      faceTemplates: [createMockVector(2)],
    );

    final candidates = [candidate1, candidate2, candidate3];

    test('Rejects match when candidate list is empty', () async {
      final service = CloudFaceRecognitionService();

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: [],
      );

      expect(result.isMatch, isFalse);
      expect(result.matchedMember, isNull);
    });

    test(
      'Returns isMatch = false when candidates have no face embeddings',
      () async {
        final service = CloudFaceRecognitionService();
        const memberWithoutEmbedding = Employee(
          id: 'emp_999',
          name: 'No Biometric',
          phone: '1234567890',
        );

        final result = await service.matchFace(
          photoBase64: 'mock_base64_data',
          candidates: [memberWithoutEmbedding],
        );

        expect(result.isMatch, isFalse);
        expect(
          result.errorMessage,
          contains('No enrolled member face profiles found'),
        );
      },
    );

    test('Rejects automatic match when multiple faces are detected', () async {
      final service = CloudFaceRecognitionService(
        frameExtractor: (_) async => const ValidatedFaceFrame(
          isValid: false,
          faceCount: 2,
          errorMessage:
              'Please ensure only one person is in front of the camera.',
        ),
      );

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: candidates,
      );

      expect(result.isMatch, isFalse);
      expect(result.errorMessage, contains('only one person'));
    });

    test('Handles invalid frame / no face detected gracefully', () async {
      final service = CloudFaceRecognitionService(
        frameExtractor: (_) async => const ValidatedFaceFrame(
          isValid: false,
          errorMessage: 'No face detected in viewfinder.',
        ),
      );

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: candidates,
      );

      expect(result.isMatch, isFalse);
      expect(result.errorMessage, contains('No face detected'));
    });

    test(
      'Successfully recognizes member with high SFace similarity and margin',
      () async {
        final targetEmb = createMockVector(0);

        final service = CloudFaceRecognitionService(
          frameExtractor: (_) async =>
              ValidatedFaceFrame(isValid: true, embedding: targetEmb),
        );

        final result = await service.matchFace(
          photoBase64: 'mock_base64_data',
          candidates: candidates,
        );

        expect(result.isMatch, isTrue);
        expect(result.matchedMember?.id, equals('emp_101'));
        expect(result.matchedMember?.name, equals('Omkar Anarse'));
        expect(result.confidence, equals(100.0));
      },
    );

    test('Skips native-only 192-d enrollments on the web matcher', () async {
      final nativeOnly = Employee(
        id: 'emp_native',
        name: 'Native Enroll',
        faceTemplates: [List<double>.filled(192, 0.01)],
      );
      final service = CloudFaceRecognitionService(
        frameExtractor: (_) async =>
            ValidatedFaceFrame(isValid: true, embedding: createMockVector(0)),
      );

      final result = await service.matchFace(
        photoBase64: 'mock_base64_data',
        candidates: [nativeOnly],
      );

      expect(result.isMatch, isFalse);
      expect(result.errorMessage, contains('web face enrollment'));
    });

    test(
      'Flags ambiguous match when runner-up margin is below threshold',
      () async {
        // Two candidates with almost identical embeddings
        final closeEmb1 = createMockVector(0);
        final closeEmb2 = List<double>.from(closeEmb1);
        closeEmb2[1] = 0.02; // tiny difference

        final closeCandidates = [
          Employee(id: 'emp_a', name: 'Member A', faceTemplates: [closeEmb1]),
          Employee(id: 'emp_b', name: 'Member B', faceTemplates: [closeEmb2]),
        ];

        final service = CloudFaceRecognitionService(
          frameExtractor: (_) async =>
              ValidatedFaceFrame(isValid: true, embedding: closeEmb1),
        );

        final result = await service.matchFace(
          photoBase64: 'mock_base64_data',
          candidates: closeCandidates,
        );

        expect(result.isMatch, isFalse);
        expect(result.isAmbiguous, isTrue);
        expect(result.errorMessage, contains('Face match ambiguous'));
      },
    );

    test(
      'Multi-frame burst verifies member when frames are consistent',
      () async {
        final targetEmb = createMockVector(0);

        final service = CloudFaceRecognitionService(
          frameExtractor: (_) async =>
              ValidatedFaceFrame(isValid: true, embedding: targetEmb),
        );

        final decision = await service.matchMultiFrameBurst(
          photosBase64: ['f1', 'f2', 'f3', 'f4', 'f5'],
          candidates: candidates,
        );

        expect(decision.verified, isTrue);
        expect(decision.matchedMember?.id, equals('emp_101'));
        expect(decision.consistencyRate, equals(1.0));
        expect(
          decision.validFramesCount,
          greaterThanOrEqualTo(FaceMatchingConfig.minimumValidFrames),
        );
      },
    );

    test('Multi-frame burst stops once enough frames already verify', () async {
      var extractCount = 0;
      final targetEmb = createMockVector(0);
      final service = CloudFaceRecognitionService(
        frameExtractor: (_) async {
          extractCount++;
          return ValidatedFaceFrame(isValid: true, embedding: targetEmb);
        },
      );

      final decision = await service.matchMultiFrameBurst(
        photosBase64: ['f1', 'f2', 'f3', 'f4', 'f5'],
        candidates: candidates,
      );

      expect(decision.verified, isTrue);
      expect(extractCount, equals(FaceMatchingConfig.minimumValidFrames));
    });

    test(
      'Multi-frame burst rejects when inconsistent or poor quality',
      () async {
        int frameIndex = 0;
        final service = CloudFaceRecognitionService(
          frameExtractor: (_) async {
            frameIndex++;
            // Alternate between candidate 1, candidate 2, and candidate 3
            return ValidatedFaceFrame(
              isValid: true,
              embedding: createMockVector(frameIndex % 3),
            );
          },
        );

        final decision = await service.matchMultiFrameBurst(
          photosBase64: ['f1', 'f2', 'f3', 'f4', 'f5'],
          candidates: candidates,
        );

        expect(decision.verified, isFalse);
        expect(decision.shouldRetry, isTrue);
        expect(decision.consistencyRate, lessThan(0.60));
      },
    );
  });
}
