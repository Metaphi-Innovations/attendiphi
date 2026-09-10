import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/device_fingerprint_helper.dart';

void main() {
  group('DeviceFingerprintHelper Tests', () {
    test('getDeviceFingerprint returns a non-null string and caches result', () async {
      final fp1 = await DeviceFingerprintHelper.getDeviceFingerprint();
      final fp2 = await DeviceFingerprintHelper.getDeviceFingerprint();

      expect(fp1, isNotNull);
      expect(fp1, equals(fp2));
    });
  });
}
