import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// Result of a face quality & liveness validation check.
class FaceValidationResult {
  const FaceValidationResult({
    required this.isValid,
    this.errorMessage,
    this.leftEyeOpenProbability,
    this.rightEyeOpenProbability,
    this.smilingProbability,
  });

  final bool isValid;
  final String? errorMessage;
  final double? leftEyeOpenProbability;
  final double? rightEyeOpenProbability;
  final double? smilingProbability;
}

/// Service wrapping Google ML Kit Face Detector for real-time face detection,
/// bounding box extraction, and liveness / anti-spoofing verification.
class FaceDetectorService {
  FaceDetectorService() {
    _initDetector();
  }

  FaceDetector? _detector;

  void _initDetector() {
    if (kIsWeb) return;
    final options = FaceDetectorOptions(
      enableClassification: true, // Needed for eye open and smile probability (liveness)
      enableTracking: true,
      performanceMode: FaceDetectorMode.accurate,
      minFaceSize: 0.15,
    );
    _detector = FaceDetector(options: options);
  }

  /// Detects faces in the provided [InputImage].
  Future<List<Face>> detectFaces(InputImage inputImage) async {
    if (kIsWeb) return [];
    if (_detector == null) {
      _initDetector();
    }
    return await _detector?.processImage(inputImage) ?? [];
  }

  /// Validates whether a detected face meets production quality & orientation standards.
  /// Checks for head rotation angles (facing front), and returns feedback.
  FaceValidationResult validateFace(Face face, {Size? previewSize}) {
    // 1. Check head tilt (yaw and roll)
    final yaw = face.headEulerAngleY ?? 0.0; // Left/right turn
    final roll = face.headEulerAngleZ ?? 0.0; // Ear to shoulder tilt

    if (yaw.abs() > 22.0) {
      return const FaceValidationResult(
        isValid: false,
        errorMessage: 'Please look directly at the camera',
      );
    }

    if (roll.abs() > 20.0) {
      return const FaceValidationResult(
        isValid: false,
        errorMessage: 'Please hold your head straight',
      );
    }

    // 2. Check bounding box size if preview size is known
    if (previewSize != null && previewSize.width > 0 && previewSize.height > 0) {
      final box = face.boundingBox;
      final faceRatio = (box.width * box.height) / (previewSize.width * previewSize.height);
      if (faceRatio < 0.04) {
        return const FaceValidationResult(
          isValid: false,
          errorMessage: 'Please move closer to the camera',
        );
      }
    }

    return FaceValidationResult(
      isValid: true,
      leftEyeOpenProbability: face.leftEyeOpenProbability,
      rightEyeOpenProbability: face.rightEyeOpenProbability,
      smilingProbability: face.smilingProbability,
    );
  }

  /// Checks if the person is blinking or has eyes open (used for anti-spoofing).
  bool isEyesOpen(Face face, {double threshold = 0.65}) {
    final left = face.leftEyeOpenProbability ?? 1.0;
    final right = face.rightEyeOpenProbability ?? 1.0;
    return left >= threshold && right >= threshold;
  }

  /// Checks if eyes are closed (e.g. mid-blink).
  bool isEyesClosed(Face face, {double threshold = 0.25}) {
    final left = face.leftEyeOpenProbability ?? 1.0;
    final right = face.rightEyeOpenProbability ?? 1.0;
    return left <= threshold || right <= threshold;
  }

  /// Releases resources.
  Future<void> dispose() async {
    await _detector?.close();
    _detector = null;
  }
}
