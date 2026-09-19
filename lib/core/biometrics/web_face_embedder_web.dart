// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:js' as js;

import '../logger/app_logger.dart';

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

    // Use JsFunction with allowInterop
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
      AppLogger.warning('Web face embedding error: $error', tag: 'WebFaceEmbedder');
      if (!completer.isCompleted) completer.complete(null);
    });

    promise.callMethod('then', [thenCallback, catchCallback]);

    return await completer.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () => null,
    );
  } catch (e) {
    AppLogger.error('Error invoking web neural face embedding: $e', tag: 'WebFaceEmbedder');
    return null;
  }
}
