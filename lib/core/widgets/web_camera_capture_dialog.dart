import 'dart:typed_data';
import 'package:flutter/material.dart';

import 'web_camera_capture_dialog_stub.dart'
    if (dart.library.html) 'web_camera_capture_dialog_web.dart' as platform;

/// Cross-platform helper to capture a photo using live camera preview.
/// On Web: Opens real HTML5 webcam video viewfinder modal with live preview.
/// On Native: Uses standard [ImagePicker] with [ImageSource.camera].
class WebCameraCaptureHelper {
  WebCameraCaptureHelper._();

  /// Opens the camera and returns captured image bytes (JPEG), or null if cancelled.
  static Future<Uint8List?> capturePhoto(BuildContext context) async {
    return platform.captureCameraPhoto(context);
  }
}
