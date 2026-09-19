// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';

/// Opens a real HTML5 webcam capture modal on Flutter Web.
Future<Uint8List?> captureCameraPhoto(BuildContext context) async {
  final dynamic result = await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withAlpha(200),
    builder: (ctx) => const _WebCameraCaptureDialogWidget(),
  );
  if (result is Uint8List) return result;
  if (result is List<Uint8List> && result.isNotEmpty) return result.first;
  return null;
}

/// Opens the HTML5 webcam to capture a multi-frame burst of photos.
Future<List<Uint8List>?> captureBurstPhotos(
  BuildContext context, {
  int count = 5,
  int intervalMs = 200,
}) async {
  final dynamic result = await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withAlpha(200),
    builder: (ctx) => _WebCameraCaptureDialogWidget(
      isBurst: true,
      burstCount: count,
      intervalMs: intervalMs,
    ),
  );
  if (result is List<Uint8List>) return result;
  if (result is Uint8List) return [result];
  return null;
}

class _WebCameraCaptureDialogWidget extends StatefulWidget {
  const _WebCameraCaptureDialogWidget({
    this.isBurst = false,
    this.burstCount = 5,
    this.intervalMs = 200,
  });

  final bool isBurst;
  final int burstCount;
  final int intervalMs;

  @override
  State<_WebCameraCaptureDialogWidget> createState() =>
      _WebCameraCaptureDialogWidgetState();
}

class _WebCameraCaptureDialogWidgetState
    extends State<_WebCameraCaptureDialogWidget> {
  late final String _viewId;
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;

  bool _isInitializing = true;
  String? _errorMessage;
  bool _isCapturingBurst = false;
  int _burstProgress = 0;

  @override
  void initState() {
    super.initState();
    _viewId = 'web-camera-view-${DateTime.now().microsecondsSinceEpoch}';
    _initWebcam();
  }

  Future<void> _initWebcam() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        throw Exception(
            'MediaDevices API not supported in this browser. Please use Gallery upload.');
      }

      final stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });

      _mediaStream = stream;

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)'; // Mirror front webcam

      video.srcObject = stream;
      _videoElement = video;

      // Register the web platform view
      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => video,
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Camera access was denied or not available. Please allow camera permissions in your browser or choose a photo from Gallery.';
        });
      }
    }
  }

  Uint8List? _grabSingleFrame() {
    final video = _videoElement;
    if (video == null) return null;

    final vw = video.videoWidth > 0 ? video.videoWidth : 640;
    final vh = video.videoHeight > 0 ? video.videoHeight : 480;

    const ovalAspect = 180 / 235;
    var cropH = vh * 0.92;
    var cropW = cropH * ovalAspect;
    if (cropW > vw * 0.92) {
      cropW = vw * 0.92;
      cropH = cropW / ovalAspect;
    }
    final sx = (vw - cropW) / 2;
    final sy = (vh - cropH) / 2;

    const outW = 480;
    final outH = (outW / ovalAspect).round();
    final canvas = html.CanvasElement(width: outW, height: outH);
    final ctx = canvas.context2D;

    // Flip horizontally to match mirror preview
    ctx.translate(outW, 0);
    ctx.scale(-1, 1);
    ctx.drawImageScaledFromSource(
      video,
      sx,
      sy,
      cropW,
      cropH,
      0,
      0,
      outW,
      outH,
    );

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.85);
    final base64String = dataUrl.split(',').last;
    return base64Decode(base64String);
  }

  Future<void> _capturePhoto() async {
    if (widget.isBurst) {
      setState(() {
        _isCapturingBurst = true;
        _burstProgress = 1;
      });

      final frames = <Uint8List>[];
      for (int i = 0; i < widget.burstCount; i++) {
        final frame = _grabSingleFrame();
        if (frame != null) {
          frames.add(frame);
        }
        if (mounted) {
          setState(() {
            _burstProgress = i + 1;
          });
        }
        if (i < widget.burstCount - 1) {
          await Future.delayed(Duration(milliseconds: widget.intervalMs));
        }
      }

      _stopCamera();
      if (mounted) {
        Navigator.of(context).pop(frames);
      }
    } else {
      final bytes = _grabSingleFrame();
      _stopCamera();
      Navigator.of(context).pop(bytes);
    }
  }

  Future<void> _pickFromGallery() async {
    _stopCamera();
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (!mounted) return;
      if (photo != null) {
        final bytes = await photo.readAsBytes();
        if (!mounted) return;
        Navigator.of(context).pop(bytes);
      } else {
        Navigator.of(context).pop(null);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(null);
      }
    }
  }

  void _stopCamera() {
    if (_mediaStream != null) {
      for (final track in _mediaStream!.getTracks()) {
        track.stop();
      }
      _mediaStream = null;
    }
    if (_videoElement != null) {
      _videoElement!.srcObject = null;
      _videoElement = null;
    }
  }

  @override
  void dispose() {
    _stopCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Dialog Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Take Member Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Align face within frame and click Capture',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Cancel',
                    onPressed: () {
                      _stopCamera();
                      Navigator.of(context).pop(null);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Camera Viewport / Error State
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 320,
                  color: const Color(0xFF0F172A),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_errorMessage != null)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.videocam_off_rounded,
                                  color: Color(0xFFF43F5E),
                                  size: 40,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _initWebcam,
                                      icon: const Icon(Icons.refresh_rounded,
                                          size: 16),
                                      label: const Text('Try Again'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(
                                            color: Colors.white54),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton.icon(
                                      onPressed: _pickFromGallery,
                                      icon: const Icon(Icons.image_outlined,
                                          size: 16),
                                      label: const Text('From Gallery'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (_isInitializing)
                        const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: AppColors.primary,
                                strokeWidth: 3,
                              ),
                              SizedBox(height: 14),
                              Text(
                                'Starting camera...',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // Live Web Video Element View
                        HtmlElementView(viewType: _viewId),

                        // Vignette cutout overlay that dims room background outside the oval
                        const IgnorePointer(
                          child: CustomPaint(
                            size: Size.infinite,
                            painter: _FaceGuideOverlayPainter(
                              ovalWidth: 180,
                              ovalHeight: 235,
                              borderColor: Colors.white,
                              scrimColor: Color(0xA6000000), // 65% black scrim
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _stopCamera();
                        Navigator.of(context).pop(null);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: (_isInitializing || _errorMessage != null || _isCapturingBurst)
                          ? null
                          : _capturePhoto,
                      icon: _isCapturingBurst
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.camera_alt_rounded, size: 18),
                      label: Text(
                        _isCapturingBurst
                            ? 'Hold still... ($_burstProgress/${widget.burstCount})'
                            : widget.isBurst
                                ? 'Verify Face (${widget.burstCount} Frames)'
                                : 'Capture Photo',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaceGuideOverlayPainter extends CustomPainter {
  const _FaceGuideOverlayPainter({
    required this.ovalWidth,
    required this.ovalHeight,
    required this.borderColor,
    required this.scrimColor,
  });

  final double ovalWidth;
  final double ovalHeight;
  final Color borderColor;
  final Color scrimColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final ovalRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: ovalWidth,
      height: ovalHeight,
    );

    final path = Path()
      ..addRect(rect)
      ..addOval(ovalRect)
      ..fillType = PathFillType.evenOdd;

    final scrimPaint = Paint()
      ..color = scrimColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(path, scrimPaint);

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    canvas.drawOval(ovalRect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _FaceGuideOverlayPainter oldDelegate) {
    return oldDelegate.ovalWidth != ovalWidth ||
        oldDelegate.ovalHeight != ovalHeight ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.scrimColor != scrimColor;
  }
}
