// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;

import '../logger/app_logger.dart';
import 'face_matching_config.dart';
import 'web_face_embedder_stub.dart';
export 'web_face_embedder_stub.dart' show ValidatedFaceFrame;

bool _engineInitializing = false;
bool _engineReady = false;

/// Loads tiny-face-detector + SFace ONNX once and reuses the sessions.
Future<bool> initializeFaceRecognitionWeb() async {
  if (_engineReady) return true;
  if (_engineInitializing) return _engineReady;
  _engineInitializing = true;
  try {
    if (!js.context.hasProperty('initializeFaceRecognition')) {
      AppLogger.warning(
        'initializeFaceRecognition JS function not present on window.',
        tag: 'WebFaceEmbedder',
      );
      return false;
    }
    final completer = Completer<bool>();
    final dynamic promise = js.context.callMethod(
      'initializeFaceRecognition',
      [],
    );
    if (promise == null) return false;
    final thenCallback = js.JsFunction.withThis((_, dynamic result) {
      if (!completer.isCompleted) completer.complete(result == true);
    });
    final catchCallback = js.JsFunction.withThis((_, dynamic error) {
      AppLogger.warning(
        'Face engine init error: $error',
        tag: 'WebFaceEmbedder',
      );
      if (!completer.isCompleted) completer.complete(false);
    });
    promise.callMethod('then', [thenCallback, catchCallback]);
    _engineReady = await completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () => false,
    );
    return _engineReady;
  } catch (e) {
    AppLogger.error(
      'Failed to initialize web face engine: $e',
      tag: 'WebFaceEmbedder',
    );
    return false;
  } finally {
    _engineInitializing = false;
  }
}

/// Web implementation calling SFace via ONNX Runtime Web in `web/face_verifier.js`.
Future<List<double>?> extractFaceEmbeddingWeb(String photoBase64) async {
  try {
    if (!js.context.hasProperty('extractNeuralFaceEmbedding')) {
      AppLogger.warning(
        'extractNeuralFaceEmbedding JS function not present on window.',
        tag: 'WebFaceEmbedder',
      );
      return null;
    }

    final completer = Completer<List<double>?>();

    final dynamic promise = js.context.callMethod(
      'extractNeuralFaceEmbedding',
      [photoBase64],
    );

    if (promise == null) return null;

    final thenCallback = js.JsFunction.withThis((_, dynamic result) {
      if (result == null) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }
      try {
        final List<dynamic> rawList = (result as js.JsArray).toList();
        final List<double> embedding = rawList
            .whereType<num>()
            .map((e) => e.toDouble())
            .toList();
        if (embedding.length == 128) {
          if (!completer.isCompleted) completer.complete(embedding);
        } else {
          if (!completer.isCompleted) completer.complete(null);
        }
      } catch (_) {
        if (!completer.isCompleted) completer.complete(null);
      }
    });

    final catchCallback = js.JsFunction.withThis((_, dynamic error) {
      AppLogger.warning(
        'Web face embedding error: $error',
        tag: 'WebFaceEmbedder',
      );
      if (!completer.isCompleted) completer.complete(null);
    });

    promise.callMethod('then', [thenCallback, catchCallback]);

    return await completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () => null,
    );
  } catch (e) {
    AppLogger.error(
      'Error invoking web neural face embedding: $e',
      tag: 'WebFaceEmbedder',
    );
    return null;
  }
}

ValidatedFaceFrame _applyQualityGate(
  ValidatedFaceFrame frame, {
  required bool forEnrollment,
}) {
  if (!frame.isValid) return frame;
  final reason = FaceMatchingConfig.qualityRejectionReason(
    forEnrollment: forEnrollment,
    sharpness: frame.sharpness,
    brightness: frame.brightness,
    faceSizeRatio: frame.faceSizeRatio,
  );
  if (reason == null) return frame;
  return ValidatedFaceFrame(
    isValid: false,
    errorMessage: reason,
    embedding: frame.embedding,
    sharpness: frame.sharpness,
    brightness: frame.brightness,
    faceSizeRatio: frame.faceSizeRatio,
    faceCount: frame.faceCount,
    poseYaw: frame.poseYaw,
    poseLabel: frame.poseLabel,
  );
}

/// Web implementation evaluating face frame quality and extracting SFace embedding.
Future<ValidatedFaceFrame> validateAndExtractFaceFrameWeb(
  String photoBase64, {
  bool forEnrollment = false,
}) async {
  try {
    if (!js.context.hasProperty('validateAndExtractFaceFrame')) {
      // Fall back to simple embedding extractor if validator not yet ready
      final emb = await extractFaceEmbeddingWeb(photoBase64);
      return _applyQualityGate(
        ValidatedFaceFrame(
          isValid: emb != null && emb.length == 128,
          embedding: emb,
          errorMessage: emb == null ? 'Face not recognized in frame.' : null,
        ),
        forEnrollment: forEnrollment,
      );
    }

    final completer = Completer<ValidatedFaceFrame>();
    final options = js.JsObject.jsify({
      'forEnrollment': forEnrollment,
      'requireFrontal': false,
      'minSharpness': FaceMatchingConfig.minimumSharpnessFor(
        forEnrollment: forEnrollment,
      ),
      'minBrightness': FaceMatchingConfig.minimumBrightness,
      'maxBrightness': FaceMatchingConfig.maximumBrightness,
      'minFaceSizeRatio': FaceMatchingConfig.minimumFaceSizeRatioFor(
        forEnrollment: forEnrollment,
      ),
      'minImageSide': forEnrollment
          ? FaceMatchingConfig.enrollMinimumImageSide
          : FaceMatchingConfig.verifyMinimumImageSide,
    });

    final dynamic promise = js.context.callMethod(
      'validateAndExtractFaceFrame',
      [photoBase64, options],
    );

    if (promise == null) {
      return const ValidatedFaceFrame(
        isValid: false,
        errorMessage: 'Could not invoke face verifier session.',
      );
    }

    final thenCallback = js.JsFunction.withThis((_, dynamic result) {
      if (result == null) {
        if (!completer.isCompleted) {
          completer.complete(
            const ValidatedFaceFrame(
              isValid: false,
              errorMessage: 'Face frame rejected.',
            ),
          );
        }
        return;
      }
      try {
        final bool valid = result['valid'] == true;
        final String? error = result['error']?.toString();

        List<double>? embedding;
        if (result['embedding'] != null) {
          final List<dynamic> rawList = (result['embedding'] as js.JsArray)
              .toList();
          embedding = rawList
              .whereType<num>()
              .map((e) => e.toDouble())
              .toList();
        }

        double sharpness = 0.0;
        double brightness = 0.0;
        double faceSizeRatio = 0.0;
        final int faceCount = (result['faceCount'] as num?)?.toInt() ?? 0;
        if (result['quality'] != null) {
          sharpness =
              (result['quality']['sharpness'] as num?)?.toDouble() ?? 0.0;
          brightness =
              (result['quality']['brightness'] as num?)?.toDouble() ?? 0.0;
          faceSizeRatio =
              (result['quality']['faceSizeRatio'] as num?)?.toDouble() ?? 0.0;
        }

        double poseYaw = 0.0;
        String? poseLabel;
        if (result['pose'] != null) {
          poseYaw = (result['pose']['yaw'] as num?)?.toDouble() ?? 0.0;
          poseLabel = result['pose']['label']?.toString();
        }

        if (!completer.isCompleted) {
          completer.complete(
            _applyQualityGate(
              ValidatedFaceFrame(
                isValid: valid && embedding != null && embedding.length == 128,
                errorMessage: error,
                embedding: embedding == null
                    ? null
                    : List<double>.from(embedding),
                sharpness: sharpness,
                brightness: brightness,
                faceSizeRatio: faceSizeRatio,
                faceCount: faceCount,
                poseYaw: poseYaw,
                poseLabel: poseLabel,
              ),
              forEnrollment: forEnrollment,
            ),
          );
        }
      } catch (e) {
        if (!completer.isCompleted) {
          completer.complete(
            ValidatedFaceFrame(
              isValid: false,
              errorMessage: 'Format error: $e',
            ),
          );
        }
      }
    });

    final catchCallback = js.JsFunction.withThis((_, dynamic error) {
      AppLogger.warning(
        'Web frame validation error: $error',
        tag: 'WebFaceEmbedder',
      );
      if (!completer.isCompleted) {
        completer.complete(
          ValidatedFaceFrame(
            isValid: false,
            errorMessage: error?.toString() ?? 'Validation failed',
          ),
        );
      }
    });

    promise.callMethod('then', [thenCallback, catchCallback]);

    return await completer.future
        .timeout(
          const Duration(seconds: 6),
          onTimeout: () => const ValidatedFaceFrame(
            isValid: false,
            errorMessage: 'Face verification timeout.',
          ),
        )
        .then(
          (frame) => _applyQualityGate(frame, forEnrollment: forEnrollment),
        );
  } catch (e) {
    return ValidatedFaceFrame(isValid: false, errorMessage: 'Error: $e');
  }
}
