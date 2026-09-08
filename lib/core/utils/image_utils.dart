import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

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

  /// Converts bytes to a Base64 string.
  static String bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
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

  /// Checks whether a file size is within the allowed limit.
  static bool isWithinSizeLimit(int sizeInBytes) {
    return sizeInBytes <= AppConstants.maxPhotoSizeBytes;
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
