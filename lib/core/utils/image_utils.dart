import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

import '../constants/app_constants.dart';
import '../logger/app_logger.dart';

/// Image compression and processing utilities.
///
/// Supports compressing face photos and converting to Base64
/// for storage in Firestore without requiring Firebase Cloud Storage billing.
class ImageUtils {
  ImageUtils._();

  /// Compresses and resizes an image file.
  ///
  /// Target:
  /// - Max dimension: [AppConstants.maxPhotoPixels] px (800px)
  /// - Quality: [AppConstants.photoCompressionQuality] % (80%)
  /// - Format: JPEG
  ///
  /// Returns compressed image bytes, or `null` if compression fails.
  static Future<Uint8List?> compressImageFile(File file) async {
    try {
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: AppConstants.maxPhotoPixels,
        minHeight: AppConstants.maxPhotoPixels,
        quality: AppConstants.photoCompressionQuality,
        format: CompressFormat.jpeg,
      );

      if (result != null) {
        AppLogger.debug(
          'Image compressed: ${file.lengthSync()} → ${result.length} bytes',
          tag: 'ImageUtils',
        );
      }

      return result;
    } catch (e, st) {
      AppLogger.error(
        'Image compression failed',
        error: e,
        stackTrace: st,
        tag: 'ImageUtils',
      );
      return null;
    }
  }

  /// Compresses image bytes directly (e.g., from memory).
  static Future<Uint8List?> compressImageBytes(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: AppConstants.maxPhotoPixels,
        minHeight: AppConstants.maxPhotoPixels,
        quality: AppConstants.photoCompressionQuality,
        format: CompressFormat.jpeg,
      );

      AppLogger.debug(
        'Image compressed: ${bytes.length} → ${result.length} bytes',
        tag: 'ImageUtils',
      );

      return result;
    } catch (e, st) {
      AppLogger.error(
        'Image bytes compression failed',
        error: e,
        stackTrace: st,
        tag: 'ImageUtils',
      );
      return null;
    }
  }

  /// Compresses a photo file and converts it to a Base64 string for direct Firestore storage.
  static Future<String?> compressAndConvertToBase64(File file) async {
    final compressedBytes = await compressImageFile(file);
    if (compressedBytes == null) return null;
    return bytesToBase64(compressedBytes);
  }

  /// Appends a version query so browsers do not keep serving a stale photo.
  ///
  /// When [version] is null, uses `0` (not wall-clock time) so live roster
  /// rebuilds do not change the URL and flash the image every few seconds.
  static String cacheBustedUrl(String url, {DateTime? version}) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;
    if (!(trimmed.startsWith('http://') || trimmed.startsWith('https://'))) {
      return trimmed;
    }
    final stamp = version?.millisecondsSinceEpoch ?? 0;
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) {
      final separator = trimmed.contains('?') ? '&' : '?';
      return '$trimmed${separator}v=$stamp';
    }
    final params = Map<String, String>.from(uri.queryParameters);
    params['v'] = '$stamp';
    return uri.replace(queryParameters: params).toString();
  }

  /// Converts bytes to a Base64 string.
  static String bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }

  /// Re-encodes any common image bytes as JPEG for Storage uploads.
  ///
  /// Gallery / web captures are often PNG/WebP; the `check-in-photos` bucket
  /// rejects `application/octet-stream` with HTTP 400, so we normalize here.
  static Uint8List toJpegBytes(
    Uint8List bytes, {
    int quality = AppConstants.photoCompressionQuality,
    int maxSide = AppConstants.maxPhotoPixels,
  }) {
    if (bytes.isEmpty) return bytes;
    final isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    try {
      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        return isJpeg ? bytes : Uint8List(0);
      }
      var frame = decoded;
      final longest = frame.width > frame.height ? frame.width : frame.height;
      if (longest > maxSide && maxSide > 0) {
        frame = img.copyResize(
          frame,
          width: frame.width >= frame.height ? maxSide : null,
          height: frame.height > frame.width ? maxSide : null,
          interpolation: img.Interpolation.linear,
        );
      }
      return Uint8List.fromList(
        img.encodeJpg(frame, quality: quality.clamp(1, 100)),
      );
    } catch (e, st) {
      AppLogger.error(
        'toJpegBytes failed',
        error: e,
        stackTrace: st,
        tag: 'ImageUtils',
      );
      return isJpeg ? bytes : Uint8List(0);
    }
  }

  /// Converts a Base64 string back to bytes for image rendering.
  static Uint8List? base64ToBytes(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    try {
      // Strip data URI prefix if present (e.g. "data:image/jpeg;base64,")
      final cleaned = base64String.contains(',')
          ? base64String.split(',').last
          : base64String;
      return base64Decode(cleaned);
    } catch (e) {
      AppLogger.error('Failed to decode base64 image: $e', tag: 'ImageUtils');
      return null;
    }
  }

  /// Returns a human-readable file size string.
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
