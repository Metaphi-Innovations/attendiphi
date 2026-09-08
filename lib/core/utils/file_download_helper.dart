import 'dart:typed_data';

import 'file_download_helper_stub.dart'
    if (dart.library.html) 'file_download_helper_web.dart' as platform;

/// Universal cross-platform helper to trigger file downloads (PNG, CSV, etc.).
class FileDownloadHelper {
  FileDownloadHelper._();

  /// Triggers a download of the given [bytes] as a PNG file named [filename].
  static Future<void> downloadPng(Uint8List bytes, String filename) async {
    final sanitizedFilename =
        filename.endsWith('.png') ? filename : '$filename.png';
    await platform.saveBytesAsFile(
      bytes,
      sanitizedFilename,
      mimeType: 'image/png',
    );
  }

  /// Triggers a download of the given [bytes] as a PDF file named [filename].
  static Future<void> downloadPdf(Uint8List bytes, String filename) async {
    final sanitizedFilename =
        filename.endsWith('.pdf') ? filename : '$filename.pdf';
    await platform.saveBytesAsFile(
      bytes,
      sanitizedFilename,
      mimeType: 'application/pdf',
    );
  }

  /// Triggers a download of the given [csvContent] as a CSV file named [filename].
  static Future<void> downloadCsv(String csvContent, String filename) async {
    final sanitizedFilename =
        filename.endsWith('.csv') ? filename : '$filename.csv';
    await platform.saveTextAsFile(
      csvContent,
      sanitizedFilename,
      mimeType: 'text/csv;charset=utf-8',
    );
  }
}
