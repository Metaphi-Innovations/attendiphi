import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/core/l10n/app_strings.dart';
import 'package:qr_checkin/core/permissions/permission_service.dart';

Position _pos() => Position(
  latitude: 19.0,
  longitude: 72.8,
  timestamp: DateTime(2026, 11, 2),
  accuracy: 20,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  group('PermissionService.checkLocationAccess', () {
    test('native: GPS disabled reports serviceDisabled', () async {
      final service = PermissionService(
        isWebOverride: false,
        isLocationServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.whileInUse,
      );
      expect(
        await service.checkLocationAccess(),
        LocationAccessStatus.serviceDisabled,
      );
    });

    test('native: GPS enabled + granted reports granted', () async {
      final service = PermissionService(
        isWebOverride: false,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
      );
      expect(await service.checkLocationAccess(), LocationAccessStatus.granted);
    });

    test('web: never claims GPS off (browser cannot tell)', () async {
      final service = PermissionService(
        isWebOverride: true,
        isLocationServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.denied,
      );
      expect(
        await service.checkLocationAccess(),
        LocationAccessStatus.needsPrompt,
      );
      expect(service.canDetectServiceState, isFalse);
    });

    test('maps Permissions API states', () async {
      Future<LocationAccessStatus> statusFor(LocationPermission p) =>
          PermissionService(
            isWebOverride: true,
            checkPermission: () async => p,
          ).checkLocationAccess();

      expect(
        await statusFor(LocationPermission.whileInUse),
        LocationAccessStatus.granted,
      );
      expect(
        await statusFor(LocationPermission.denied),
        LocationAccessStatus.needsPrompt,
      );
      expect(
        await statusFor(LocationPermission.deniedForever),
        LocationAccessStatus.blocked,
      );
      expect(
        await statusFor(LocationPermission.unableToDetermine),
        LocationAccessStatus.needsPrompt,
      );
    });

    test('Permissions API failure falls back to needsPrompt', () async {
      final service = PermissionService(
        isWebOverride: true,
        checkPermission: () async => throw ArgumentError('unknown state'),
      );
      expect(
        await service.checkLocationAccess(),
        LocationAccessStatus.needsPrompt,
      );
    });

    test('never prompts or fetches a position', () async {
      var requests = 0;
      var fixes = 0;
      final service = PermissionService(
        isWebOverride: true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async {
          requests++;
          return LocationPermission.whileInUse;
        },
        getCurrentPositionFn: (_) async {
          fixes++;
          return _pos();
        },
      );
      await service.checkLocationAccess();
      expect(requests, 0);
      expect(fixes, 0);
    });
  });

  group('PermissionService.requestLocationPermission (native)', () {
    test('returns when already granted without re-request', () async {
      var requestCalls = 0;
      final service = PermissionService(
        isWebOverride: false,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.whileInUse;
        },
      );

      await service.requestLocationPermission();
      expect(requestCalls, 0);
    });

    test('prompts when denied and succeeds on Allow', () async {
      var requestCalls = 0;
      final service = PermissionService(
        isWebOverride: false,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.whileInUse;
        },
      );

      await service.requestLocationPermission();
      expect(requestCalls, 1);
    });

    test('GPS off throws LocationServiceDisabled without prompting', () async {
      var requestCalls = 0;
      final service = PermissionService(
        isWebOverride: false,
        isLocationServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.denied;
        },
      );

      await expectLater(
        service.requestLocationPermission(),
        throwsA(
          isA<LocationServiceDisabledException>().having(
            (e) => e.userMessage,
            'userMessage',
            AppStrings.locationServiceDisabled,
          ),
        ),
      );
      expect(requestCalls, 0);
    });

    test('denied after prompt throws LocationPermissionDenied', () async {
      final service = PermissionService(
        isWebOverride: false,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.denied,
      );

      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });

    test('permanently denied before prompt never re-requests', () async {
      var requestCalls = 0;
      final service = PermissionService(
        isWebOverride: false,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.deniedForever,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.deniedForever;
        },
      );

      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationPermissionPermanentlyDeniedException>()),
      );
      expect(requestCalls, 0);
    });
  });

  group('PermissionService.requestLocationPermission (web)', () {
    PermissionService web({
      required List<LocationPermission> states,
      required Future<Position> Function() fix,
      void Function()? onRequest,
    }) {
      var i = 0;
      return PermissionService(
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async =>
            states[i < states.length - 1 ? i++ : states.length - 1],
        requestPermission: () async {
          onRequest?.call();
          return LocationPermission.deniedForever;
        },
        getCurrentPositionFn: (_) => fix(),
        webPromptTimeout: const Duration(milliseconds: 50),
      );
    }

    test('prompt granted returns and skips geolocator requestPermission', () async {
      var requests = 0;
      final service = web(
        states: [LocationPermission.denied, LocationPermission.whileInUse],
        fix: () async => _pos(),
        onRequest: () => requests++,
      );
      await service.requestLocationPermission();
      expect(requests, 0);
    });

    test('blocked site never prompts', () async {
      var fixes = 0;
      final service = web(
        states: [LocationPermission.deniedForever],
        fix: () async {
          fixes++;
          return _pos();
        },
      );
      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationPermissionPermanentlyDeniedException>()),
      );
      expect(fixes, 0);
    });

    test('Block chosen in prompt → blocked', () async {
      final service = web(
        states: [LocationPermission.denied, LocationPermission.deniedForever],
        fix: () async => throw const PermissionDeniedException('denied'),
      );
      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationPermissionPermanentlyDeniedException>()),
      );
    });

    test('denied while site stays Ask → neutral denied (not GPS off)', () async {
      final service = web(
        states: [LocationPermission.denied, LocationPermission.denied],
        fix: () async => throw const PermissionDeniedException('denied'),
      );
      await expectLater(
        service.requestLocationPermission(),
        throwsA(
          isA<LocationPermissionDeniedException>().having(
            (e) => e.userMessage,
            'userMessage',
            AppStrings.locationPermissionDenied,
          ),
        ),
      );
    });

    test('denied while site granted → device Location off', () async {
      final service = web(
        states: [LocationPermission.denied, LocationPermission.whileInUse],
        fix: () async => throw const PermissionDeniedException('denied'),
      );
      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationServiceDisabledException>()),
      );
    });

    test('position unavailable while granted → LocationUnavailable', () async {
      final service = web(
        states: [LocationPermission.denied, LocationPermission.whileInUse],
        fix: () async => throw const PositionUpdateException('unavailable'),
      );
      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationUnavailableException>()),
      );
    });

    test('slow first fix after grant is not an error', () async {
      final service = web(
        states: [LocationPermission.denied, LocationPermission.whileInUse],
        fix: () => Completer<Position>().future,
      );
      await service.requestLocationPermission();
    });

    test('prompt left unanswered → neutral denied', () async {
      final service = web(
        states: [LocationPermission.denied, LocationPermission.denied],
        fix: () => Completer<Position>().future,
      );
      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });
  });

  group('classifyLocationDenial', () {
    test('maps site state to the most specific error', () {
      expect(
        classifyLocationDenial(LocationPermission.deniedForever),
        isA<LocationPermissionPermanentlyDeniedException>(),
      );
      expect(
        classifyLocationDenial(LocationPermission.whileInUse),
        isA<LocationServiceDisabledException>(),
      );
      expect(
        classifyLocationDenial(LocationPermission.denied),
        isA<LocationPermissionDeniedException>(),
      );
      expect(
        classifyLocationDenial(LocationPermission.unableToDetermine),
        isA<LocationPermissionDeniedException>(),
      );
    });
  });
}
