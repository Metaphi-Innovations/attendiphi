import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import 'face_detector_service.dart';
import 'face_embedding_service.dart';

/// Result of processing a photo for member face enrollment.
class FaceEnrollmentResult {
  const FaceEnrollmentResult({
    required this.faceEmbedding,
    required this.face,
    required this.croppedFaceBytes,
  });

  final List<double> faceEmbedding;
  final Face face;
  final Uint8List croppedFaceBytes;
}

/// Helper class to coordinate face detection, quality validation,
/// cropping, and embedding extraction from an image file during member enrollment.
class FaceEnrollmentHelper {
  const FaceEnrollmentHelper({
    required this.detectorService,
    required this.embeddingService,
  });

  final FaceDetectorService detectorService;
  final FaceEmbeddingService embeddingService;

  /// Processes an image from [filePath] and generates a valid 192-float biometric embedding.
  /// Throws [Exception] with user-friendly messages if validation fails.
  Future<FaceEnrollmentResult> processEnrollmentPhoto(String filePath) async {
    if (kIsWeb) {
      throw Exception(
        'Face biometric extraction requires the native Android/iOS mobile application.',
      );
    }
    final file = File(filePath);
    if (!file.existsSync()) {
      throw Exception('Image file not found at $filePath');
    }

    final bytes = await file.readAsBytes();

    // 1. Detect faces using Google ML Kit
    final inputImage = InputImage.fromFilePath(filePath);
    final faces = await detectorService.detectFaces(inputImage);

    if (faces.isEmpty) {
      throw Exception(
        'No face detected. Please ensure the photo is well-lit and faces the camera directly.',
      );
    }

    if (faces.length > 1) {
      throw Exception(
        'Multiple faces detected (${faces.length}). Only the member\'s face should be in the photo.',
      );
    }

    final face = faces.first;

    // 2. Validate face orientation & angle
    final quality = detectorService.validateFace(face);
    if (!quality.isValid) {
      throw Exception(
        quality.errorMessage ?? 'Please take a clearer front-facing photo.',
      );
    }

    // 3. Decode image to pure Dart Image for manipulation
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Failed to decode image file.');
    }

    // Adjust for EXIF orientation if needed
    final oriented = img.bakeOrientation(decoded);

    // 4. Horizontally level face via eye landmarks and crop with contrast normalization
    final alignedCropped = embeddingService.alignAndCropFace(oriented, face);
    final croppedJpg = Uint8List.fromList(
      img.encodeJpg(alignedCropped, quality: 85),
    );

    // 5. Ensure embedding model is initialized
    if (!embeddingService.isInitialized) {
      await embeddingService.initialize();
    }

    // 6. Extract 192-dimension biometric vector
    final embedding = embeddingService.extractEmbedding(alignedCropped);

    return FaceEnrollmentResult(
      faceEmbedding: embedding,
      face: face,
      croppedFaceBytes: croppedJpg,
    );
  }

  /// Computes a normalized centroid embedding from multiple enrollment captures.
  /// Averages vectors to filter sensor noise, subtle lighting changes, and small pose differences.
  static List<double> computeCentroidEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return const [];
    if (embeddings.length == 1) return embeddings.first;

    final length = embeddings.first.length;
    final centroid = List<double>.filled(length, 0.0);

    for (final emb in embeddings) {
      if (emb.length != length) continue;
      for (int i = 0; i < length; i++) {
        centroid[i] += emb[i];
      }
    }

    // L2-normalize the centroid vector
    double sumSq = 0.0;
    for (final v in centroid) {
      sumSq += v * v;
    }
    final norm = sqrt(sumSq);

    if (norm > 0) {
      for (int i = 0; i < length; i++) {
        centroid[i] /= norm;
      }
    }

    return centroid;
  }
}
