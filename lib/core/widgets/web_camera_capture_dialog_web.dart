// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js' as js;
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
  int intervalMs = 280,
  List<String>? poseGuides,
  bool waitForFace = true,
  bool allowGallery = false,
  bool autoCapture = false,
}) async {
  final dynamic result = await showDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withAlpha(200),
    builder: (ctx) => _WebCameraCaptureDialogWidget(
      isBurst: true,
      burstCount: count,
      intervalMs: intervalMs,
      poseGuides: poseGuides,
      waitForFace: waitForFace,
      allowGallery: allowGallery,
      autoCapture: autoCapture,
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
    this.intervalMs = 280,
    this.poseGuides,
    this.waitForFace = false,
    this.allowGallery = true,
    this.autoCapture = false,
  });

  final bool isBurst;
  final int burstCount;
  final int intervalMs;
  final List<String>? poseGuides;
  final bool waitForFace;
  final bool allowGallery;
  final bool autoCapture;

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
  String _liveGuidance = 'Align your face within the oval';
  bool _faceReady = false;
  int _poseIndex = 0;
  Timer? _previewTimer;
  bool _autoCaptureStarted = false;

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
      if (html.window.isSecureContext == false) {
        throw Exception(
          'Camera access requires HTTPS. Open this app on a secure URL.',
        );
      }
      if (mediaDevices == null) {
        throw Exception(
            'This browser does not support camera access. Please use Chrome, Edge, or Safari.');
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
        _startPreviewLoop();
        _maybeAutoCapture();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage =
              'Camera permission is required for face attendance. Allow camera access in your browser, or try again.';
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

  String get _currentPoseGuide {
    final guides = widget.poseGuides;
    if (guides == null || guides.isEmpty) {
      return _liveGuidance;
    }
    final i = _poseIndex.clamp(0, guides.length - 1);
    return guides[i];
  }

  bool get _currentPoseWantsFrontal {
    final text = _currentPoseGuide.toLowerCase();
    return text.contains('look at the camera') || text.contains('look straight');
  }

  void _maybeAutoCapture() {
    if (!widget.autoCapture || _autoCaptureStarted) return;
    if (_isInitializing || _errorMessage != null) return;
    _autoCaptureStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_isCapturingBurst) {
        _capturePhoto();
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
    if (!mounted || _isInitializing || _errorMessage != null || _isCapturingBurst) {
      return;
    }
    final bytes = _grabSingleFrame();
    if (bytes == null) return;
    final assessed = await _assessJpeg(bytes, requireFrontal: _currentPoseWantsFrontal);
    if (!mounted || _isCapturingBurst) return;
    final guidance = assessed?['guidance']?.toString() ?? _currentPoseGuide;
    final ready = assessed?['ok'] == true;
    if (guidance != _liveGuidance || ready != _faceReady) {
      setState(() {
        _liveGuidance = ready ? _currentPoseGuide : guidance;
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

  Future<void> _waitUntilReady({Duration timeout = const Duration(seconds: 10)}) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted && DateTime.now().isBefore(deadline)) {
      final bytes = _grabSingleFrame();
      if (bytes != null) {
        final assessed =
            await _assessJpeg(bytes, requireFrontal: _currentPoseWantsFrontal);
        final ready = assessed?['ok'] == true;
        final guidance = assessed?['guidance']?.toString();
        if (mounted) {
          setState(() {
            _faceReady = ready;
            if (guidance != null && guidance.isNotEmpty) {
              _liveGuidance = ready ? _currentPoseGuide : guidance;
            }
          });
        }
        if (ready) return;
      }
      await Future.delayed(const Duration(milliseconds: 280));
    }
  }

  Future<void> _capturePhoto() async {
    if (widget.isBurst) {
      setState(() {
        _isCapturingBurst = true;
      });

      final frames = <Uint8List>[];
      final guides = widget.poseGuides;
      for (int i = 0; i < widget.burstCount; i++) {
        if (guides != null && guides.isNotEmpty) {
          _poseIndex = i % guides.length;
        }
        if (mounted) {
          setState(() {
            _liveGuidance = _currentPoseGuide;
          });
        }
        if (widget.waitForFace) {
          await _waitUntilReady();
        }
        final frame = _grabSingleFrame();
        if (frame != null) {
          frames.add(frame);
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
      if (widget.waitForFace) {
        await _waitUntilReady();
      }
      final bytes = _grabSingleFrame();
      _stopCamera();
      if (mounted) {
        Navigator.of(context).pop(bytes);
      }
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
    _previewTimer?.cancel();
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Take Member Photo',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        if (!_isCapturingBurst)
                          Text(
                            _liveGuidance,
                            style: TextStyle(
                              fontSize: 12,
                              color: _faceReady
                                  ? const Color(0xFF059669)
                                  : const Color(0xFF64748B),
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
                                    if (widget.allowGallery)
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
                      onPressed: _isCapturingBurst
                          ? null
                          : () {
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
                  if (!widget.autoCapture) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (_isInitializing ||
                                _errorMessage != null ||
                                _isCapturingBurst)
                            ? null
                            : _capturePhoto,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: AppColors.primary,
                          disabledForegroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          elevation: 0,
                        ),
                        child: _isCapturingBurst
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.camera_alt_rounded, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.isBurst
                                        ? 'Verify Face'
                                        : 'Capture Photo',
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ] else if (_isCapturingBurst) ...[
                    const SizedBox(width: 12),
                    const Expanded(
                      flex: 2,
                      child: Text(
                        'Verifying face...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
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
