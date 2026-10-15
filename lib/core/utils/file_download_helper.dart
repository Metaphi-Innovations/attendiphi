import 'dart:convert';
import 'dart:typed_data';

import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart'
    as platform;

/// Universal cross-platform helper to trigger file downloads (PNG, etc.).
class FileDownloadHelper {
  FileDownloadHelper._();

  /// Triggers a download of the given [bytes] as a PNG file named [filename].
  static Future<void> downloadPng(Uint8List bytes, String filename) async {
    final sanitizedFilename = filename.endsWith('.png')
        ? filename
        : '$filename.png';
    await platform.saveBytesAsFile(
      bytes,
      sanitizedFilename,
      mimeType: 'image/png',
    );
  }

  /// Triggers a download of UTF-8 [content] as a `.txt` file named [filename].
  static Future<void> downloadTxt(String content, String filename) async {
    final sanitizedFilename = filename.endsWith('.txt')
        ? filename
        : '$filename.txt';
    await platform.saveBytesAsFile(
      Uint8List.fromList(utf8.encode(content)),
      sanitizedFilename,
      mimeType: 'text/plain;charset=utf-8',
    );
  }
}
