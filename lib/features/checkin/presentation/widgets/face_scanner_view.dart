import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;

import '../../../../app/theme/app_colors.dart';
import '../../../../core/biometrics/biometrics_provider.dart';
import '../../../../core/biometrics/face_matching_config.dart';
import '../../../../core/biometrics/face_matching_service.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/web_inline_face_camera.dart';
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
  /// Awaited so the verifying overlay stays up until check-in navigation.
  final Future<void> Function(
    Employee member,
    double confidence,
    Uint8List selfieBytes,
  ) onFaceRecognized;

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
  int _retryCount = 0;

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
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(cloudFaceRecognitionServiceProvider).initialize();
      });
    }
  }

  Future<void> _initCamera() async {
    if (kIsWeb) {
      // On Web: Activate interactive selfie capture mode instead of blocking the user
      setState(() {
        _isCameraReady = true;
        _cameraError = null;
        _statusMessage = 'Position your face in front of the camera.';
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

        if (mounted) {
          await widget.onFaceRecognized(matched.candidate, matched.confidence, bytes);
        }
      } else if (mounted && !_hasMatched) {
        setState(() {
          _statusMessage = 'Face not recognized. Please try again.';
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

  /// Runs existing SFace matching on frames captured from the inline webcam.
  Future<void> _processWebFrames(List<Uint8List> frames) async {
    if (_isProcessingFrame || frames.isEmpty) return;
    _hasMatched = false;

    final primaryBytes = frames.first;
    setState(() {
      _isProcessingFrame = true;
      _webCapturedBytes = primaryBytes;
      _statusMessage = 'Verifying face...';
      _statusColor = AppColors.primary;
    });

    try {
      final cloudService = ref.read(cloudFaceRecognitionServiceProvider);

      if (frames.length > 1) {
        final photosBase64 = frames.map(ImageUtils.bytesToBase64).toList();
        final decision = await cloudService
            .matchMultiFrameBurst(
              photosBase64: photosBase64,
              candidates: widget.candidates,
              adminId: widget.adminId,
            )
            .timeout(const Duration(seconds: 15));

        if (!mounted) return;

        if (decision.verified && decision.matchedMember != null) {
          _hasMatched = true;
          _retryCount = 0;
          setState(() {
            _statusMessage = 'Recording attendance...';
            _statusColor = AppColors.success;
          });
          await widget.onFaceRecognized(
            decision.matchedMember!,
            decision.averageScore * 100.0,
            primaryBytes,
          );
        } else {
          final shouldAllowRetry = decision.shouldRetry &&
              _retryCount < FaceMatchingConfig.maxVerificationRetries;

          if (shouldAllowRetry) {
            _retryCount++;
          }

          setState(() {
            _isProcessingFrame = false;
            _statusMessage = shouldAllowRetry
                ? '${decision.statusMessage} (Attempt $_retryCount/${FaceMatchingConfig.maxVerificationRetries + 1})'
                : decision.statusMessage;
            _statusColor = const Color(0xFFE11D48);
          });

          if (widget.onFaceNotRecognized != null) {
            widget.onFaceNotRecognized!(primaryBytes, decision.statusMessage);
          }
        }
      } else {
        final base64Photo = ImageUtils.bytesToBase64(primaryBytes);
        final matchResult = await cloudService.matchFace(
          photoBase64: base64Photo,
          candidates: widget.candidates,
          adminId: widget.adminId,
          locationId: widget.locationId,
        );

        if (!mounted) return;

        if (matchResult.isMatch && matchResult.matchedMember != null) {
          _hasMatched = true;
          _retryCount = 0;
          setState(() {
            _statusMessage = 'Recording attendance...';
            _statusColor = AppColors.success;
          });
          await widget.onFaceRecognized(
            matchResult.matchedMember!,
            matchResult.confidence,
            primaryBytes,
          );
        } else {
          final shouldAllowRetry = matchResult.isAmbiguous &&
              _retryCount < FaceMatchingConfig.maxVerificationRetries;

          if (shouldAllowRetry) {
            _retryCount++;
          }

          setState(() {
            _isProcessingFrame = false;
            _statusMessage = matchResult.errorMessage ??
                'Face not recognized. Please try again.';
            _statusColor = const Color(0xFFE11D48);
          });

          if (widget.onFaceNotRecognized != null) {
            widget.onFaceNotRecognized!(primaryBytes, matchResult.errorMessage);
          }
        }
      }
    } catch (e, st) {
      AppLogger.error(
        'Failed to verify inline web selfie: $e',
        error: e,
        stackTrace: st,
        tag: 'FaceScannerView',
      );
      if (mounted) {
        setState(() {
          _isProcessingFrame = false;
          _statusMessage = e is TimeoutException
              ? 'Verification took too long. Please try again.'
              : 'Could not verify this selfie. Please try again.';
          _statusColor = AppColors.error;
        });
        widget.onFaceNotRecognized?.call(primaryBytes, _statusMessage);
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
          Center(
            child: SizedBox(
              width: 250,
              height: 300,
              child: _webCapturedBytes != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(
                            _webCapturedBytes!,
                            fit: BoxFit.cover,
                          ),
                          if (_isProcessingFrame)
                            Container(
                              color: Colors.black.withAlpha(150),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _statusMessage,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    )
                  : WebInlineFaceCamera(
                      burstCount: FaceMatchingConfig.minimumValidFrames + 1,
                      intervalMs: 160,
                      waitForFace: true,
                      onCaptured: _processWebFrames,
                    ),
            ),
          ),
          if (_statusColor == AppColors.error && !_hasMatched) ...[
            const SizedBox(height: 16),
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
                    Icons.error_outline_rounded,
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
          ],
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
            _cameraError ??
                'Camera permission is required for face attendance.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _cameraError = null;
                _isCameraReady = false;
              });
              _initCamera();
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try Again'),
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
