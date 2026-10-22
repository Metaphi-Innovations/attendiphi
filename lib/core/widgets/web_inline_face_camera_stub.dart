import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Non-web stub: Member check-in uses the native [CameraPreview] path instead.
class WebInlineFaceCameraView extends StatelessWidget {
  const WebInlineFaceCameraView({
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
    return const SizedBox(
      height: 300,
      child: Center(
        child: CircularProgressIndicator(
          color: AppColors.primary,
          strokeWidth: 2.5,
        ),
      ),
    );
  }
}
