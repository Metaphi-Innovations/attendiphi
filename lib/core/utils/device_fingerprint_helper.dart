import 'device_fingerprint_stub.dart'
    if (dart.library.html) 'device_fingerprint_web.dart'
    as platform;

/// Cross-platform helper for deterministic physical device fingerprinting.
class DeviceFingerprintHelper {
  DeviceFingerprintHelper._();

  static String? _cachedFingerprint;

  /// Retrieves a deterministic SHA-256 fingerprint representing the physical device/browser.
  static Future<String> getDeviceFingerprint() async {
    if (_cachedFingerprint != null && _cachedFingerprint!.isNotEmpty) {
      return _cachedFingerprint!;
    }
    final fp = await platform.getPlatformDeviceFingerprint();
    if (fp.isNotEmpty) {
      _cachedFingerprint = fp;
    }
    return fp;
  }
}
