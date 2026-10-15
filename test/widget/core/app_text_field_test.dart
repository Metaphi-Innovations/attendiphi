import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/widgets/app_text_field.dart';

void main() {
  Widget buildTestable(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }

  group('AppTextField Widget Tests', () {
    testWidgets('renders label and hint text', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const AppTextField(
            label: 'Full Name',
            hint: 'Enter your full name',
            showFloatingLabel: true,
          ),
        ),
      );

      expect(find.text('Full Name'), findsOneWidget);
      expect(find.text('Enter your full name'), findsOneWidget);
    });

    testWidgets('allows text input and triggers onChanged', (tester) async {
      String? entered;

      await tester.pumpWidget(
        buildTestable(
          AppTextField(label: 'Name', onChanged: (val) => entered = val),
        ),
      );

      await tester.enterText(find.byType(TextFormField), 'Jane Doe');
      expect(entered, 'Jane Doe');
    });

    testWidgets('displays validation error message when invalid', (
      tester,
    ) async {
      final formKey = GlobalKey<FormState>();

      await tester.pumpWidget(
        buildTestable(
          Form(
            key: formKey,
            child: AppTextField(
              label: 'Phone',
              validator: (val) =>
                  (val == null || val.isEmpty) ? 'Required field' : null,
            ),
          ),
        ),
      );

      formKey.currentState!.validate();
      await tester.pumpAndSettle();

      expect(find.text('Required field'), findsOneWidget);
    });
  });
}
