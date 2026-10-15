import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/logger/app_logger.dart';

void main() {
  group('AppLogger.redact', () {
    test('masks Indian phone and email', () {
      final out = AppLogger.redact(
        'user +919876543210 mailed a@b.co with token Bearer abc.def.ghi',
      );
      expect(out.contains('9876543210'), isFalse);
      expect(out.contains('a@b.co'), isFalse);
      expect(out.contains('[phone]'), isTrue);
      expect(out.contains('[email]'), isTrue);
      expect(out.contains('[token]'), isTrue);
    });
  });
}
