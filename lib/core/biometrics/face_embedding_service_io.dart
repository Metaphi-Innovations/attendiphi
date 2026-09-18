import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Native (Android / iOS / Desktop) implementation using tflite_flutter.
class FaceEmbeddingService {
  FaceEmbeddingService({this.modelPath = 'assets/models/mobilefacenet.tflite'});

  final String modelPath;
  Interpreter? _interpreter;
  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  /// Loads the TFLite interpreter from assets.
  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_isInitialized) return;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(modelPath, options: options);
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  /// Crops a face region from a full [img.Image] given its bounding box [Rect].
  /// Applies a gentle 15% safety margin around the face.
  img.Image cropFace(img.Image image, Rect boundingBox) {
    final double marginX = boundingBox.width * 0.15;
    final double marginY = boundingBox.height * 0.15;

    final int x = max(0, (boundingBox.left - marginX).toInt());
    final int y = max(0, (boundingBox.top - marginY).toInt());
    final int w = min(image.width - x, (boundingBox.width + (marginX * 2)).toInt());
    final int h = min(image.height - y, (boundingBox.height + (marginY * 2)).toInt());

    return img.copyCrop(image, x: x, y: y, width: max(1, w), height: max(1, h));
  }

  /// Extracts a 192-float normalized face embedding from an [img.Image] of a face.
  /// Automatically resizes to 112x112 and normalizes pixels to [-1, 1].
  List<double> extractEmbedding(img.Image faceImage) {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('FaceEmbeddingService is not initialized. Call initialize() first.');
    }

    // 1. Resize cropped face to 112 x 112 required by MobileFaceNet
    final resized = img.copyResize(faceImage, width: 112, height: 112);

    // 2. Prepare 4D input array: shape [1, 112, 112, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        112,
        (y) => List.generate(
          112,
          (x) {
            final pixel = resized.getPixel(x, y);
            // MobileFaceNet standard normalization: (x - 127.5) / 128.0
            final r = (pixel.r - 127.5) / 128.0;
            final g = (pixel.g - 127.5) / 128.0;
            final b = (pixel.b - 127.5) / 128.0;
            return [r, g, b];
          },
        ),
      ),
    );

    // 3. Output buffer: shape [1, 192]
    final output = List.filled(1 * 192, 0.0).reshape([1, 192]);

    // 4. Run inference on device
    _interpreter!.run(input, output);

    // 5. Extract and L2-normalize the 192 numbers
    final List<dynamic> rawRow = output[0] as List<dynamic>;
    final List<double> embedding = rawRow.map((e) => (e as num).toDouble()).toList();

    double sumSq = 0.0;
    for (final val in embedding) {
      sumSq += val * val;
    }
    final double norm = sqrt(sumSq);

    if (norm > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] = embedding[i] / norm;
      }
    }

    return embedding;
  }

  /// Releases model interpreter.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
