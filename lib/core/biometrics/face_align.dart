/// Geometry helpers for SFace 112×112 letterbox crops (no stretching).
class FaceAlign {
  const FaceAlign._();

  /// Destination rect that fits [srcW]×[srcH] inside [dstSize]² with uniform scale.
  static LetterboxDest letterboxDest({
    required double srcW,
    required double srcH,
    required double dstSize,
  }) {
    final scale = dstSize / (srcW > srcH ? srcW : srcH);
    final dw = srcW * scale;
    final dh = srcH * scale;
    return LetterboxDest(
      dx: (dstSize - dw) / 2,
      dy: (dstSize - dh) / 2,
      dw: dw,
      dh: dh,
    );
  }
}

class LetterboxDest {
  const LetterboxDest({
    required this.dx,
    required this.dy,
    required this.dw,
    required this.dh,
  });

  final double dx;
  final double dy;
  final double dw;
  final double dh;
}
