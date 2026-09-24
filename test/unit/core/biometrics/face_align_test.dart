import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/biometrics/face_align.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  group('FaceAlign letterbox', () {
    test('non-square source is not stretched to fill 112', () {
      final dest = FaceAlign.letterboxDest(srcW: 80, srcH: 120, dstSize: 112);
      expect(dest.dh, closeTo(112, 0.001));
      expect(dest.dw, lessThan(112));
      expect(dest.dx, greaterThan(0));
      expect(dest.dy, closeTo(0, 0.001));
    });
  });

  group('Employee faceTemplates Firestore encoding', () {
    test('uses t0/t1 keys instead of nested arrays or numeric keys', () {
      final templates = [
        List<double>.filled(128, 0.1),
        List<double>.filled(128, 0.2),
      ];
      final encoded = Employee.faceTemplatesToFirestore(templates);
      expect(encoded.keys, containsAll(['t0', 't1']));
      expect(encoded.containsKey('0'), isFalse);
      expect(encoded['t0'], isA<List<double>>());
      expect(encoded['t0']!.first, isA<double>());

      final parsed = Employee.parseFaceTemplates(encoded);
      expect(parsed, isNotNull);
      expect(parsed!.length, 2);
    });

    test('reads legacy numeric map keys', () {
      final parsed = Employee.parseFaceTemplates({
        '0': [0.1, 0.2, 0.3],
        '1': [0.4, 0.5, 0.6],
      });
      expect(parsed!.length, 2);
      expect(parsed.first, [0.1, 0.2, 0.3]);
    });
  });
}
