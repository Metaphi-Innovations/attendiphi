// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// Live inline webcam used by Member check-in. Same getUserMedia + face
/// assessment + burst capture as the existing web camera helper, without a dialog.
class WebInlineFaceCameraView extends StatefulWidget {
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
  State<WebInlineFaceCameraView> createState() =>
      _WebInlineFaceCameraViewState();
}

class _WebInlineFaceCameraViewState extends State<WebInlineFaceCameraView> {
  late final String _viewId;
  html.VideoElement? _videoElement;
  html.MediaStream? _mediaStream;

  bool _isInitializing = true;
  String? _errorMessage;
  bool _isCapturingBurst = false;
  String _liveGuidance = 'Align your face within the oval';
  bool _faceReady = false;
  bool _autoCaptureStarted = false;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _viewId = 'inline-web-camera-${DateTime.now().microsecondsSinceEpoch}';
    _initWebcam();
  }

  Future<void> _initWebcam() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
      _autoCaptureStarted = false;
      _isCapturingBurst = false;
    });

    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (html.window.isSecureContext == false) {
        throw Exception(
          'Camera access requires HTTPS. Open this app on a secure URL.',
        );
      }
      if (mediaDevices == null) {
        throw Exception(
          'This browser does not support camera access. Please use Chrome, Edge, or Safari.',
        );
      }

      final stream = await mediaDevices.getUserMedia({
        'video': {
          'facingMode': 'user',
          'width': {'ideal': 1280},
          'height': {'ideal': 720},
        },
        'audio': false,
      });

      if (!mounted) {
        for (final track in stream.getTracks()) {
          track.stop();
        }
        return;
      }

      _mediaStream = stream;

      final video = html.VideoElement()
        ..autoplay = true
        ..muted = true
        ..setAttribute('playsinline', 'true')
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.objectFit = 'cover'
        ..style.transform = 'scaleX(-1)';

      video.srcObject = stream;
      _videoElement = video;

      ui_web.platformViewRegistry.registerViewFactory(
        _viewId,
        (int viewId) => video,
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _startPreviewLoop();
        _maybeAutoCapture();
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Camera permission is required for face attendance. Allow camera access in your browser, then tap Try Again.';
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

  void _maybeAutoCapture() {
    if (_autoCaptureStarted) return;
    if (_isInitializing || _errorMessage != null) return;
    _autoCaptureStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isCapturingBurst) {
        _captureBurst();
      }
    });
  }

  void _startPreviewLoop() {
    _previewTimer?.cancel();
    _previewTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _refreshLiveGuidance();
    });
  }

  Future<void> _refreshLiveGuidance() async {
    if (!mounted ||
        _isInitializing ||
        _errorMessage != null ||
        _isCapturingBurst) {
      return;
    }
    final bytes = _grabSingleFrame();
    if (bytes == null) return;
    final assessed = await _assessJpeg(bytes, requireFrontal: true);
    if (!mounted || _isCapturingBurst) return;
    final guidance = assessed?['guidance']?.toString() ?? _liveGuidance;
    final ready = assessed?['ok'] == true;
    if (guidance != _liveGuidance || ready != _faceReady) {
      setState(() {
        _liveGuidance = ready ? 'Hold still — verifying face...' : guidance;
        _faceReady = ready;
      });
    }
  }

  Future<Map<String, dynamic>?> _assessJpeg(
    Uint8List bytes, {
    required bool requireFrontal,
  }) async {
    if (!js.context.hasProperty('assessLiveFaceFrame')) return null;
    try {
      final completer = Completer<Map<String, dynamic>?>();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final options = js.JsObject.jsify({
        'minFaceSizeRatio': 0.12,
        'minBrightness': 35,
        'maxBrightness': 230,
        'minSharpness': 18,
        'requireFrontal': requireFrontal,
      });
      final dynamic promise =
          js.context.callMethod('assessLiveFaceFrame', [dataUrl, options]);
      if (promise == null) return null;
      promise.callMethod('then', [
        js.JsFunction.withThis((_, dynamic result) {
          if (completer.isCompleted) return;
          if (result == null) {
            completer.complete(null);
            return;
          }
          completer.complete({
            'ok': result['ok'] == true,
            'guidance': result['guidance']?.toString(),
            'faceCount': result['faceCount'],
          });
        }),
        js.JsFunction.withThis((_, dynamic error) {
          if (!completer.isCompleted) completer.complete(null);
        }),
      ]);
      return await completer.future.timeout(
        const Duration(seconds: 4),
        onTimeout: () => null,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _waitUntilReady({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      final bytes = _grabSingleFrame();
      if (bytes != null) {
        final assessed = await _assessJpeg(bytes, requireFrontal: true);
        final ready = assessed?['ok'] == true;
        final guidance = assessed?['guidance']?.toString();
        if (mounted) {
          setState(() {
            _faceReady = ready;
            if (guidance != null && guidance.isNotEmpty) {
              _liveGuidance =
                  ready ? 'Hold still — verifying face...' : guidance;
            }
          });
        }
        if (ready) return;
      }
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  Future<void> _captureBurst() async {
    if (!mounted || _isCapturingBurst) return;
    setState(() {
      _isCapturingBurst = true;
      _liveGuidance = 'Verifying face...';
    });

    final frames = <Uint8List>[];
    var waitedForFace = false;
    for (int i = 0; i < widget.burstCount; i++) {
      if (!mounted) return;
      if (widget.waitForFace && !waitedForFace) {
        await _waitUntilReady();
        waitedForFace = true;
      }
      if (!mounted) return;
      final frame = _grabSingleFrame();
      if (frame != null) {
        frames.add(frame);
      }
      if (i < widget.burstCount - 1) {
        await Future.delayed(Duration(milliseconds: widget.intervalMs));
      }
    }

    _stopCamera();
    if (!mounted) return;
    if (frames.isEmpty) {
      setState(() {
        _isCapturingBurst = false;
        _errorMessage =
            'Could not capture a face. Check lighting and tap Try Again.';
      });
      return;
    }
    widget.onCaptured(frames);
  }

  void _stopCamera() {
    _previewTimer?.cancel();
    _previewTimer = null;
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Container(
        height: 300,
        color: const Color(0xFF0F172A),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
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
                      OutlinedButton.icon(
                        onPressed: _initWebcam,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Try Again'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white54),
                        ),
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
              HtmlElementView(viewType: _viewId),
              const IgnorePointer(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _InlineFaceGuidePainter(
                    ovalWidth: 180,
                    ovalHeight: 235,
                    borderColor: Colors.white,
                    scrimColor: Color(0xA6000000),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withAlpha(160),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _isCapturingBurst ? 'Verifying face...' : _liveGuidance,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _faceReady || _isCapturingBurst
                          ? const Color(0xFF34D399)
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InlineFaceGuidePainter extends CustomPainter {
  const _InlineFaceGuidePainter({
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

    canvas.drawPath(
      path,
      Paint()
        ..color = scrimColor
        ..style = PaintingStyle.fill,
    );
    canvas.drawOval(
      ovalRect,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(covariant _InlineFaceGuidePainter oldDelegate) {
    return oldDelegate.ovalWidth != ovalWidth ||
        oldDelegate.ovalHeight != ovalHeight ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.scrimColor != scrimColor;
  }
}
