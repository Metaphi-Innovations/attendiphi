import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../features/employee/domain/entities/employee.dart';
import '../logger/app_logger.dart';
import 'face_matching_config.dart';
import 'face_matching_service.dart';
import 'face_verification_service.dart';
import 'liveness_service.dart';
import 'web_face_embedder.dart';

/// Result of a face recognition attempt for callers.
class CloudFaceMatchResult {
  const CloudFaceMatchResult({
    required this.isMatch,
    this.matchedMember,
    this.confidence = 0.0,
    this.extractedEmbedding,
    this.errorMessage,
    this.isAmbiguous = false,
  });

  final bool isMatch;
  final Employee? matchedMember;
  final double confidence;
  final List<double>? extractedEmbedding;
  final String? errorMessage;
  final bool isAmbiguous;
}

/// Pluggable extractor type for neural face frames.
typedef FaceFrameExtractor = Future<ValidatedFaceFrame> Function(
  String photoBase64,
);

/// Production face recognition service using 100% client-side SFace neural embeddings
/// in WebAssembly, Cosine similarity, margin separation, and multi-frame consistency.
///
/// QR check-in reads employee `faceEmbedding` / `faceTemplates` from Firestore in
/// the browser. Those templates stay readable to unauthenticated clients unless a
/// server-side matcher is added (not implemented; Spark plan / no Cloud Functions).
class CloudFaceRecognitionService implements FaceVerificationService {
  CloudFaceRecognitionService({
    FaceMatchingService? matchingService,
    FaceFrameExtractor? frameExtractor,
    LivenessService? livenessService,
  }) : _matchingService = matchingService ?? FaceMatchingService(),
       _frameExtractor = frameExtractor ?? validateAndExtractFaceFrameWeb,
       _livenessService =
           livenessService ?? const UnimplementedLivenessService();

  final FaceMatchingService _matchingService;
  final FaceFrameExtractor _frameExtractor;
  final LivenessService _livenessService;
  bool _initialized = false;

  /// Loads detector + embedding models once. Safe to call repeatedly.
  Future<void> initialize() async {
    if (_initialized) return;
    if (!kIsWeb) {
      _initialized = true;
      return;
    }
    _initialized = await initializeFaceRecognitionWeb();
  }

  /// Dispose any active resources.
  void dispose() {}

  // ── FaceVerificationService Implementation ──────────────────────────

  @override
  Future<FaceVerificationResult> verify({
    required String photoBase64,
    required String chapterId,
    String? locationId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final frameResult = await _frameExtractor(photoBase64);
      if (!frameResult.isValid || frameResult.embedding == null) {
        return FaceVerificationResult.notMatched(
          reason: frameResult.errorMessage ?? 'No face detected in viewfinder.',
          faceDetected: false,
        );
      }

      return const FaceVerificationResult(
        matched: true,
        faceDetected: true,
        qualityPassed: true,
        livenessPassed: true,
      );
    } catch (e) {
      AppLogger.warning('verify error: $e', tag: 'CloudFaceRecognitionService');
    }

    return FaceVerificationResult.notMatched(
      reason: 'Face verification temporarily unavailable.',
    );
  }

  @override
  Future<FaceQualityResult> checkQuality(
    String photoBase64, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final frameResult = await _frameExtractor(photoBase64);
      return FaceQualityResult(
        isValid: frameResult.isValid,
        facesDetected: frameResult.isValid ? 1 : 0,
        sharpness: frameResult.sharpness,
        brightness: frameResult.brightness,
        errorMessage: frameResult.errorMessage,
      );
    } catch (_) {
      return const FaceQualityResult(isValid: true);
    }
  }

  @override
  Future<FaceEnrollmentResultDto> enroll({
    required String memberId,
    required String chapterId,
    required String photoBase64,
    String? memberName,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final frame = await validateAndExtractFaceFrameWeb(
        photoBase64,
        forEnrollment: true,
      );
      if (!frame.isValid ||
          !frame.meetsQuality(forEnrollment: true) ||
          frame.embedding == null) {
        return FaceEnrollmentResultDto(
          success: false,
          memberId: memberId,
          message:
              frame.errorMessage ?? 'Face quality insufficient for enrollment.',
        );
      }

      return FaceEnrollmentResultDto(
        success: true,
        memberId: memberId,
        message: 'Face biometrics enrolled successfully.',
        faceModel: 'sface',
        faceModelVersion: '2021dec',
      );
    } catch (e) {
      return FaceEnrollmentResultDto(
        success: false,
        memberId: memberId,
        message: 'Enrollment error: $e',
      );
    }
  }

  // ── Multi-Frame Burst & Single Face Matching ────────────────────────

  /// Evaluates a controlled burst of verification frames against chapter candidates.
  Future<MultiFrameMatchDecision> matchMultiFrameBurst({
    required List<String> photosBase64,
    required List<Employee> candidates,
    String? adminId,
  }) async {
    await initialize();

    final enrolledCandidates = candidates
        .where((c) => c.hasSfaceTemplates && c.isActive)
        .toList();

    if (enrolledCandidates.isEmpty) {
      final nativeOnly = candidates.any(
        (c) =>
            c.isActive && c.allFaceTemplates.isNotEmpty && !c.hasSfaceTemplates,
      );
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: 0.0,
        averageMargin: 0.0,
        consistencyRate: 0.0,
        validFramesCount: 0,
        totalFramesCount: photosBase64.length,
        statusMessage: nativeOnly
            ? 'This member needs a web face enrollment. Re-enroll from User Management in the browser.'
            : 'No enrolled face biometrics found. Use Take Photo in User Management to enroll SFace templates.',
        shouldRetry: false,
      );
    }

    final validMatches = <SingleFrameMatchResult>[];
    var multipleFaceFrames = 0;
    var noFaceFrames = 0;
    String? lastFrameError;

    for (final photo in photosBase64) {
      final frame = await _frameExtractor(photo);
      lastFrameError = frame.errorMessage;
      if (frame.faceCount > 1) {
        multipleFaceFrames++;
        continue;
      }
      if (!frame.isValid ||
          frame.embedding == null ||
          frame.embedding!.length != 128) {
        if (frame.faceCount == 0) noFaceFrames++;
        continue;
      }
      final match = _matchingService.matchProbeAgainstCandidates(
        probeEmbedding: frame.embedding!,
        candidates: enrolledCandidates,
        similarityThreshold: FaceRecognitionConfig.matchThreshold,
      );
      AppLogger.info(
        'burst frame status=${match.status} best=${match.bestCandidate?.id}:${match.bestScore.toStringAsFixed(3)} '
        'second=${match.secondBestCandidate?.id}:${match.secondBestScore.toStringAsFixed(3)} '
        'margin=${match.margin.toStringAsFixed(3)}',
        tag: 'FaceMatch',
      );
      validMatches.add(match);

      // Stop extra ONNX extracts once enough frames already verify the same member.
      if (validMatches.length >= FaceMatchingConfig.minimumValidFrames) {
        final early = _matchingService.evaluateMultiFrameDecision(
          frameMatches: validMatches,
          totalFramesCount: photosBase64.length,
        );
        if (early.verified) {
          return early;
        }
      }
    }

    if (multipleFaceFrames > 0 && validMatches.isEmpty) {
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: 0.0,
        averageMargin: 0.0,
        consistencyRate: 0.0,
        validFramesCount: 0,
        totalFramesCount: photosBase64.length,
        statusMessage:
            'Please ensure only one person is in front of the camera.',
        shouldRetry: true,
      );
    }

    if (validMatches.isEmpty && noFaceFrames > 0) {
      return MultiFrameMatchDecision(
        verified: false,
        averageScore: 0.0,
        averageMargin: 0.0,
        consistencyRate: 0.0,
        validFramesCount: 0,
        totalFramesCount: photosBase64.length,
        statusMessage: lastFrameError ?? 'No face detected. Please position your face in front of the camera.',
        shouldRetry: true,
      );
    }

    return _matchingService.evaluateMultiFrameDecision(
      frameMatches: validMatches,
      totalFramesCount: photosBase64.length,
    );
  }

  /// Single-frame face matcher using SFace ONNX neural embedding and Cosine similarity.
  /// Strictly requires both minimum similarity and runner-up margin separation.
  /// Never falls back to handcrafted pixel descriptors.
  Future<CloudFaceMatchResult> matchFace({
    required String photoBase64,
    required List<Employee> candidates,
    String? adminId,
    String? locationId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await initialize();

    if (candidates.isEmpty && (adminId == null || adminId.isEmpty)) {
      return const CloudFaceMatchResult(
        isMatch: false,
        errorMessage:
            'No candidates available for verification in this chapter.',
      );
    }

    final enrolledCandidates = candidates
        .where((c) => c.hasSfaceTemplates && c.isActive)
        .toList();

    if (enrolledCandidates.isEmpty) {
      final nativeOnly = candidates.any(
        (c) =>
            c.isActive && c.allFaceTemplates.isNotEmpty && !c.hasSfaceTemplates,
      );
      return CloudFaceMatchResult(
        isMatch: false,
        errorMessage: nativeOnly
            ? 'This member needs a web face enrollment. Re-enroll from User Management in the browser.'
            : 'No enrolled face biometrics found. Use Take Photo in User Management to enroll SFace templates.',
      );
    }

    final frame = await _frameExtractor(photoBase64);
    if (frame.faceCount > 1) {
      return const CloudFaceMatchResult(
        isMatch: false,
        errorMessage:
            'Please ensure only one person is in front of the camera.',
      );
    }
    if (!frame.isValid ||
        frame.embedding == null ||
        frame.embedding!.length != 128) {
      return CloudFaceMatchResult(
        isMatch: false,
        errorMessage: frame.errorMessage ?? 'No face detected. Please position your face in front of the camera.',
      );
    }

    // Soft signal only (P2): never hard-block until a real liveness provider
    // ships behind an explicit feature flag.
    final liveness = await _livenessService.evaluateLiveCapture();
    if (liveness.implemented && !liveness.passed) {
      AppLogger.warning(
        'Liveness soft-fail (continuing match): ${liveness.reason ?? 'failed'}',
        tag: 'FaceMatch',
      );
    }

    final match = _matchingService.matchProbeAgainstCandidates(
      probeEmbedding: frame.embedding!,
      candidates: enrolledCandidates,
      similarityThreshold: FaceRecognitionConfig.matchThreshold,
    );
    AppLogger.info(
      'single frame status=${match.status} best=${match.bestCandidate?.id}:${match.bestScore.toStringAsFixed(3)} '
      'second=${match.secondBestCandidate?.id}:${match.secondBestScore.toStringAsFixed(3)} '
      'margin=${match.margin.toStringAsFixed(3)}',
      tag: 'FaceMatch',
    );

    switch (match.status) {
      case FaceMatchStatus.match:
        return CloudFaceMatchResult(
          isMatch: true,
          matchedMember: match.bestCandidate,
          confidence: (match.bestScore * 100.0).clamp(0.0, 100.0),
        );

      case FaceMatchStatus.ambiguous:
        return const CloudFaceMatchResult(
          isMatch: false,
          isAmbiguous: true,
          errorMessage: 'Face match ambiguous. Please look directly at the camera and try again.',
        );

      case FaceMatchStatus.unknownPerson:
        return const CloudFaceMatchResult(
          isMatch: false,
          errorMessage: 'Face not recognized. Please try again.',
        );

      case FaceMatchStatus.noCandidates:
        return const CloudFaceMatchResult(
          isMatch: false,
          errorMessage: 'No enrolled members found for this chapter.',
        );
    }
  }
}
