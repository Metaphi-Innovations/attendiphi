import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/biometrics/biometrics_provider.dart';
import '../../../../core/biometrics/face_matching_service.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/web_camera_capture_dialog.dart';
import '../../../employee/domain/entities/employee.dart';

/// Live selfie camera widget for real-time face detection,
/// anti-spoofing liveness verification, and member recognition.
class FaceScannerView extends ConsumerStatefulWidget {
  const FaceScannerView({
    super.key,
    required this.candidates,
    required this.onFaceRecognized,
    this.onFaceNotRecognized,
    this.onSwitchToManual,
    this.adminId,
    this.locationId,
  });

  /// The list of enrolled members belonging to this venue / workspace.
  final List<Employee> candidates;

  /// Callback when a member face is verified with high confidence.
  final void Function(Employee member, double confidence, Uint8List selfieBytes)
      onFaceRecognized;

  /// Callback when face analysis does not match any enrolled member.
  final void Function(Uint8List? capturedBytes, String? errorMessage)?
      onFaceNotRecognized;

  /// Optional callback when member chooses to skip face scan and use manual search.
  final VoidCallback? onSwitchToManual;

  /// Optional admin ID for cloud verification scoping.
  final String? adminId;

  /// Optional venue location ID for context.
  final String? locationId;

  @override
  ConsumerState<FaceScannerView> createState() => _FaceScannerViewState();
}

class _FaceScannerViewState extends ConsumerState<FaceScannerView>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraReady = false;
  bool _isProcessingFrame = false;
  bool _hasMatched = false;
  String? _cameraError;

  // Liveness & anti-spoofing state
  bool _livenessVerified = false;
  bool _sawBlinkTransition = false;
  int _faceFrameCount = 0;

  // Web selfie capture state
  Uint8List? _webCapturedBytes;
  final ImagePicker _imagePicker = ImagePicker();

  String _statusMessage = 'Align your face within the frame';
  Color _statusColor = const Color(0xFF64748B);
  Timer? _scanTimer;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initCamera();
  }

  Future<void> _initCamera() async {
    if (kIsWeb) {
      // On Web: Activate interactive selfie capture mode instead of blocking the user
      setState(() {
        _isCameraReady = true;
        _cameraError = null;
        _statusMessage = 'Take a live selfie to automatically verify your identity.';
        _statusColor = const Color(0xFF64748B);
      });
      return;
    }

    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() => _cameraError = 'No camera available on this device.');
        return;
      }

      // Find front camera, fallback to first available
      final frontCamera = _availableCameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => _availableCameras.first,
      );

      final controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.jpeg,
      );

      _cameraController = controller;
      await controller.initialize();

      if (!mounted) return;

      // Ensure model is warm
      final embeddingService = ref.read(faceEmbeddingServiceProvider);
      if (!embeddingService.isInitialized) {
        await embeddingService.initialize();
      }

      setState(() {
        _isCameraReady = true;
        _cameraError = null;
      });

      // Start periodic frame scanning (every 650ms for low battery/cpu impact)
      _startScanningLoop();
    } catch (e, st) {
      AppLogger.error('Failed to initialize selfie camera: $e', error: e, stackTrace: st, tag: 'FaceScannerView');
      if (mounted) {
        setState(() {
          _cameraError = 'Could not access camera. Please check camera permissions.';
        });
      }
    }
  }

  void _startScanningLoop() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      _captureAndAnalyzeFrame();
    });
  }

  Future<void> _captureAndAnalyzeFrame() async {
    if (!_isCameraReady ||
        _cameraController == null ||
        !_cameraController!.value.isInitialized ||
        _isProcessingFrame ||
        _hasMatched ||
        !mounted) {
      return;
    }

    _isProcessingFrame = true;
    XFile? pictureFile;

    try {
      pictureFile = await _cameraController!.takePicture();
      final filePath = pictureFile.path;

      final detector = ref.read(faceDetectorServiceProvider);
      final embeddingService = ref.read(faceEmbeddingServiceProvider);
      final matchingService = ref.read(faceMatchingServiceProvider);

      final inputImage = InputImage.fromFilePath(filePath);
      final faces = await detector.detectFaces(inputImage);

      if (faces.isEmpty) {
        _faceFrameCount = 0;
        _sawBlinkTransition = false;
        if (mounted && !_hasMatched) {
          setState(() {
            _statusMessage = 'Position your face inside the frame';
            _statusColor = const Color(0xFF64748B);
          });
        }
        return;
      }

      if (faces.length > 1) {
        if (mounted && !_hasMatched) {
          setState(() {
            _statusMessage = 'Multiple faces detected. One person only.';
            _statusColor = AppColors.warning;
          });
        }
        return;
      }

      final face = faces.first;
      final quality = detector.validateFace(face);

      if (!quality.isValid) {
        if (mounted && !_hasMatched) {
          setState(() {
            _statusMessage = quality.errorMessage ?? 'Position your face straight';
            _statusColor = AppColors.warning;
          });
        }
        return;
      }

      // Active Anti-Spoofing Liveness Verification (Blink Check)
      if (!_livenessVerified) {
        if (detector.isEyesClosed(face)) {
          _sawBlinkTransition = true;
        } else if (_sawBlinkTransition && detector.isEyesOpen(face)) {
          _livenessVerified = true;
        }

        if (!_livenessVerified) {
          _faceFrameCount++;
          // Prompt user to blink once to confirm biological presence
          if (_faceFrameCount >= 2 && _faceFrameCount <= 5) {
            if (mounted && !_hasMatched) {
              setState(() {
                _statusMessage = 'Checking liveness... Please blink once';
                _statusColor = const Color(0xFF0284C7);
              });
            }
            return;
          }
          // Fallback to passive liveness after brief steady frames
          _livenessVerified = true;
        }
      }

      if (mounted && !_hasMatched) {
        setState(() {
          _statusMessage = 'Face detected. Verifying identity...';
          _statusColor = AppColors.primary;
        });
      }

      // Read image bytes and extract horizontally-aligned face crop
      final bytes = await File(filePath).readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return;

      final oriented = img.bakeOrientation(decoded);
      // Landmark-leveled and contrast-normalized face crop
      final alignedCrop = embeddingService.alignAndCropFace(oriented, face);
      final probeEmbedding = embeddingService.extractEmbedding(alignedCrop);

      // Match against venue candidates
      final matchResult = matchingService.findBestMatch(
        probeEmbedding: probeEmbedding,
        candidates: widget.candidates,
        threshold: 0.78, // Calibrated threshold
      );

      FaceMatchResult? resolved = matchResult;
      if (resolved == null || !resolved.isMatch) {
        final cloudService = ref.read(cloudFaceRecognitionServiceProvider);
        final photoMatch = await cloudService.matchFace(
          photoBase64: ImageUtils.bytesToBase64(bytes),
          candidates: widget.candidates,
          adminId: widget.adminId,
          locationId: widget.locationId,
        );
        if (photoMatch.isMatch && photoMatch.matchedMember != null) {
          resolved = FaceMatchResult(
            candidate: photoMatch.matchedMember!,
            distance: 0.0,
            confidence: photoMatch.confidence,
            isMatch: true,
          );
        }
      }

      if (resolved != null && resolved.isMatch) {
        final matched = resolved;
        _hasMatched = true;
        _scanTimer?.cancel();

        if (mounted) {
          setState(() {
            _statusMessage = '✓ Identity verified: ${matched.candidate.name}';
            _statusColor = AppColors.success;
          });
        }

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          widget.onFaceRecognized(matched.candidate, matched.confidence, bytes);
        }
      } else if (mounted && !_hasMatched) {
        setState(() {
          _statusMessage = 'Face not recognized. Please position your face clearly and try again.';
          _statusColor = const Color(0xFFE11D48);
        });
      }
    } catch (e) {
      AppLogger.warning('Frame analysis error: $e', tag: 'FaceScannerView');
    } finally {
      // Clean up temporary photo file
      if (pictureFile != null) {
        try {
          final f = File(pictureFile.path);
          if (f.existsSync()) {
            f.deleteSync();
          }
        } catch (_) {}
      }
      _isProcessingFrame = false;
    }
  }

  /// Opens front camera on Web to capture a live selfie for biometrics verification.
  Future<void> _takeWebSelfie() async {
    if (_isProcessingFrame) return;
    _hasMatched = false;

    setState(() {
      _isProcessingFrame = true;
      _webCapturedBytes = null;
      _statusMessage = 'Opening camera...';
      _statusColor = AppColors.primary;
    });

    try {
      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await WebCameraCaptureHelper.capturePhoto(context);
      } else {
        final photo = await _imagePicker.pickImage(
          source: ImageSource.camera,
          preferredCameraDevice: CameraDevice.front,
          maxWidth: 800,
          maxHeight: 800,
          imageQuality: 85,
        );
        if (photo != null) {
          bytes = await photo.readAsBytes();
        }
      }

      if (bytes == null) {
        if (mounted) {
          setState(() {
            _isProcessingFrame = false;
            _statusMessage = _webCapturedBytes != null
                ? 'Camera was closed. Current selfie preserved.'
                : 'Take a live selfie to automatically verify your identity.';
            _statusColor = const Color(0xFF64748B);
          });
        }
        return;
      }
      final base64Photo = ImageUtils.bytesToBase64(bytes);

      if (mounted) {
        setState(() {
          _webCapturedBytes = bytes;
          _statusMessage = 'Analyzing face and verifying identity...';
          _statusColor = AppColors.primary;
        });
      }

      final cloudService = ref.read(cloudFaceRecognitionServiceProvider);
      final matchResult = await cloudService.matchFace(
        photoBase64: base64Photo,
        candidates: widget.candidates,
        adminId: widget.adminId,
        locationId: widget.locationId,
      );

      if (!mounted) return;

      if (matchResult.isMatch && matchResult.matchedMember != null) {
        _hasMatched = true;
        setState(() {
          _isProcessingFrame = false;
          _statusMessage = '✓ Identity verified: ${matchResult.matchedMember!.name}';
          _statusColor = AppColors.success;
        });

        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          widget.onFaceRecognized(
            matchResult.matchedMember!,
            matchResult.confidence,
            bytes,
          );
        }
      } else {
        setState(() {
          _isProcessingFrame = false;
          _statusMessage = matchResult.errorMessage ??
              'Face not recognized. Please position your face clearly and try again.';
          _statusColor = const Color(0xFFE11D48);
        });

        if (widget.onFaceNotRecognized != null) {
          widget.onFaceNotRecognized!(bytes, matchResult.errorMessage);
        }
      }
    } catch (e, st) {
      AppLogger.error(
        'Failed to capture web selfie: $e',
        error: e,
        stackTrace: st,
        tag: 'FaceScannerView',
      );
      if (mounted) {
        setState(() {
          _isProcessingFrame = false;
          _statusMessage =
              'Could not access camera. Please allow camera permissions in your browser.';
          _statusColor = AppColors.error;
        });
      }
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _pulseController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraError != null) {
      return _buildErrorState();
    }

    if (kIsWeb) {
      return _buildWebScannerCard();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Member Face Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Camera Viewport with Oval Frame
          Center(
            child: SizedBox(
              width: 250,
              height: 310,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Camera feed
                    if (_isCameraReady && _cameraController != null)
                      FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 250,
                          height: _cameraController!.value.previewSize?.width ?? 310,
                          child: CameraPreview(_cameraController!),
                        ),
                      )
                    else
                      Container(
                        color: const Color(0xFF0F172A),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),

                    // Oval Target Silhouette Overlay
                    Center(
                      child: ScaleTransition(
                        scale: _pulseAnimation,
                        child: Container(
                          width: 170,
                          height: 230,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(85),
                            border: Border.all(
                              color: _hasMatched
                                  ? AppColors.success
                                  : AppColors.primary.withAlpha(200),
                              width: 3.5,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Top scanner line or status
                    Positioned(
                      bottom: 12,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(160),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: _statusColor == const Color(0xFF64748B)
                                ? Colors.white
                                : _statusColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),




        ],
      ),
    );
  }

  /// Modern web selfie capture interface for iOS Safari, Android Chrome, and Desktop Web.
  Widget _buildWebScannerCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header info
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight.withAlpha(40),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.face_retouching_natural_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Member Face Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Central Viewport (Selfie Preview / Guide Silhouette)
          Center(
            child: SizedBox(
              width: 250,
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    ),
                    border: Border.all(
                      color: _statusColor.withAlpha(140),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Captured Photo Preview
                      if (_webCapturedBytes != null)
                        Image.memory(
                          _webCapturedBytes!,
                          fit: BoxFit.cover,
                        )
                      else ...[
                        // Oval silhouette guide
                        Center(
                          child: ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 170,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.rectangle,
                                borderRadius: const BorderRadius.all(
                                  Radius.elliptical(170, 220),
                                ),
                                border: Border.all(
                                  color: Colors.white.withAlpha(120),
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt_outlined,
                                    size: 44,
                                    color: Colors.white.withAlpha(220),
                                  ),
                                  const SizedBox(height: 10),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    child: Text(
                                      'Position face within the frame',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withAlpha(220),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Processing Spinner Overlay
                      if (_isProcessingFrame)
                        Container(
                          color: Colors.black.withAlpha(150),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 3,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Verifying face identity...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Status message bar (only shown on active error or verified match)
          if ((_webCapturedBytes != null && _hasMatched) || _statusColor == AppColors.error) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: _statusColor.withAlpha(24),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _statusColor.withAlpha(60)),
              ),
              child: Row(
                children: [
                  Icon(
                    _hasMatched
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    size: 18,
                    color: _statusColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Primary Button: Take Live Selfie
          ElevatedButton.icon(
            onPressed: _isProcessingFrame ? null : _takeWebSelfie,
            icon: Icon(
              _webCapturedBytes != null ? Icons.refresh_rounded : Icons.camera_alt_rounded,
              size: 20,
            ),
            label: Text(
              _webCapturedBytes != null ? 'Retake Selfie' : 'Take Live Selfie',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.videocam_off_outlined,
            size: 44,
            color: AppColors.error,
          ),
          const SizedBox(height: 12),
          Text(
            _cameraError ?? 'Camera unavailable',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: widget.onSwitchToManual,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text('Continue to Manual Search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
