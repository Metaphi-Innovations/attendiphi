import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/qr_checkin/presentation/widgets/qr_overlay.dart';

void main() {
  group('QrOverlay Widget Tests', () {
    testWidgets('renders CustomPaints for cutout and brackets', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: QrOverlay(scanWindowSize: 260))),
      );

      // Verify custom painters are in the tree
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.byType(QrOverlay), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
    });
  });
}
