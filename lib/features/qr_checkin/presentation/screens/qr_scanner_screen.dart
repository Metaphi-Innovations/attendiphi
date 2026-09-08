import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../../checkin/data/datasources/device_checkin_service.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../providers/qr_scanner_provider.dart';
import '../providers/qr_scanner_state.dart';
import '../widgets/qr_overlay.dart';

/// Screen allowing the user to scan a location QR code to begin attendance check-in.
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with WidgetsBindingObserver {
  late final MobileScannerController _scannerController;
  bool _isTorchOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Pre-warm employee list in background while scanning QR code for instant dropdown loading
    ref.read(employeesStreamProvider);
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_scannerController.value.isInitialized) return;
    if (state == AppLifecycleState.resumed) {
      _scannerController.start();
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _scannerController.stop();
    }
  }

  void _onDetect(BarcodeCapture capture) {
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final rawValue = barcodes.first.rawValue;
    if (rawValue != null && rawValue.isNotEmpty) {
      ref.read(qrScannerProvider.notifier).onQrCodeDetected(rawValue);
    }
  }

  void _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      setState(() => _isTorchOn = !_isTorchOn);
    } catch (_) {}
  }

  void _switchCamera() async {
    try {
      await _scannerController.switchCamera();
    } catch (_) {}
  }

  void _showManualInputDialog() async {
    final controller = TextEditingController(text: '{"locationId": "location_x"}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Enter Location / QR Payload'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter a location ID (e.g. "location_x") or JSON payload for testing without a physical QR code:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: 'QR Payload',
              controller: controller,
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: const Text('Verify & Check In'),
          ),
        ],
      ),
    );

    if (confirmed == true && controller.text.trim().isNotEmpty) {
      ref
          .read(qrScannerProvider.notifier)
          .onQrCodeDetected(controller.text.trim());
    }
  }

  Future<void> _handleQrScannerSuccess(QrScannerSuccess next) async {
    // 1. Check if this device has already submitted attendance for this session
    final deviceService = ref.read(deviceCheckInServiceProvider);
    final existingSubmission = await deviceService.getSubmissionForSession(
      sessionDateStr: next.payload.sessionDateStr,
      locationId: next.location.id,
    );
    if (!mounted) return;
    if (existingSubmission != null) {
      context.push(RouteNames.checkinResult, extra: existingSubmission);
      return;
    }

    // 2. Otherwise navigate to location check with session parameters
    final queryParams = [
      'locationId=${next.location.id}',
      if (next.payload.adminId != null && next.payload.adminId!.isNotEmpty)
        'adminId=${next.payload.adminId}',
      if (next.payload.sessionDateStr != null && next.payload.sessionDateStr!.isNotEmpty)
        'date=${next.payload.sessionDateStr}',
    ].join('&');
    final queryStr = queryParams.isNotEmpty ? '?$queryParams' : '';

    context.push(
      '${RouteNames.locationPermission}$queryStr',
      extra: next.location,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scannerState = ref.watch(qrScannerProvider);

    // Listen to state changes to handle navigation or errors
    ref.listen<QrScannerState>(qrScannerProvider, (prev, next) {
      if (next is QrScannerSuccess) {
        _handleQrScannerSuccess(next);
      }
    });

    final isProcessing = scannerState is QrScannerProcessing;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera scanner preview
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        size: 56,
                        color: Colors.white70,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Camera unavailable or permission denied',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),
                      AppButton.secondary(
                        label: 'Enter Location Manually',
                        onPressed: _showManualInputDialog,
                        fullWidth: false,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Custom animated scanner overlay
          LayoutBuilder(
            builder: (context, constraints) {
              final shortestSide = constraints.maxWidth < constraints.maxHeight
                  ? constraints.maxWidth
                  : constraints.maxHeight;
              final isLandscape = constraints.maxWidth > constraints.maxHeight;
              final scanSize = isLandscape
                  ? (shortestSide * 0.55).clamp(160.0, 260.0)
                  : (shortestSide * 0.70).clamp(200.0, 300.0);
              return QrOverlay(
                scanWindowSize: scanSize,
                isProcessing: isProcessing,
              );
            },
          ),

          // 3. Top Header Bar (Safe Area)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App Logo / Title Pill
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(140),
                          borderRadius: AppRadius.fullAll,
                          border: Border.all(color: Colors.white24),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.qr_code_scanner_rounded,
                              color: AppColors.primaryLight,
                              size: 16,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                AppStrings.appName,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Standee / Venue QR Display Shortcut
                        IconButton(
                          icon: const Icon(
                            Icons.qr_code_2_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Display Venue QR Standee',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withAlpha(140),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () => context.go(RouteNames.venueQr),
                        ),
                        const SizedBox(width: 6),

                        // Admin Login Shortcut
                        IconButton(
                          icon: const Icon(
                            Icons.admin_panel_settings_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: 'Admin Portal',
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withAlpha(140),
                            padding: const EdgeInsets.all(8),
                          ),
                          onPressed: () => context.push(RouteNames.adminLogin),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 4. Instructions below scanning box
          Positioned(
            bottom: MediaQuery.orientationOf(context) == Orientation.landscape
                ? 72
                : 120,
            left: 24,
            right: 24,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AppStrings.qrScannerTitle,
                  style: (MediaQuery.orientationOf(context) == Orientation.landscape
                          ? Theme.of(context).textTheme.titleSmall
                          : Theme.of(context).textTheme.titleLarge)
                      ?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.qrScannerInstruction,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: MediaQuery.orientationOf(context) == Orientation.landscape
                        ? 11
                        : 13,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // 5. Bottom Control Bar (Torch, Switch Camera, Manual Input)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                  vertical: MediaQuery.orientationOf(context) == Orientation.landscape
                      ? 6
                      : AppSpacing.lg,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Torch Button
                    _ControlCircleButton(
                      icon: _isTorchOn
                          ? Icons.flash_on_rounded
                          : Icons.flash_off_rounded,
                      label: 'Flash',
                      isActive: _isTorchOn,
                      onTap: _toggleTorch,
                    ),

                    // Manual Input Button
                    _ControlCircleButton(
                      icon: Icons.keyboard_alt_outlined,
                      label: 'Manual',
                      onTap: _showManualInputDialog,
                    ),

                    // Switch Camera Button
                    _ControlCircleButton(
                      icon: Icons.flip_camera_ios_rounded,
                      label: 'Flip',
                      onTap: _switchCamera,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 6. Processing Modal Overlay
          if (isProcessing)
            Container(
              color: Colors.black.withAlpha(180),
              child: const Center(
                child: MetaPhiLoadingIndicator(),
              ),
            ),

          // 7. Error Banner Modal
          if (scannerState is QrScannerError)
            Positioned(
              bottom: 32,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: AppRadius.mdAll,
                  border: Border.all(color: AppColors.error),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            ErrorHandler.getUserMessage(scannerState.exception),
                            style: const TextStyle(
                              color: AppColors.onSurfaceLight,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            ref.read(qrScannerProvider.notifier).reset();
                          },
                          child: const Text('Try Again'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ControlCircleButton extends StatelessWidget {
  const _ControlCircleButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: isActive
              ? AppColors.primary
              : Colors.black.withAlpha(160),
          shape: const CircleBorder(
            side: BorderSide(color: Colors.white24),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
