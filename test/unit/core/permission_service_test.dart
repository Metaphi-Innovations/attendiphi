import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/core/l10n/app_strings.dart';
import 'package:qr_checkin/core/permissions/permission_service.dart';

void main() {
  group('PermissionService.requestLocationPermission', () {
    test('returns when already whileInUse without re-request', () async {
      var requestCalls = 0;
      final service = PermissionService(
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

    test('requests when denied and succeeds on Allow', () async {
      var requestCalls = 0;
      final service = PermissionService(
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

    test('services off after probe throws recoverable LocationServiceDisabled', () async {
      var requestCalls = 0;
      final service = PermissionService(
        isLocationServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.deniedForever,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.deniedForever;
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
      expect(requestCalls, 1);
    });

    test('denied after request throws LocationPermissionDeniedException', () async {
      final service = PermissionService(
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.denied,
      );

      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });

    test('web deniedForever is soft deny after requestPermission', () async {
      var requestCalls = 0;
      final service = PermissionService(
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.deniedForever,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.deniedForever;
        },
      );

      await expectLater(
        service.requestLocationPermission(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
      expect(requestCalls, 1);
    });

    test('native deniedForever is permanently denied after request', () async {
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
      expect(requestCalls, 1);
    });
  });
}
