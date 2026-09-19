import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../features/employee/domain/entities/employee.dart';
import '../logger/app_logger.dart';
import '../utils/image_utils.dart';
import 'face_matching_service.dart';
import 'face_verification_service.dart';
import 'local_face_descriptor.dart';
import 'web_face_embedder.dart';

/// Result of a face recognition attempt for backwards-compatible callers.
class CloudFaceMatchResult {
  const CloudFaceMatchResult({
    required this.isMatch,
    this.matchedMember,
    this.confidence = 0.0,
    this.extractedEmbedding,
    this.errorMessage,
  });

  final bool isMatch;
  final Employee? matchedMember;
  final double confidence;
  final List<double>? extractedEmbedding;
  final String? errorMessage;
}

/// Production face recognition service communicating with the FastAPI
/// neural ArcFace/SFace verification microservice and providing fallbacks.
class CloudFaceRecognitionService implements FaceVerificationService {
  CloudFaceRecognitionService({
    FaceMatchingService? matchingService,
    http.Client? httpClient,
    String? apiBaseUrl,
    String? legacyFunctionUrl,
  })  : _matchingService = matchingService ?? FaceMatchingService(),
        _httpClient = httpClient ?? http.Client(),
        _apiBaseUrl = apiBaseUrl ?? _resolveDefaultApiUrl(),
        _legacyFunctionUrl = legacyFunctionUrl ??
            'https://us-central1-qr-checkin-dev.cloudfunctions.net/matchMemberFace';

  final FaceMatchingService _matchingService;
  final http.Client _httpClient;
  final String _apiBaseUrl;
  final String _legacyFunctionUrl;

  static String _resolveDefaultApiUrl() {
    const definedUrl = String.fromEnvironment('FACE_API_URL');
    if (definedUrl.isNotEmpty) return definedUrl;
    // Do not default to localhost: production check-in runs in the browser
    // and would call the member's phone, then fail every selfie.
    return '';
  }

  // ── FaceVerificationService Implementation ──────────────────────────

  @override
  Future<FaceVerificationResult> verify({
    required String photoBase64,
    required String chapterId,
    String? locationId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/face/verify');
      final payload = {
        'photo_base64': photoBase64,
        'chapter_id': chapterId,
        'location_id': ?locationId,
      };

      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final bool matched = data['matched'] == true;
        final String? memberId =
            data['member_id']?.toString() ?? data['memberId']?.toString();
        final String? memberName = data['member_name']?.toString();
        final double? confidence = (data['confidence'] as num?)?.toDouble();
        final double? similarity = (data['similarity'] as num?)?.toDouble();
        final double? margin = (data['margin'] as num?)?.toDouble();
        final String? reason = data['reason']?.toString();
        final bool faceDetected = data['face_detected'] != false;
        final bool qualityPassed = data['quality_passed'] != false;
        final bool livenessPassed = data['liveness_passed'] != false;
        final int evaluated = (data['candidates_evaluated'] as num?)?.toInt() ?? 0;

        return FaceVerificationResult(
          matched: matched,
          memberId: memberId,
          memberName: memberName,
          confidence: confidence,
          similarity: similarity,
          margin: margin,
          reason: _mapReasonToUserMessage(reason),
          faceDetected: faceDetected,
          qualityPassed: qualityPassed,
          livenessPassed: livenessPassed,
          candidatesEvaluated: evaluated,
        );
      }
    } catch (e) {
      AppLogger.warning('Face API verify request failed: $e', tag: 'CloudFaceRecognitionService');
    }

    return FaceVerificationResult.notMatched(
      reason: 'Face verification service temporarily unavailable.',
    );
  }

  @override
  Future<FaceQualityResult> checkQuality(
    String photoBase64, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final uri = Uri.parse('$_apiBaseUrl/face/quality');
      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'photo_base64': photoBase64}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FaceQualityResult(
          isValid: data['is_valid'] == true,
          facesDetected: (data['faces_detected'] as num?)?.toInt() ?? 0,
          sharpness: (data['sharpness'] as num?)?.toDouble() ?? 0.0,
          brightness: (data['brightness'] as num?)?.toDouble() ?? 0.0,
          yaw: (data['yaw'] as num?)?.toDouble() ?? 0.0,
          roll: (data['roll'] as num?)?.toDouble() ?? 0.0,
          errorMessage: data['error_message']?.toString(),
        );
      }
    } catch (_) {}

    return const FaceQualityResult(isValid: true);
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
      final uri = Uri.parse('$_apiBaseUrl/face/enroll');
      final payload = {
        'member_id': memberId,
        'chapter_id': chapterId,
        'photo_base64': photoBase64,
        'member_name': ?memberName,
      };

      final response = await _httpClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return FaceEnrollmentResultDto(
          success: data['success'] == true,
          memberId: memberId,
          message: data['message']?.toString() ?? 'Biometrics enrolled successfully.',
          faceModel: data['face_model']?.toString(),
          faceModelVersion: data['face_model_version']?.toString(),
        );
      } else {
        final errorData = jsonDecode(response.body);
        final detail = errorData is Map ? errorData['detail']?.toString() : null;
        return FaceEnrollmentResultDto(
          success: false,
          memberId: memberId,
          message: detail ?? 'Failed to enroll face biometrics (${response.statusCode}).',
        );
      }
    } catch (e) {
      return FaceEnrollmentResultDto(
        success: false,
        memberId: memberId,
        message: 'Enrollment network error: $e',
      );
    }
  }

  // ── Backwards Compatible `matchFace` Method ────────────────────────

  /// Matches a captured selfie against [candidates].
  /// Prioritizes the neural Face Verification API; gracefully falls back
  /// to local 192-d vectors or legacy Cloud Function when necessary.
  Future<CloudFaceMatchResult> matchFace({
    required String photoBase64,
    required List<Employee> candidates,
    String? adminId,
    String? locationId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    if (candidates.isEmpty && (adminId == null || adminId.isEmpty)) {
      return const CloudFaceMatchResult(
        isMatch: false,
        errorMessage: 'No candidates available for verification in this chapter.',
      );
    }

    final activeChapterId = adminId ??
        candidates.where((c) => c.adminId != null).firstOrNull?.adminId ??
        '';

    // 1. Neural Face API — only when a real host is configured.
    // Production web builds default to 127.0.0.1, which is the member's
    // phone, not the server. Skip that so check-in can use roster photos.
    if (_isRemoteApiReachable) {
      try {
        final verifyResult = await verify(
          photoBase64: photoBase64,
          chapterId: activeChapterId,
          locationId: locationId,
          timeout: timeout,
        );

        if (verifyResult.matched && verifyResult.memberId != null) {
          Employee? matched = candidates
              .where((c) => c.id == verifyResult.memberId)
              .firstOrNull;

          matched ??= Employee(
            id: verifyResult.memberId!,
            name: verifyResult.memberName ?? 'Enrolled Member',
            adminId: activeChapterId,
            isActive: true,
          );

          return CloudFaceMatchResult(
            isMatch: true,
            matchedMember: matched,
            confidence: verifyResult.confidence ?? 95.0,
          );
        } else if (!verifyResult.faceDetected) {
          return CloudFaceMatchResult(
            isMatch: false,
            errorMessage: verifyResult.reason ??
                'No face detected. Please look directly at the camera.',
          );
        } else if (!verifyResult.livenessPassed) {
          return CloudFaceMatchResult(
            isMatch: false,
            errorMessage:
                verifyResult.reason ?? 'Face authenticity check failed.',
          );
        }
      } catch (e) {
        AppLogger.warning(
          'Face API unavailable, using on-device photo match: $e',
          tag: 'CloudFaceRecognitionService',
        );
      }
    }

    // 2. Candidates with enrolled biometric vectors (Native MobileFaceNet or SFace)
    final enrolledCandidates = candidates
        .where((c) => c.faceEmbedding != null && c.faceEmbedding!.isNotEmpty && c.isActive)
        .toList();

    if (enrolledCandidates.isNotEmpty) {
      // 2a. Attempt client-side web neural embedding extraction if running in browser
      try {
        final webEmbedding = await extractFaceEmbeddingWeb(photoBase64);
        if (webEmbedding != null && webEmbedding.isNotEmpty) {
          final localMatch = _matchingService.findBestMatch(
            probeEmbedding: webEmbedding,
            candidates: enrolledCandidates,
            threshold: 0.78,
          );

          if (localMatch != null && localMatch.isMatch) {
            return CloudFaceMatchResult(
              isMatch: true,
              matchedMember: localMatch.candidate,
              confidence: localMatch.confidence,
              extractedEmbedding: webEmbedding,
            );
          }
        }
      } catch (e) {
        AppLogger.warning('Client-side web embedding error: $e', tag: 'CloudFaceRecognitionService');
      }

      // 2b. Attempt legacy Cloud Function if available
      try {
        final payload = {
          'photoBase64': photoBase64,
          'adminId': adminId,
          'locationId': locationId,
          'candidates': enrolledCandidates.map((c) => {
            'id': c.id,
            'name': c.name,
            'faceEmbedding': c.faceEmbedding,
          }).toList(),
        };

        final response = await _httpClient
            .post(
              Uri.parse(_legacyFunctionUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final bool matched = data['matched'] == true;
          final String? matchedId = data['memberId']?.toString();
          final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;

          if (matched && matchedId != null) {
            final found = enrolledCandidates.where((c) => c.id == matchedId).firstOrNull;
            if (found != null) {
              return CloudFaceMatchResult(
                isMatch: true,
                matchedMember: found,
                confidence: confidence,
              );
            }
          }

          if (data['embedding'] is List) {
            final List<double> probeEmbedding = (data['embedding'] as List)
                .map((e) => (e as num).toDouble())
                .toList();

            final localMatch = _matchingService.findBestMatch(
              probeEmbedding: probeEmbedding,
              candidates: enrolledCandidates,
              threshold: 0.78,
            );

            if (localMatch != null && localMatch.isMatch) {
              return CloudFaceMatchResult(
                isMatch: true,
                matchedMember: localMatch.candidate,
                confidence: localMatch.confidence,
                extractedEmbedding: probeEmbedding,
              );
            }
          }

          return CloudFaceMatchResult(
            isMatch: false,
            errorMessage: data['message']?.toString() ?? 'Face not recognized in this chapter.',
          );
        }
      } catch (_) {}
    }

    // 3. Web enrollment stores the member photo in Firestore, not a neural
    // embedding. Compare the live selfie to those photos so photo-enrolled
    // members can still be recognized on Flutter web.
    final photoMatch = await _matchByEnrolledPhotos(photoBase64, candidates);
    if (photoMatch != null) return photoMatch;

    return const CloudFaceMatchResult(
      isMatch: false,
      errorMessage: 'Face not recognized in this chapter. Please look directly at the camera.',
    );
  }

  bool get _isRemoteApiReachable {
    final host = Uri.tryParse(_apiBaseUrl)?.host ?? '';
    if (host.isEmpty) return false;
    if (kIsWeb && (host == '127.0.0.1' || host == 'localhost')) {
      return false;
    }
    return true;
  }

  Future<Uint8List?> _resolvePhotoBytes(String photoUrl) async {
    try {
      final trimmed = photoUrl.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final res = await _httpClient
            .get(Uri.parse(trimmed))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
        return null;
      }
      return ImageUtils.base64ToBytes(trimmed);
    } catch (e) {
      AppLogger.warning(
        'Could not load member photo: $e',
        tag: 'CloudFaceRecognitionService',
      );
    }
    return null;
  }

  Future<CloudFaceMatchResult?> _matchByEnrolledPhotos(
    String photoBase64,
    List<Employee> candidates,
  ) async {
    final candidatesWithPhoto = candidates
        .where((c) =>
            c.isActive &&
            c.photoUrl != null &&
            c.photoUrl!.trim().isNotEmpty)
        .toList();
    if (candidatesWithPhoto.isEmpty) return null;

    final probeBytes = ImageUtils.base64ToBytes(photoBase64);
    if (probeBytes == null) return null;

    var probe = LocalFaceDescriptor.fromBytes(probeBytes);
    var probeMirror = LocalFaceDescriptor.mirroredFromBytes(probeBytes);
    probe ??= probeMirror;
    probeMirror ??= probe;
    if (probe == null || probeMirror == null) return null;

    Employee? bestCandidate;
    var bestSimilarity = -1.0;
    var secondBestSimilarity = -1.0;
    var scoredCount = 0;

    final resolved = await Future.wait(
      candidatesWithPhoto.map((candidate) async {
        final bytes = await _resolvePhotoBytes(candidate.photoUrl!);
        return (candidate, bytes);
      }),
    );

    for (final entry in resolved) {
      final candBytes = entry.$2;
      if (candBytes == null) continue;
      final cand = LocalFaceDescriptor.fromBytes(candBytes);
      if (cand == null) continue;

      final sim = LocalFaceDescriptor.bestSimilarity(
        probe: probe,
        probeMirrored: probeMirror,
        candidate: cand,
      );
      scoredCount++;
      if (sim > bestSimilarity) {
        secondBestSimilarity = bestSimilarity;
        bestSimilarity = sim;
        bestCandidate = entry.$1;
      } else if (sim > secondBestSimilarity) {
        secondBestSimilarity = sim;
      }
    }

    const likelyMatch = 0.36;
    const soloMatch = 0.44;
    const strongMatch = 0.60;
    const minMargin = 0.02;

    final margin = bestSimilarity -
        (secondBestSimilarity < 0 ? 0.0 : secondBestSimilarity);
    final templates = candidatesWithPhoto.length;

    AppLogger.info(
      'Photo match: best=${bestCandidate?.name} ($bestSimilarity), runnerUp=$secondBestSimilarity, margin=$margin, scored=$scoredCount/$templates',
      tag: 'CloudFaceRecognitionService',
    );

    if (bestCandidate == null) return null;

    var accept = false;
    if (templates <= 1) {
      accept = scoredCount == 1 && bestSimilarity >= soloMatch;
    } else if (scoredCount >= 2) {
      accept = bestSimilarity >= strongMatch ||
          (bestSimilarity >= likelyMatch && margin >= minMargin);
    } else if (scoredCount == 1) {
      accept = bestSimilarity >= 0.70;
    }

    if (!accept) return null;

    final confidence = (70.0 + bestSimilarity * 30.0).clamp(78.0, 99.0);
    return CloudFaceMatchResult(
      isMatch: true,
      matchedMember: bestCandidate,
      confidence: confidence,
    );
  }

  String _mapReasonToUserMessage(String? reason) {
    if (reason == null) return 'Face not recognized in this chapter.';
    switch (reason) {
      case 'NO_FACE_DETECTED':
        return 'No face detected. Please look directly at the camera.';
      case 'MULTIPLE_FACES_DETECTED':
        return 'Multiple faces detected. Please ensure only one person is in frame.';
      case 'POOR_IMAGE_QUALITY':
        return 'Image is blurry or poorly lit. Please position clearly.';
      case 'SPOOF_SUSPECTED':
        return 'Face authenticity check failed. Please ensure a live face without screen reflection.';
      case 'LOW_CONFIDENCE':
        return 'Face not recognized with sufficient confidence in this chapter.';
      case 'AMBIGUOUS_MATCH':
        return 'Multiple similar members detected. Please retake photo with clear lighting.';
      case 'NO_ENROLLED_MEMBERS_IN_CHAPTER':
        return 'No enrolled members found in this chapter.';
      default:
        return reason;
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
