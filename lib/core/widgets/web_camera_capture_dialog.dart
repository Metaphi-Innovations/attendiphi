import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'web_camera_capture_dialog_stub.dart'
    if (dart.library.html) 'web_camera_capture_dialog_web.dart' as platform;

/// Cross-platform helper to capture photos using live camera preview.
/// On Web: Opens real HTML5 webcam video viewfinder modal with live preview.
/// On Native: Uses standard [ImagePicker] with [ImageSource.camera].
class WebCameraCaptureHelper {
  WebCameraCaptureHelper._();

  /// Opens the camera and returns captured image bytes (JPEG), or null if cancelled.
  static Future<Uint8List?> capturePhoto(BuildContext context) async {
    return platform.captureCameraPhoto(context);
  }

  /// Captures a controlled multi-frame burst of photos for biometric verification.
  static Future<List<Uint8List>?> captureBurstPhotos(
    BuildContext context, {
    int count = 5,
    int intervalMs = 280,
    List<String>? poseGuides,
    bool waitForFace = true,
    bool allowGallery = false,
    bool autoCapture = false,
  }) async {
    return platform.captureBurstPhotos(
      context,
      count: count,
      intervalMs: intervalMs,
      poseGuides: poseGuides,
      waitForFace: waitForFace,
      allowGallery: allowGallery,
      autoCapture: autoCapture,
    );
  }
}
