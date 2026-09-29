import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/checkin/presentation/widgets/recognized_member_card.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';

void main() {
  group('RecognizedMemberCard Widget Tests', () {
    testWidgets('formats 10-digit phone number with +91 prefix', (tester) async {
      const member = Employee(
        id: 'emp_1',
        name: 'John Doe',
        phone: '9876543210',
        role: 'Director',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecognizedMemberCard(
              member: member,
              confidence: 95.0,
              onRescan: () {},
            ),
          ),
        ),
      );

      expect(find.text('+91 9876543210'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Face Verified'), findsOneWidget);
    });

    testWidgets('does not duplicate +91 when phone already contains country code',
        (tester) async {
      const member = Employee(
        id: 'emp_2',
        name: 'Jane Smith',
        phone: '+919876543210',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecognizedMemberCard(
              member: member,
              confidence: 92.0,
              onRescan: () {},
            ),
          ),
        ),
      );

      expect(find.text('+91 9876543210'), findsOneWidget);
      expect(find.textContaining('+91 +91'), findsNothing);
    });

    testWidgets('displays "No phone" when member phone is empty', (tester) async {
      const member = Employee(
        id: 'emp_3',
        name: 'Alex Johnson',
        phone: '',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecognizedMemberCard(
              member: member,
              confidence: 88.0,
              onRescan: () {},
            ),
          ),
        ),
      );

      expect(find.text('No phone'), findsOneWidget);
    });

    testWidgets('triggers onRescan callback when refresh icon is tapped',
        (tester) async {
      var rescanCalled = false;
      const member = Employee(
        id: 'emp_4',
        name: 'Chris Evans',
        phone: '9876543210',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RecognizedMemberCard(
              member: member,
              confidence: 90.0,
              onRescan: () {
                rescanCalled = true;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.refresh_rounded));
      await tester.pump();

      expect(rescanCalled, isTrue);
    });
  });
}
