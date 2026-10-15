import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'cloud_face_recognition_service.dart';
import 'face_detector_service.dart';
import 'face_embedding_service.dart';
import 'face_enrollment_helper.dart';
import 'face_matching_service.dart';
import 'face_verification_service.dart';

/// Provider for [FaceDetectorService].
final faceDetectorServiceProvider = Provider<FaceDetectorService>((ref) {
  final service = FaceDetectorService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for [FaceEmbeddingService].
final faceEmbeddingServiceProvider = Provider<FaceEmbeddingService>((ref) {
  final service = FaceEmbeddingService();
  ref.onDispose(service.dispose);
  return service;
});

/// Provider for [FaceMatchingService].
final faceMatchingServiceProvider = Provider<FaceMatchingService>((ref) {
  return FaceMatchingService();
});

/// Provider for [CloudFaceRecognitionService] (used primarily on Web).
final cloudFaceRecognitionServiceProvider =
    Provider<CloudFaceRecognitionService>((ref) {
      final matchingService = ref.watch(faceMatchingServiceProvider);
      final service = CloudFaceRecognitionService(
        matchingService: matchingService,
      );
      ref.onDispose(service.dispose);
      return service;
    });

/// Provider for the abstract [FaceVerificationService].
final faceVerificationServiceProvider = Provider<FaceVerificationService>((
  ref,
) {
  return ref.watch(cloudFaceRecognitionServiceProvider);
});

/// Provider for [FaceEnrollmentHelper].
final faceEnrollmentHelperProvider = Provider<FaceEnrollmentHelper>((ref) {
  final detector = ref.watch(faceDetectorServiceProvider);
  final embedding = ref.watch(faceEmbeddingServiceProvider);
  return FaceEnrollmentHelper(
    detectorService: detector,
    embeddingService: embedding,
  );
});
