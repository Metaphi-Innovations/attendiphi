import 'dart:math';
import 'dart:ui';
import 'package:image/image.dart' as img;

/// Web stub implementation of FaceEmbeddingService.
/// tflite_flutter uses dart:ffi which is unsupported on the web compiler.
class FaceEmbeddingService {
  FaceEmbeddingService({this.modelPath = 'assets/models/mobilefacenet.tflite'});

  final String modelPath;
  final bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// No-op on web since native TFLite binaries cannot run in JS environment.
  Future<void> initialize() async {}

  /// Crops a face region from a full [img.Image] given its bounding box [Rect].
  img.Image cropFace(img.Image image, Rect boundingBox) {
    final double marginX = boundingBox.width * 0.15;
    final double marginY = boundingBox.height * 0.15;

    final int x = max(0, (boundingBox.left - marginX).toInt());
    final int y = max(0, (boundingBox.top - marginY).toInt());
    final int w = min(image.width - x, (boundingBox.width + (marginX * 2)).toInt());
    final int h = min(image.height - y, (boundingBox.height + (marginY * 2)).toInt());

    return img.copyCrop(image, x: x, y: y, width: max(1, w), height: max(1, h));
  }

  /// Extracts embedding. Not supported on web without WebAssembly TFLite build.
  List<double> extractEmbedding(img.Image faceImage) {
    return const [];
  }

  /// Releases resources.
  void dispose() {}
}
