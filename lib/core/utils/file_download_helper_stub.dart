import 'dart:typed_data';

/// Platform-agnostic stub for file downloading.
Future<void> saveBytesAsFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'image/png',
}) async {
  // No-op or mobile implementation fallback
}
