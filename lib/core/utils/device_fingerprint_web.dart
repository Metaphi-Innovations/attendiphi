// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:convert';
import 'dart:html' as html;

import 'package:crypto/crypto.dart';

/// Web implementation collecting immutable hardware and browser characteristics
/// to generate a stable, deterministic hardware fingerprint.
///
/// Persists across Incognito windows, private browsing, and iOS Camera ephemeral sessions.
Future<String> getPlatformDeviceFingerprint() async {
  final buffer = StringBuffer();

  try {
    // 1. User Agent & Platform architecture
    buffer.write(html.window.navigator.userAgent);
    buffer.write('|');
    buffer.write(html.window.navigator.platform ?? '');
    buffer.write('|');
  } catch (_) {}

  try {
    // 2. Screen & Display metrics
    final screen = html.window.screen;
    if (screen != null) {
      buffer.write('${screen.width}x${screen.height}x${screen.colorDepth}');
    }
    buffer.write('|');
    buffer.write(html.window.devicePixelRatio);
    buffer.write('|');
  } catch (_) {}

  try {
    // 3. Hardware concurrency (CPU cores) & memory hints
    buffer.write(html.window.navigator.hardwareConcurrency ?? 0);
    buffer.write('|');
    buffer.write(html.window.navigator.language);
    buffer.write('|');
    buffer.write(DateTime.now().timeZoneOffset.inMinutes);
    buffer.write('|');
  } catch (_) {}

  try {
    // 4. WebGL GPU Hardware Unmasked Renderer
    final canvas = html.CanvasElement(width: 16, height: 16);
    final dynamic gl =
        canvas.getContext('webgl') ?? canvas.getContext('experimental-webgl');

    if (gl != null) {
      // Extension 0x9245 (UNMASKED_VENDOR_WEBGL), 0x9246 (UNMASKED_RENDERER_WEBGL)
      final debugInfo = gl.getExtension('WEBGL_debug_renderer_info');
      if (debugInfo != null) {
        final vendor = gl.getParameter(0x9245);
        final renderer = gl.getParameter(0x9246);
        buffer.write('$vendor~$renderer|');
      }
    }
  } catch (_) {}

  try {
    // 5. 2D Canvas Sub-pixel Rasterization Signature
    final canvas2d = html.CanvasElement(width: 120, height: 30);
    final ctx = canvas2d.context2D;
    ctx.textBaseline = 'top';
    ctx.font = '14px Arial, sans-serif';
    ctx.fillStyle = '#f60';
    ctx.fillRect(10, 1, 62, 20);
    ctx.fillStyle = '#069';
    ctx.fillText('Attendiphi#1', 2, 15);
    ctx.fillStyle = 'rgba(102, 204, 0, 0.7)';
    ctx.fillText('Attendiphi#1', 4, 17);
    final dataUrl = canvas2d.toDataUrl();
    buffer.write(dataUrl.hashCode);
  } catch (_) {}

  final rawString = buffer.toString();
  if (rawString.isEmpty) {
    return '';
  }

  // Generate SHA-256 digest
  final bytes = utf8.encode(rawString);
  final digest = sha256.convert(bytes);
  return digest.toString();
}
