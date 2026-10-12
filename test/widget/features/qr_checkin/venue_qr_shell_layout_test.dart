import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/qr_checkin/presentation/screens/venue_qr_display_screen.dart';

void main() {
  testWidgets(
    'renders inside shell-like Positioned.fill constraints without blank body',
    (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  const SizedBox(
                    width: 250,
                    child: ColoredBox(color: Colors.white),
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: VenueQrDisplayScreen(
                            location: const LocationConfig(
                              id: 'location_x',
                              name: 'Test',
                              latitude: 0,
                              longitude: 0,
                              radiusMeters: 100,
                            ),
                            initialDate: DateTime(2026, 10, 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Thursday QR Standees'), findsOneWidget);
      expect(find.textContaining('Thursdays in October 2026'), findsOneWidget);
    },
  );
}
