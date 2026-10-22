import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/biometrics/biometrics_provider.dart';
import '../../../../core/biometrics/face_matching_config.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/web_inline_face_camera.dart';
import '../../../employee/domain/entities/employee.dart';

/// Live selfie camera widget for real-time face detection and member recognition.
///
/// Web uses [WebInlineFaceCamera] + cloud/SFace matching. Native mobile check-in
/// should use the manual Member tab (camera package is not bundled).
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
  final Future<void> Function(
    Employee member,
    double confidence,
    Uint8List selfieBytes,
  )
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
  bool _isProcessingFrame = false;
  bool _hasMatched = false;

  Uint8List? _webCapturedBytes;
  int _retryCount = 0;
  int _cameraGeneration = 0;

  String _statusMessage = 'Align your face within the frame';
  Color _statusColor = const Color(0xFF64748B);

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(cloudFaceRecognitionServiceProvider).initialize();
      });
    }
  }

  void _scheduleInCameraRetry(String message) {
    _retryCount++;
    setState(() {
      _webCapturedBytes = null;
      _isProcessingFrame = false;
      _hasMatched = false;
      _cameraGeneration++;
      _statusMessage =
          '$message (Retry $_retryCount of ${FaceMatchingConfig.maxVerificationRetries})';
      _statusColor = const Color(0xFFE11D48);
    });
  }

  void _failPermanently(Uint8List? bytes, String? message) {
    setState(() {
      _isProcessingFrame = false;
      _statusMessage = message ?? 'Face not recognized. Please try again.';
      _statusColor = const Color(0xFFE11D48);
    });
    widget.onFaceNotRecognized?.call(bytes, message);
  }

  /// Runs SFace matching on frames captured from the inline webcam.
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

    final enrolledCount = widget.candidates
        .where((c) => c.hasSfaceTemplates && c.isActive)
        .length;
    if (enrolledCount == 0) {
      _failPermanently(
        primaryBytes,
        'No enrolled face biometrics found. A profile photo alone is not enough — in User Management use Take Photo (live camera) to enroll SFace templates, then try again. Or use the Member tab.',
      );
      return;
    }

    try {
      final cloudService = ref.read(cloudFaceRecognitionServiceProvider);
      await cloudService.initialize();

      final photosBase64 = frames.map(ImageUtils.bytesToBase64).toList();
      final decision = await cloudService
          .matchMultiFrameBurst(
            photosBase64: photosBase64,
            candidates: widget.candidates,
            adminId: widget.adminId,
          )
          .timeout(const Duration(seconds: 20));

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
        return;
      }

      final message =
          decision.statusMessage.isNotEmpty
              ? decision.statusMessage
              : 'Face not recognized. Please try again.';

      // Retry in-camera for lighting/angle misses before leaving the Face tab.
      final canRetry =
          _retryCount < FaceMatchingConfig.maxVerificationRetries &&
          (decision.shouldRetry ||
              message.toLowerCase().contains('not recognized') ||
              message.toLowerCase().contains('ambiguous') ||
              message.toLowerCase().contains('inconsistent') ||
              message.toLowerCase().contains('quality') ||
              message.toLowerCase().contains('no face'));

      if (canRetry) {
        AppLogger.info(
          'Face verify soft-fail, in-camera retry '
          '(${_retryCount + 1}/${FaceMatchingConfig.maxVerificationRetries}): $message',
          tag: 'FaceScannerView',
        );
        _scheduleInCameraRetry(message);
        return;
      }

      _failPermanently(primaryBytes, message);
    } catch (e, st) {
      AppLogger.error(
        'Failed to verify inline web selfie: $e',
        error: e,
        stackTrace: st,
        tag: 'FaceScannerView',
      );
      if (!mounted) return;
      final message = e is TimeoutException
          ? 'Verification took too long. Please try again.'
          : 'Could not verify this selfie. Please try again.';
      if (_retryCount < FaceMatchingConfig.maxVerificationRetries) {
        _scheduleInCameraRetry(message);
      } else {
        _failPermanently(primaryBytes, message);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return _buildNativeFallback();
    }
    return _buildWebScannerCard();
  }

  Widget _buildNativeFallback() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.face_retouching_natural_rounded,
            size: 44,
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),
          const Text(
            'Face verification is available on web. Use the Member tab to check in manually on this device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
              height: 1.4,
            ),
          ),
          if (widget.onSwitchToManual != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: widget.onSwitchToManual,
              icon: const Icon(Icons.person_search_rounded, size: 18),
              label: const Text('Choose Member Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }

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
                  'Face Verification',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Look straight at the camera in good light. Hold still when asked.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
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
                          Image.memory(_webCapturedBytes!, fit: BoxFit.cover),
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
                        ],
                      ),
                    )
                  : WebInlineFaceCamera(
                      key: ValueKey('face-cam-$_cameraGeneration'),
                      burstCount: FaceMatchingConfig.burstFrameCount,
                      intervalMs: 220,
                      waitForFace: true,
                      onCaptured: _processWebFrames,
                    ),
            ),
          ),
          if (_statusColor == const Color(0xFFE11D48) &&
              !_hasMatched &&
              _webCapturedBytes == null) ...[
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
          if (widget.onSwitchToManual != null) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onSwitchToManual,
              child: const Text('Use Member tab instead'),
            ),
          ],
        ],
      ),
    );
  }
}
