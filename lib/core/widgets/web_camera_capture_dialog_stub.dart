import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Stub implementation for non-web platforms (Android, iOS, desktop native, tests).
/// Uses the standard [ImagePicker] with [ImageSource.camera].
Future<Uint8List?> captureCameraPhoto(BuildContext context) async {
  try {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (photo == null) return null;
    return await photo.readAsBytes();
  } catch (e) {
    debugPrint('Native camera capture error: $e');
    return null;
  }
}

/// Stub burst capture for non-web platforms.
Future<List<Uint8List>?> captureBurstPhotos(
  BuildContext context, {
  int count = 5,
  int intervalMs = 280,
  List<String>? poseGuides,
  bool waitForFace = true,
  bool allowGallery = false,
  bool autoCapture = false,
}) async {
  final single = await captureCameraPhoto(context);
  if (single == null) return null;
  return [single];
}
