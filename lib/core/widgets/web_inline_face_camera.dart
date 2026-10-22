import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'web_inline_face_camera_stub.dart'
    if (dart.library.html) 'web_inline_face_camera_web.dart' as platform;

/// Inline HTML5 webcam preview used by Member check-in on Flutter Web.
///
/// Starts the camera as soon as it is mounted (browser permission prompt
/// appears here). Auto-captures a verification burst once a face is ready.
class WebInlineFaceCamera extends StatelessWidget {
  const WebInlineFaceCamera({
    super.key,
    required this.onCaptured,
    this.burstCount = 5,
    this.intervalMs = 280,
    this.waitForFace = true,
  });

  final int burstCount;
  final int intervalMs;
  final bool waitForFace;
  final void Function(List<Uint8List> frames) onCaptured;

  @override
  Widget build(BuildContext context) {
    return platform.WebInlineFaceCameraView(
      burstCount: burstCount,
      intervalMs: intervalMs,
      waitForFace: waitForFace,
      onCaptured: onCaptured,
    );
  }
}
