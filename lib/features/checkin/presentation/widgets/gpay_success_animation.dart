import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Google Pay style animated success checkmark with expanding ripple rings and particle burst.
class GPaySuccessAnimation extends StatefulWidget {
  const GPaySuccessAnimation({
    super.key,
    this.size = 130.0,
    this.color = const Color(0xFF0F9D58), // Google Pay Emerald Green
    this.onAnimationComplete,
  });

  final double size;
  final Color color;
  final VoidCallback? onAnimationComplete;

  @override
  State<GPaySuccessAnimation> createState() => _GPaySuccessAnimationState();
}

class _GPaySuccessAnimationState extends State<GPaySuccessAnimation>
    with TickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  late final AnimationController _checkController;
  late final Animation<double> _checkAnimation;

  late final AnimationController _rippleController;
  late final Animation<double> _rippleAnimation;

  late final AnimationController _particlesController;
  late final Animation<double> _particlesAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Central Circle Elastic Pop
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // 2. Ripple Expansion
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOutQuad,
    );

    // 3. Checkmark Stroke Drawing
    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _checkAnimation = CurvedAnimation(
      parent: _checkController,
      curve: Curves.easeInOutCubic,
    );

    // 4. Confetti Particles Burst
    _particlesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _particlesAnimation = CurvedAnimation(
      parent: _particlesController,
      curve: Curves.easeOutCubic,
    );

    // Sequence the animations
    _scaleController.forward();
    _rippleController.forward();
    _particlesController.forward();

    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) {
        _checkController.forward().then((_) {
          widget.onAnimationComplete?.call();
        });
      }
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _checkController.dispose();
    _rippleController.dispose();
    _particlesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.2,
      height: widget.size * 2.2,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Confetti Particle Burst
          AnimatedBuilder(
            animation: _particlesAnimation,
            builder: (context, child) {
              return CustomPaint(
                size: Size(widget.size * 2.2, widget.size * 2.2),
                painter: _ParticlesPainter(
                  progress: _particlesAnimation.value,
                  baseColor: widget.color,
                ),
              );
            },
          ),

          // 2. Outer Expanding Ripple 1
          AnimatedBuilder(
            animation: _rippleAnimation,
            builder: (context, child) {
              final val = _rippleAnimation.value;
              return Container(
                width: widget.size + (val * 70),
                height: widget.size + (val * 70),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withAlpha(((1 - val) * 70).toInt()),
                ),
              );
            },
          ),

          // 3. Outer Expanding Ripple 2
          AnimatedBuilder(
            animation: _rippleAnimation,
            builder: (context, child) {
              final val = _rippleAnimation.value;
              return Container(
                width: widget.size + (val * 40),
                height: widget.size + (val * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withAlpha(((1 - val) * 110).toInt()),
                ),
              );
            },
          ),

          // 4. Elastic Pop Central Green Circle
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [
                    Color(0xFF34A853), // Google Green
                    Color(0xFF0F9D58),
                  ],
                  center: Alignment(-0.2, -0.2),
                  radius: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0F9D58).withAlpha(100),
                    blurRadius: 24,
                    spreadRadius: 4,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedBuilder(
                animation: _checkAnimation,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _AnimatedCheckmarkPainter(
                      progress: _checkAnimation.value,
                      color: Colors.white,
                      strokeWidth: widget.size * 0.085,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter drawing the animated checkmark stroke.
class _AnimatedCheckmarkPainter extends CustomPainter {
  const _AnimatedCheckmarkPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  final double progress;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;

    // Checkmark coordinates relative to circle center
    final start = Offset(w * 0.28, h * 0.52);
    final mid = Offset(w * 0.44, h * 0.68);
    final end = Offset(w * 0.72, h * 0.38);

    final path = Path();
    path.moveTo(start.dx, start.dy);

    final firstSegmentLength = (mid - start).distance;
    final secondSegmentLength = (end - mid).distance;
    final totalLength = firstSegmentLength + secondSegmentLength;

    final currentLength = totalLength * progress;

    if (currentLength <= firstSegmentLength) {
      final t = currentLength / firstSegmentLength;
      final currentPoint = Offset.lerp(start, mid, t)!;
      path.lineTo(currentPoint.dx, currentPoint.dy);
    } else {
      path.lineTo(mid.dx, mid.dy);
      final t = (currentLength - firstSegmentLength) / secondSegmentLength;
      final currentPoint = Offset.lerp(mid, end, t)!;
      path.lineTo(currentPoint.dx, currentPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnimatedCheckmarkPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

/// Custom painter drawing festive particle dots shooting outward.
class _ParticlesPainter extends CustomPainter {
  const _ParticlesPainter({
    required this.progress,
    required this.baseColor,
  });

  final double progress;
  final Color baseColor;

  static const List<Color> _particleColors = [
    Color(0xFF4285F4), // Google Blue
    Color(0xFFEA4335), // Google Red
    Color(0xFFFBBC05), // Google Yellow
    Color(0xFF34A853), // Google Green
    Color(0xFF9C27B0), // Purple
    Color(0xFF00BCD4), // Cyan
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.0 || progress >= 1.0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.48;
    const count = 16;

    for (int i = 0; i < count; i++) {
      final angle = (i * 2 * math.pi / count) + (i.isEven ? 0.1 : -0.1);
      final distance = (maxRadius * 0.5) + (maxRadius * 0.5 * progress);
      final alpha = ((1.0 - progress) * 255).toInt().clamp(0, 255);

      final color = _particleColors[i % _particleColors.length].withAlpha(alpha);
      final particlePaint = Paint()..color = color;

      final pos = Offset(
        center.dx + (math.cos(angle) * distance),
        center.dy + (math.sin(angle) * distance),
      );

      final radius = (4.0 * (1.0 - (progress * 0.5))).clamp(1.5, 5.0);
      canvas.drawCircle(pos, radius, particlePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlesPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
