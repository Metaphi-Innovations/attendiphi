import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/widgets/app_button.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('AppButton Widget Tests', () {
    testWidgets('renders label correctly and responds to tap', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        buildTestable(
          AppButton.primary(label: 'Submit', onPressed: () => tapped = true),
        ),
      );

      expect(find.text('Submit'), findsOneWidget);
      await tester.tap(find.text('Submit'));
      expect(tapped, isTrue);
    });

    testWidgets(
      'shows loading indicator and ignores taps when isLoading is true',
      (tester) async {
        var tapped = false;

        await tester.pumpWidget(
          buildTestable(
            AppButton.primary(
              label: 'Submit',
              isLoading: true,
              onPressed: () => tapped = true,
            ),
          ),
        );

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Submit'), findsNothing);

        await tester.tap(find.byType(AppButton));
        expect(tapped, isFalse);
      },
    );

    testWidgets('renders secondary and text variants properly', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          Column(
            children: [
              AppButton.secondary(label: 'Secondary', onPressed: () {}),
              AppButton.text(label: 'Text Only', onPressed: () {}),
            ],
          ),
        ),
      );

      expect(find.text('Secondary'), findsOneWidget);
      expect(find.text('Text Only'), findsOneWidget);
    });
  });
}
