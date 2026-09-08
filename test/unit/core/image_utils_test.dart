import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/utils/image_utils.dart';

void main() {
  group('ImageUtils - Base64 operations', () {
    test('bytesToBase64 and base64ToBytes work symmetrically', () {
      final sampleBytes = Uint8List.fromList([0, 1, 2, 3, 255, 254, 128]);
      final base64Str = ImageUtils.bytesToBase64(sampleBytes);

      expect(base64Str, isNotEmpty);
      final decoded = ImageUtils.base64ToBytes(base64Str);
      expect(decoded, equals(sampleBytes));
    });

    test('base64ToBytes handles data URI prefix', () {
      const rawStr = 'hello world';
      final base64Raw = base64Encode(utf8.encode(rawStr));
      final dataUri = 'data:image/jpeg;base64,$base64Raw';

      final decoded = ImageUtils.base64ToBytes(dataUri);
      expect(decoded, isNotNull);
      expect(utf8.decode(decoded!), rawStr);
    });

    test('base64ToBytes returns null for invalid string', () {
      expect(ImageUtils.base64ToBytes(null), isNull);
      expect(ImageUtils.base64ToBytes(''), isNull);
      expect(ImageUtils.base64ToBytes('!invalid base64!@#'), isNull);
    });
  });

  group('ImageUtils - formatFileSize', () {
    test('formats bytes, KB, and MB accurately', () {
      expect(ImageUtils.formatFileSize(500), '500 B');
      expect(ImageUtils.formatFileSize(1536), '1.5 KB');
      expect(ImageUtils.formatFileSize(2097152), '2.0 MB');
    });
  });
}
