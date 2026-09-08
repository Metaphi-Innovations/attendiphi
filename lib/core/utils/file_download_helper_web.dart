// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Web implementation using HTML Anchor Element for browser file download.
Future<void> saveBytesAsFile(
  Uint8List bytes,
  String filename, {
  String mimeType = 'image/png',
}) async {
  final blob = html.Blob([bytes], mimeType);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';

  html.document.body?.children.add(anchor);
  anchor.click();
  html.document.body?.children.remove(anchor);
  html.Url.revokeObjectUrl(url);
}

Future<void> saveTextAsFile(
  String text,
  String filename, {
  String mimeType = 'text/csv;charset=utf-8',
}) async {
  final bytes = utf8.encode(text);
  await saveBytesAsFile(Uint8List.fromList(bytes), filename, mimeType: mimeType);
}
