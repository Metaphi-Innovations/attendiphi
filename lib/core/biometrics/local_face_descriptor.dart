import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Lightweight, Flutter-web-safe face descriptor used when MobileFaceNet
/// (TFLite) cannot run.
///
/// Lighting is equalized, then several face-shaped crops are compared with
/// cosine similarity on regional structure (not raw color). That keeps the
/// same member matching across selfie exposure, background, and mirroring.
class LocalFaceDescriptor {
  LocalFaceDescriptor._(this.variants);

  final List<List<double>> variants;

  static LocalFaceDescriptor? fromBytes(Uint8List bytes) {
    try {
      final raw = img.decodeImage(bytes);
      if (raw == null) return null;
      return _fromImage(img.bakeOrientation(raw), mirror: false);
    } catch (_) {
      return null;
    }
  }

  static double cosineVectors(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    var dot = 0.0;
    for (var i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot.clamp(-1.0, 1.0);
  }

  static double cosine(LocalFaceDescriptor a, LocalFaceDescriptor b) {
    var best = -1.0;
    for (final av in a.variants) {
      for (final bv in b.variants) {
        final s = cosineVectors(av, bv);
        if (s > best) best = s;
      }
    }
    return best;
  }

  static double bestSimilarity({
    required LocalFaceDescriptor probe,
    required LocalFaceDescriptor probeMirrored,
    required LocalFaceDescriptor candidate,
  }) {
    final s1 = cosine(probe, candidate);
    final s2 = cosine(probeMirrored, candidate);
    return s1 > s2 ? s1 : s2;
  }

  static LocalFaceDescriptor? mirroredFromBytes(Uint8List bytes) {
    try {
      final raw = img.decodeImage(bytes);
      if (raw == null) return null;
      return _fromImage(img.bakeOrientation(raw), mirror: true);
    } catch (_) {
      return null;
    }
  }

  static LocalFaceDescriptor? _fromImage(img.Image source, {required bool mirror}) {
    var oriented = source;
    if (mirror) {
      oriented = img.Image.from(source);
      img.flipHorizontal(oriented);
    }

    final variants = <List<double>>[];
    for (final crop in _faceCrops(oriented)) {
      final prepared = _prepare(crop);
      if (prepared == null) continue;
      final vector = _embed(prepared);
      if (vector != null) variants.add(vector);
    }

    if (variants.isEmpty) return null;
    return LocalFaceDescriptor._(variants);
  }

  static img.Image? _prepare(img.Image crop) {
    if (crop.width < 8 || crop.height < 8) return null;
    final sized = img.copyResize(crop, width: 96, height: 96);
    final equalized = _equalizeLuma(sized);
    if (_lumaStd(equalized) < 0.028) return null;
    return equalized;
  }

  static img.Image _equalizeLuma(img.Image src) {
    final n = src.width * src.height;
    if (n <= 1) return src;
    final hist = List<int>.filled(256, 0);
    final luma = List<int>.filled(n, 0);
    var i = 0;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final p = src.getPixel(x, y);
        final yv =
            (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(0, 255);
        luma[i++] = yv;
        hist[yv]++;
      }
    }
    final cdf = List<int>.filled(256, 0);
    var acc = 0;
    var cdfMin = 0;
    for (var b = 0; b < 256; b++) {
      acc += hist[b];
      cdf[b] = acc;
      if (cdfMin == 0 && acc > 0) cdfMin = acc;
    }
    final denom = n - cdfMin;
    if (denom <= 0) return src;

    final out = img.Image(width: src.width, height: src.height);
    i = 0;
    for (var y = 0; y < src.height; y++) {
      for (var x = 0; x < src.width; x++) {
        final eq = ((cdf[luma[i]] - cdfMin) * 255 / denom).round().clamp(0, 255);
        i++;
        out.setPixelRgb(x, y, eq, eq, eq);
      }
    }
    return out;
  }

  static img.Image _centerCrop(img.Image source, double widthFrac, double heightFrac) {
    final cropW = (source.width * widthFrac).round().clamp(1, source.width);
    final cropH = (source.height * heightFrac).round().clamp(1, source.height);
    final x = ((source.width - cropW) / 2).round().clamp(0, source.width - 1);
    final y = ((source.height - cropH) / 2.2).round().clamp(0, source.height - 1);
    return img.copyCrop(
      source,
      x: x,
      y: y,
      width: min(cropW, source.width - x),
      height: min(cropH, source.height - y),
    );
  }

  static double _lumaStd(img.Image face) {
    var sum = 0.0;
    var sumSq = 0.0;
    var n = 0;
    for (var y = 0; y < face.height; y += 2) {
      for (var x = 0; x < face.width; x += 2) {
        final p = face.getPixel(x, y);
        final luma = p.r / 255.0;
        sum += luma;
        sumSq += luma * luma;
        n++;
      }
    }
    if (n == 0) return 0.0;
    final mean = sum / n;
    return sqrt(max(0.0, sumSq / n - mean * mean));
  }

  static List<img.Image> _faceCrops(img.Image source) {
    // Portrait oval (~180×235) plus tighter inner face windows.
    final crops = <img.Image>[
      _centerCrop(source, 0.78, 0.92),
      _centerCrop(source, 0.62, 0.78),
      _centerCrop(source, 0.50, 0.64),
    ];
    final bounds = _skinBounds(source);
    if (bounds != null) {
      crops.insert(0, _cropPad(source, bounds, 0.12));
      crops.insert(0, _cropPad(source, bounds, 0.04));
    }
    return crops;
  }

  static (int, int, int, int)? _skinBounds(img.Image source) {
    var minX = source.width;
    var minY = source.height;
    var maxX = 0;
    var maxY = 0;
    var count = 0;
    final step = max(1, min(source.width, source.height) ~/ 80);
    for (var y = 0; y < source.height; y += step) {
      for (var x = 0; x < source.width; x += step) {
        final p = source.getPixel(x, y);
        if (!_isSkin(p.r.toDouble(), p.g.toDouble(), p.b.toDouble())) {
          continue;
        }
        count++;
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
      }
    }
    final sampled =
        (source.width / step).ceil() * (source.height / step).ceil();
    if (count < sampled * 0.03 || maxX <= minX || maxY <= minY) {
      return null;
    }
    return (minX, minY, maxX - minX, maxY - minY);
  }

  static img.Image _cropPad(
    img.Image source,
    (int, int, int, int) box,
    double padFrac,
  ) {
    final (bx, by, bw, bh) = box;
    final padX = max(0, (bw * padFrac).round());
    final padY = max(0, (bh * padFrac).round());
    final x = max(0, bx - padX);
    final y = max(0, by - padY);
    final w = min(source.width - x, bw + padX * 2);
    final h = min(source.height - y, bh + padY * 2);
    return img.copyCrop(source, x: x, y: y, width: max(1, w), height: max(1, h));
  }

  /// Broad YCbCr + RGB skin test so indoor lighting and South Asian skin
  /// still produce a face box (the previous range dropped most live selfies).
  static bool _isSkin(double r, double g, double b) {
    if (r < 35 || g < 18 || b < 12) return false;
    if (r + 8 < g) return false;
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
    final ycbcr = y > 22 && y < 250 && cb > 70 && cb < 145 && cr > 118 && cr < 188;
    final rgb = r > 55 && (r - g) >= 6 && (r - b) >= 6 && (r - g) < 140;
    return ycbcr || rgb;
  }

  static List<double>? _embed(img.Image face) {
    final parts = <double>[];
    void addRegion(int x, int y, int w, int h, int out) {
      parts.addAll(_zscorePatch(face, x, y, w, h, out, out));
    }

    addRegion(0, 0, 96, 96, 16);
    addRegion(6, 16, 84, 32, 12); // eyes
    addRegion(30, 34, 36, 30, 10); // nose
    addRegion(18, 58, 60, 30, 12); // mouth
    parts.addAll(_differenceHashBits(face));

    var sumSq = 0.0;
    for (final v in parts) {
      sumSq += v * v;
    }
    final norm = sqrt(sumSq);
    if (norm < 1e-8) return null;
    return [for (final v in parts) v / norm];
  }

  static List<double> _zscorePatch(
    img.Image face,
    int x,
    int y,
    int w,
    int h,
    int outW,
    int outH,
  ) {
    final cropped = img.copyCrop(
      face,
      x: x.clamp(0, face.width - 1),
      y: y.clamp(0, face.height - 1),
      width: max(1, min(w, face.width - x)),
      height: max(1, min(h, face.height - y)),
    );
    final small = img.copyResize(cropped, width: outW, height: outH);
    final gray = List<double>.filled(outW * outH, 0.0);
    var sum = 0.0;
    for (var py = 0; py < outH; py++) {
      for (var px = 0; px < outW; px++) {
        final p = small.getPixel(px, py);
        final luma = p.r / 255.0;
        gray[py * outW + px] = luma;
        sum += luma;
      }
    }
    final n = gray.length;
    final mean = sum / n;
    var varSum = 0.0;
    for (var i = 0; i < n; i++) {
      final d = gray[i] - mean;
      gray[i] = d;
      varSum += d * d;
    }
    final std = sqrt(varSum / n);
    if (std > 1e-6) {
      for (var i = 0; i < n; i++) {
        gray[i] /= std;
      }
    }
    return gray;
  }

  static List<double> _differenceHashBits(img.Image face) {
    final small = img.copyResize(face, width: 9, height: 8);
    final bits = List<double>.filled(64, 0.0);
    var i = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final left = small.getPixel(x, y);
        final right = small.getPixel(x + 1, y);
        bits[i++] = left.r > right.r ? 1.0 : -1.0;
      }
    }
    return bits;
  }
}
