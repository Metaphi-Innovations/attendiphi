import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/responsive/responsive_breakpoints.dart';

void main() {
  group('ResponsiveBreakpoints Tests', () {
    testWidgets('Detects compact mobile for width < 360px', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late bool isCompact;
      late bool isMobile;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isCompact = context.isCompactMobile;
              isMobile = context.isMobile;
              isDesktop = context.isDesktop;
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(isCompact, isTrue);
      expect(isMobile, isTrue);
      expect(isDesktop, isFalse);
    });

    testWidgets('Detects desktop for width >= 1024px', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late bool isMobile;
      late bool isTablet;
      late bool isDesktop;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              isMobile = context.isMobile;
              isTablet = context.isTablet;
              isDesktop = context.isDesktop;
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(isMobile, isFalse);
      expect(isTablet, isFalse);
      expect(isDesktop, isTrue);
    });

    testWidgets('Keeps tablet classification between 600px and 1023px', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(600, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late ScreenDeviceType deviceType;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              deviceType = context.deviceType;
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(deviceType, ScreenDeviceType.tablet);
    });

    testWidgets('Uses desktop classification at the 1024px boundary', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1024, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      late ScreenDeviceType deviceType;

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              deviceType = context.deviceType;
              return const Scaffold(body: Text('Test'));
            },
          ),
        ),
      );

      expect(deviceType, ScreenDeviceType.desktop);
    });
  });
}
