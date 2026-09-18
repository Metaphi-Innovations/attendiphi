import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../../features/employee/domain/entities/employee.dart';
import '../logger/app_logger.dart';
import '../utils/image_utils.dart';
import 'face_matching_service.dart';

/// Result of a face recognition attempt.
class CloudFaceMatchResult {
  const CloudFaceMatchResult({
    required this.isMatch,
    this.matchedMember,
    this.confidence = 0.0,
    this.extractedEmbedding,
    this.errorMessage,
  });

  final bool isMatch;
  final Employee? matchedMember;
  final double confidence;
  final List<double>? extractedEmbedding;
  final String? errorMessage;
}

/// Service providing client-side and cloud-assisted face recognition for Flutter Web clients.
/// Matches captured live selfies against enrolled chapter members using multi-feature facial signatures
/// and vector biometrics without requiring server-side Cloud Function billing.
class CloudFaceRecognitionService {
  CloudFaceRecognitionService({
    FaceMatchingService? matchingService,
    http.Client? httpClient,
    String? functionUrl,
  })  : _matchingService = matchingService ?? FaceMatchingService(),
        _httpClient = httpClient ?? http.Client(),
        _functionUrl = functionUrl ??
            'https://us-central1-qr-checkin-dev.cloudfunctions.net/matchMemberFace';

  final FaceMatchingService _matchingService;
  final http.Client _httpClient;
  final String _functionUrl;

  Future<Uint8List?> _resolvePhotoBytes(String photoUrl) async {
    try {
      final trimmed = photoUrl.trim();
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        final res = await _httpClient
            .get(Uri.parse(trimmed))
            .timeout(const Duration(seconds: 12));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          return res.bodyBytes;
        }
      }
      return ImageUtils.base64ToBytes(trimmed);
    } catch (_) {}
    return null;
  }

  /// Sends a captured photo to identify the member.
  /// Matches against [candidates] using profile photos and/or biometric vectors.
  Future<CloudFaceMatchResult> matchFace({
    required String photoBase64,
    required List<Employee> candidates,
    String? adminId,
    String? locationId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    // 1. Client-side visual match against enrolled member photos (web enrollment
    // stores photos only — no MobileFaceNet embeddings).
    final candidatesWithPhoto = candidates
        .where((c) => c.photoUrl != null && c.photoUrl!.trim().isNotEmpty && c.isActive)
        .toList();

    if (candidatesWithPhoto.isNotEmpty) {
      final probeBytes = ImageUtils.base64ToBytes(photoBase64);
      if (probeBytes != null) {
        final probeBank = _FaceSignatureBank.fromBytes(probeBytes);
        if (probeBank != null && probeBank.hasValidFeatures) {
          Employee? bestCandidate;
          double bestSimilarity = -1.0;
          double secondBestSimilarity = -1.0;
          var scoredCount = 0;

          final resolved = await Future.wait(
            candidatesWithPhoto.map((candidate) async {
              final bytes = await _resolvePhotoBytes(candidate.photoUrl!);
              return (candidate, bytes);
            }),
          );

          for (final entry in resolved) {
            final candBytes = entry.$2;
            if (candBytes == null) continue;
            final candBank = _FaceSignatureBank.fromBytes(candBytes);
            if (candBank == null || !candBank.hasValidFeatures) continue;

            final sim = probeBank.maxSimilarity(candBank);
            scoredCount++;
            if (sim > bestSimilarity) {
              secondBestSimilarity = bestSimilarity;
              bestSimilarity = sim;
              bestCandidate = entry.$1;
            } else if (sim > secondBestSimilarity) {
              secondBestSimilarity = sim;
            }
          }

          // 1:N identification: accept the unique nearest enrolled photo.
          // Same person (tight roster headshot vs wide live selfie) often
          // scores ~0.58–0.88. Wrong person should lose on margin, not on
          // an absolute bar that also rejects the true member.
          const double likelyMatch = 0.58;
          const double strongMatch = 0.70;
          const double soloMatch = 0.72;
          const double minMargin = 0.03;

          final margin = bestSimilarity -
              (secondBestSimilarity < 0 ? 0.0 : secondBestSimilarity);

          AppLogger.info(
            'Visual match analysis: best=${bestCandidate?.name} ($bestSimilarity), runnerUp=$secondBestSimilarity, margin=$margin, scored=$scoredCount',
            tag: 'CloudFaceRecognitionService',
          );

          if (bestCandidate != null) {
            final unique = scoredCount < 2 ||
                margin >= minMargin ||
                bestSimilarity >= strongMatch;
            final meetsScore = scoredCount >= 2
                ? bestSimilarity >= likelyMatch
                : bestSimilarity >= soloMatch;

            if (unique && meetsScore) {
              final confidence = (bestSimilarity * 100.0).clamp(78.0, 99.0);
              AppLogger.info(
                '✓ Client Face Match found: ${bestCandidate.name} (confidence: ${confidence.toStringAsFixed(1)}%)',
                tag: 'CloudFaceRecognitionService',
              );
              return CloudFaceMatchResult(
                isMatch: true,
                matchedMember: bestCandidate,
                confidence: confidence,
              );
            }
          }
        }
      }
    }

    // 2. Candidates with enrolled 192-d biometric vectors
    final enrolledCandidates = candidates
        .where((c) => c.faceEmbedding != null && c.faceEmbedding!.isNotEmpty && c.isActive)
        .toList();

    if (enrolledCandidates.isNotEmpty) {
      try {
        final payload = {
          'photoBase64': photoBase64,
          'adminId': adminId,
          'locationId': locationId,
          'candidates': enrolledCandidates.map((c) => {
            'id': c.id,
            'name': c.name,
            'faceEmbedding': c.faceEmbedding,
          }).toList(),
        };

        final response = await _httpClient
            .post(
              Uri.parse(_functionUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(payload),
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;

          final bool matched = data['matched'] == true;
          final String? matchedId = data['memberId']?.toString();
          final double confidence = (data['confidence'] as num?)?.toDouble() ?? 0.0;

          if (matched && matchedId != null) {
            Employee? found;
            for (final c in enrolledCandidates) {
              if (c.id == matchedId) {
                found = c;
                break;
              }
            }
            if (found != null) {
              return CloudFaceMatchResult(
                isMatch: true,
                matchedMember: found,
                confidence: confidence,
              );
            }
          }

          if (data['embedding'] is List) {
            final List<double> probeEmbedding = (data['embedding'] as List)
                .map((e) => (e as num).toDouble())
                .toList();

            final localMatch = _matchingService.findBestMatch(
              probeEmbedding: probeEmbedding,
              candidates: enrolledCandidates,
              threshold: 0.78,
            );

            if (localMatch != null && localMatch.isMatch) {
              return CloudFaceMatchResult(
                isMatch: true,
                matchedMember: localMatch.candidate,
                confidence: localMatch.confidence,
                extractedEmbedding: probeEmbedding,
              );
            }
          }

          return CloudFaceMatchResult(
            isMatch: false,
            errorMessage: data['message']?.toString() ?? 'Face not recognized in this chapter.',
          );
        } else {
          return CloudFaceMatchResult(
            isMatch: false,
            errorMessage: 'Server face check unavailable (${response.statusCode}).',
          );
        }
      } catch (_) {}
    }

    return const CloudFaceMatchResult(
      isMatch: false,
      errorMessage: 'Face not recognized in this chapter.',
    );
  }

  void dispose() {
    _httpClient.close();
  }
}

/// Bank of facial signatures from multiple crops and a mirrored copy so a
/// live selfie can match an enrolled portrait despite pose, crop, and
/// front-camera mirroring.
class _FaceSignatureBank {
  const _FaceSignatureBank(this._signatures);

  final List<_FaceSignature> _signatures;

  bool get hasValidFeatures =>
      _signatures.any((s) => s.hasValidFeatures);

  static _FaceSignatureBank? fromBytes(Uint8List bytes) {
    try {
      final raw = img.decodeImage(bytes);
      if (raw == null) return null;
      final oriented = img.bakeOrientation(raw);
      final signatures = <_FaceSignature>[];

      void addFrom(img.Image source) {
        final rois = <img.Image>[
          source,
          _faceRoi(source),
          _applyCrop(source, (0.18, 0.10, 0.64, 0.78)),
          _applyCrop(source, (0.24, 0.14, 0.52, 0.62)),
        ];
        for (final roi in rois) {
          final extracted = _FaceSignature.fromImage(roi);
          if (extracted != null) signatures.add(extracted);
        }
      }

      addFrom(oriented);
      final mirrored = img.Image.from(oriented);
      img.flipHorizontal(mirrored);
      addFrom(mirrored);

      if (signatures.isEmpty) return null;
      return _FaceSignatureBank(signatures);
    } catch (_) {
      return null;
    }
  }

  static img.Image _faceRoi(img.Image source) {
    var minX = source.width;
    var minY = source.height;
    var maxX = 0;
    var maxY = 0;
    var count = 0;
    final step = max(1, min(source.width, source.height) ~/ 90);
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
    if (count < sampled * 0.04 || maxX <= minX || maxY <= minY) {
      return _applyCrop(source, (0.18, 0.10, 0.64, 0.78));
    }
    final padX = max(8, ((maxX - minX) * 0.18).round());
    final padY = max(8, ((maxY - minY) * 0.22).round());
    final x = max(0, minX - padX);
    final y = max(0, minY - padY);
    final w = min(source.width - x, (maxX - minX) + padX * 2);
    final h = min(source.height - y, (maxY - minY) + padY * 2);
    return img.copyCrop(source, x: x, y: y, width: max(1, w), height: max(1, h));
  }

  static bool _isSkin(double r, double g, double b) {
    final y = 0.299 * r + 0.587 * g + 0.114 * b;
    final cb = 128 - 0.168736 * r - 0.331264 * g + 0.5 * b;
    final cr = 128 + 0.5 * r - 0.418688 * g - 0.081312 * b;
    return y > 40 && cb > 77 && cb < 135 && cr > 130 && cr < 180;
  }

  static img.Image _applyCrop(
    img.Image source,
    (double, double, double, double) window,
  ) {
    final x = (source.width * window.$1).round().clamp(0, source.width - 1);
    final y = (source.height * window.$2).round().clamp(0, source.height - 1);
    final w = max(1, (source.width * window.$3).round());
    final h = max(1, (source.height * window.$4).round());
    return img.copyCrop(
      source,
      x: x,
      y: y,
      width: min(w, source.width - x),
      height: min(h, source.height - y),
    );
  }

  double maxSimilarity(_FaceSignatureBank other) {
    final perProbe = <double>[];
    var peak = 0.0;
    for (final a in _signatures) {
      if (!a.hasValidFeatures) continue;
      var best = 0.0;
      for (final b in other._signatures) {
        if (!b.hasValidFeatures) continue;
        final sim = a.compareWith(b);
        if (sim > best) best = sim;
      }
      perProbe.add(best);
      if (best > peak) peak = best;
    }
    if (perProbe.isEmpty) return 0.0;
    perProbe.sort();
    final median = perProbe[perProbe.length ~/ 2];
    // Peak is the correctly aligned face crop (roster headshot vs live selfie).
    // Median only slightly regularizes so one noisy window cannot dominate.
    return (0.80 * peak + 0.20 * median).clamp(0.0, 1.0);
  }
}

/// Spatial HOG + LBP + structural profile of a single face crop.
class _FaceSignature {
  final List<double> hog;
  final List<double> lbp;
  final List<double> structure;
  final int dHash;
  final bool hasValidFeatures;

  const _FaceSignature({
    required this.hog,
    required this.lbp,
    required this.structure,
    required this.dHash,
    required this.hasValidFeatures,
  });

  static _FaceSignature? fromImage(img.Image face) {
    try {
      final resized = img.copyResize(face, width: 64, height: 64);

      final gray = List<double>.filled(64 * 64, 0.0);
      for (int y = 0; y < 64; y++) {
        for (int x = 0; x < 64; x++) {
          final p = resized.getPixel(x, y);
          gray[y * 64 + x] = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
        }
      }

      _histogramEqualize(gray);

      final meanLuma = gray.reduce((a, b) => a + b) / (64 * 64);
      double varSum = 0.0;
      for (final l in gray) {
        final d = l - meanLuma;
        varSum += d * d;
      }
      final stdDev = sqrt(varSum / (64 * 64));

      final hog = List<double>.filled(64 * 8, 0.0);
      double totalGradEnergy = 0.0;
      int gradCount = 0;

      for (int y = 1; y < 63; y++) {
        final cellY = y ~/ 8;
        for (int x = 1; x < 63; x++) {
          final cellX = x ~/ 8;
          final cellIdx = (cellY * 8 + cellX) * 8;

          final dx = gray[y * 64 + (x + 1)] - gray[y * 64 + (x - 1)];
          final dy = gray[(y + 1) * 64 + x] - gray[(y - 1) * 64 + x];
          final mag = sqrt(dx * dx + dy * dy);

          totalGradEnergy += mag;
          gradCount++;

          if (mag > 0.01) {
            var angle = atan2(dy, dx);
            if (angle < 0) angle += pi;
            final bin = ((angle / pi) * 8).floor().clamp(0, 7);
            hog[cellIdx + bin] += mag;
          }
        }
      }

      final avgGrad = gradCount > 0 ? totalGradEnergy / gradCount : 0.0;
      final bool hasFeatures = stdDev >= 0.02 && avgGrad >= 0.008;

      for (int c = 0; c < 64; c++) {
        final offset = c * 8;
        double cellNorm = 0.0;
        for (int b = 0; b < 8; b++) {
          final v = hog[offset + b];
          cellNorm += v * v;
        }
        cellNorm = sqrt(cellNorm);
        if (cellNorm > 0.0001) {
          for (int b = 0; b < 8; b++) {
            hog[offset + b] /= cellNorm;
          }
        }
      }

      double globalHogNorm = 0.0;
      for (final v in hog) {
        globalHogNorm += v * v;
      }
      globalHogNorm = sqrt(globalHogNorm);
      if (globalHogNorm > 0.0001) {
        for (int i = 0; i < hog.length; i++) {
          hog[i] /= globalHogNorm;
        }
      }

      final lbp = List<double>.filled(64 * 8, 0.0);
      for (int y = 1; y < 63; y++) {
        final cellY = y ~/ 8;
        for (int x = 1; x < 63; x++) {
          final cellX = x ~/ 8;
          final cellOffset = (cellY * 8 + cellX) * 8;
          final c = gray[y * 64 + x];

          int bits = 0;
          if (gray[(y - 1) * 64 + (x - 1)] >= c) bits++;
          if (gray[(y - 1) * 64 + x] >= c) bits++;
          if (gray[(y - 1) * 64 + (x + 1)] >= c) bits++;
          if (gray[y * 64 + (x + 1)] >= c) bits++;
          if (gray[(y + 1) * 64 + (x + 1)] >= c) bits++;
          if (gray[(y + 1) * 64 + x] >= c) bits++;
          if (gray[(y + 1) * 64 + (x - 1)] >= c) bits++;
          if (gray[y * 64 + (x - 1)] >= c) bits++;

          final bin = (bits - 1).clamp(0, 7);
          lbp[cellOffset + bin] += 1.0;
        }
      }

      double lbpNorm = 0.0;
      for (final v in lbp) {
        lbpNorm += v * v;
      }
      lbpNorm = sqrt(lbpNorm);
      if (lbpNorm > 0.0001) {
        for (int i = 0; i < lbp.length; i++) {
          lbp[i] /= lbpNorm;
        }
      }

      final small = img.copyResize(face, width: 32, height: 32);
      final structure = List<double>.filled(32 * 32, 0.0);
      double structSum = 0.0;
      for (int sy = 0; sy < 32; sy++) {
        for (int sx = 0; sx < 32; sx++) {
          final p = small.getPixel(sx, sy);
          final luma = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b) / 255.0;
          structure[sy * 32 + sx] = luma;
          structSum += luma;
        }
      }

      final structMean = structSum / (32 * 32);
      double structVar = 0.0;
      for (int i = 0; i < structure.length; i++) {
        structure[i] -= structMean;
        structVar += structure[i] * structure[i];
      }
      final structStd = sqrt(structVar / (32 * 32));
      if (structStd > 0.0001) {
        for (int i = 0; i < structure.length; i++) {
          structure[i] /= structStd;
        }
      }

      return _FaceSignature(
        hog: hog,
        lbp: lbp,
        structure: structure,
        dHash: _differenceHash(face),
        hasValidFeatures: hasFeatures,
      );
    } catch (_) {
      return null;
    }
  }

  static void _histogramEqualize(List<double> gray) {
    final hist = List<int>.filled(256, 0);
    for (final v in gray) {
      hist[(v * 255.0).round().clamp(0, 255)]++;
    }
    final cdf = List<int>.filled(256, 0);
    cdf[0] = hist[0];
    for (int i = 1; i < 256; i++) {
      cdf[i] = cdf[i - 1] + hist[i];
    }
    var cdfMin = 0;
    for (int i = 0; i < 256; i++) {
      if (cdf[i] > 0) {
        cdfMin = cdf[i];
        break;
      }
    }
    final n = gray.length;
    final denom = max(1, n - cdfMin);
    for (int i = 0; i < gray.length; i++) {
      final bin = (gray[i] * 255.0).round().clamp(0, 255);
      gray[i] = ((cdf[bin] - cdfMin) / denom).clamp(0.0, 1.0);
    }
  }

  static int _differenceHash(img.Image face) {
    final small = img.copyResize(face, width: 9, height: 8);
    var hash = 0;
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final left = small.getPixel(x, y);
        final right = small.getPixel(x + 1, y);
        final lLuma = 0.299 * left.r + 0.587 * left.g + 0.114 * left.b;
        final rLuma = 0.299 * right.r + 0.587 * right.g + 0.114 * right.b;
        hash = (hash << 1) | (lLuma > rLuma ? 1 : 0);
      }
    }
    return hash;
  }

  static int _hamming(int a, int b) {
    final x = a ^ b;
    var bits = 0;
    for (var i = 0; i < 64; i++) {
      bits += (x >> i) & 1;
    }
    return bits;
  }

  double compareWith(_FaceSignature other) {
    if (!hasValidFeatures || !other.hasValidFeatures) {
      return 0.0;
    }

    double hogDot = 0.0;
    for (int i = 0; i < hog.length; i++) {
      hogDot += hog[i] * other.hog[i];
    }
    final hogSim = hogDot.clamp(0.0, 1.0);

    double lbpDot = 0.0;
    for (int i = 0; i < lbp.length; i++) {
      lbpDot += lbp[i] * other.lbp[i];
    }
    final lbpSim = lbpDot.clamp(0.0, 1.0);

    double structDot = 0.0;
    for (int i = 0; i < structure.length; i++) {
      structDot += structure[i] * other.structure[i];
    }
    final r = (structDot / structure.length).clamp(-1.0, 1.0);
    final structSim = ((r + 1.0) / 2.0).clamp(0.0, 1.0);

    final dHashSim = (1.0 - (_hamming(dHash, other.dHash) / 64.0)).clamp(0.0, 1.0);

    return (0.30 * hogSim + 0.18 * lbpSim + 0.30 * structSim + 0.22 * dHashSim)
        .clamp(0.0, 1.0);
  }
}
