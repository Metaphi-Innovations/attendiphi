import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// Custom animated overlay for the QR scanner viewfinder.
///
/// Features:
/// - Darkened background cutout focusing on the scan area
/// - Neon corner targeting brackets
/// - Animated scanning laser line
/// - Clear typography instructions
class QrOverlay extends StatefulWidget {
  const QrOverlay({
    super.key,
    this.scanWindowSize = 260.0,
    this.isProcessing = false,
  });

  final double scanWindowSize;
  final bool isProcessing;

  @override
  State<QrOverlay> createState() => _QrOverlayState();
}

class _QrOverlayState extends State<QrOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Cutout background
        CustomPaint(
          size: MediaQuery.sizeOf(context),
          painter: _ScannerCutoutPainter(
            scanWindowSize: widget.scanWindowSize,
          ),
        ),

        // Centered scanning box with animated line and corners
        Center(
          child: SizedBox(
            width: widget.scanWindowSize,
            height: widget.scanWindowSize,
            child: Stack(
              children: [
                // Corner targeting brackets
                const _CornerBrackets(),

                // Animated scan line
                if (!widget.isProcessing)
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Positioned(
                        top: _animationController.value *
                            (widget.scanWindowSize - 4),
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primaryLight.withAlpha(0),
                                AppColors.primaryLight,
                                AppColors.primaryLight.withAlpha(0),
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primaryLight.withAlpha(180),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CornerBrackets extends StatelessWidget {
  const _CornerBrackets();

  static const double bracketLength = 28;
  static const double bracketThickness = 4;
  static const double radius = 12;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _CornerBracketsPainter(
        color: AppColors.primaryLight,
        bracketLength: bracketLength,
        bracketThickness: bracketThickness,
        radius: radius,
      ),
    );
  }
}

class _CornerBracketsPainter extends CustomPainter {
  _CornerBracketsPainter({
    required this.color,
    required this.bracketLength,
    required this.bracketThickness,
    required this.radius,
  });

  final Color color;
  final double bracketLength;
  final double bracketThickness;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = bracketThickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, bracketLength)
        ..lineTo(0, radius)
        ..arcToPoint(Offset(radius, 0), radius: Radius.circular(radius))
        ..lineTo(bracketLength, 0),
      paint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(w - bracketLength, 0)
        ..lineTo(w - radius, 0)
        ..arcToPoint(Offset(w, radius), radius: Radius.circular(radius))
        ..lineTo(w, bracketLength),
      paint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(0, h - bracketLength)
        ..lineTo(0, h - radius)
        ..arcToPoint(Offset(radius, h), radius: Radius.circular(radius))
        ..lineTo(bracketLength, h),
      paint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(w - bracketLength, h)
        ..lineTo(w - radius, h)
        ..arcToPoint(Offset(w, h - radius), radius: Radius.circular(radius))
        ..lineTo(w, h - bracketLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScannerCutoutPainter extends CustomPainter {
  _ScannerCutoutPainter({required this.scanWindowSize});

  final double scanWindowSize;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPaint = Paint()..color = Colors.black.withAlpha(160);

    final left = (size.width - scanWindowSize) / 2;
    final top = (size.height - scanWindowSize) / 2;

    final scanRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, scanWindowSize, scanWindowSize),
      const Radius.circular(16),
    );

    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(scanRect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(path, backgroundPaint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCutoutPainter oldDelegate) =>
      oldDelegate.scanWindowSize != scanWindowSize;
}
