import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../checkin/presentation/providers/checkin_form_provider.dart';

/// Screen allowing substitute attendees to capture a face photo
/// using the device camera for identity verification.
class PhotoCaptureScreen extends ConsumerStatefulWidget {
  const PhotoCaptureScreen({super.key});

  @override
  ConsumerState<PhotoCaptureScreen> createState() => _PhotoCaptureScreenState();
}

class _PhotoCaptureScreenState extends ConsumerState<PhotoCaptureScreen> {
  final ImagePicker _picker = ImagePicker();
  Uint8List? _capturedBytes;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final existingPhoto = ref.read(checkInFormProvider).photoBase64;
    if (existingPhoto != null) {
      _capturedBytes = ImageUtils.base64ToBytes(existingPhoto);
    }
  }

  Future<void> _takePhoto() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        setState(() {
          _capturedBytes = bytes;
          _isProcessing = false;
        });
      } else {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _errorMessage =
            'Could not access camera. Please allow camera permissions.';
      });
    }
  }

  Future<void> _confirmPhoto() async {
    final captured = _capturedBytes;
    if (captured == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final compressed = await ImageUtils.compressImageBytes(captured);
      final bytes = compressed ?? captured;
      final base64 = ImageUtils.bytesToBase64(bytes);
      if (!mounted) return;
      ref.read(checkInFormProvider.notifier).setPhotoBase64(base64);
      context.pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isProcessing = false;
        _errorMessage = 'Could not process photo. Please retake your selfie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCompact = context.isCompactMobile;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final viewfinderHeight = (screenHeight * 0.38).clamp(200.0, 320.0);

    final hPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    return AppScaffold(
      title: AppStrings.cameraTitle,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: hPadding,
            vertical: isCompact ? 16 : 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveBreakpoints.maxCardWidth,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.cameraInstruction,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: isCompact ? 13 : 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: isCompact ? 16 : 24),

                // Photo Preview Area / Viewfinder
                AppCard(
                  elevation: 4,
                  child: Container(
                    width: double.infinity,
                    height: viewfinderHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppRadius.mdAll,
                      border: Border.all(
                        color: _capturedBytes != null
                            ? AppColors.success
                            : theme.colorScheme.outlineVariant,
                        width: 2,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _isProcessing
                        ? const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CircularProgressIndicator(),
                                SizedBox(height: 16),
                                Text(
                                  'Processing photo...',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          )
                        : _capturedBytes != null
                        ? Image.memory(
                            _capturedBytes!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withAlpha(20),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.face_retouching_natural_rounded,
                                  size: 56,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Face Photo Required',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Please capture a clear photo of your face',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                  ),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight.withAlpha(40),
                      borderRadius: AppRadius.smAll,
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Controls
                if (_capturedBytes != null) ...[
                  AppButton.primary(
                    label: AppStrings.cameraConfirm,
                    icon: Icons.check_circle_rounded,
                    isLoading: _isProcessing,
                    onPressed: _confirmPhoto,
                  ),
                  const SizedBox(height: 12),
                  AppButton.secondary(
                    label: AppStrings.cameraRetake,
                    icon: Icons.refresh_rounded,
                    onPressed: _takePhoto,
                  ),
                ] else ...[
                  AppButton.primary(
                    label: 'Open Camera / Take Photo',
                    icon: Icons.camera_alt_rounded,
                    isLoading: _isProcessing,
                    onPressed: _takePhoto,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
