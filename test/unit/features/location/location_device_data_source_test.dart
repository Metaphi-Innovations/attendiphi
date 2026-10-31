import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:qr_checkin/core/constants/app_constants.dart';
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/features/location/data/datasources/location_device_data_source.dart';

Position _pos({
  required DateTime timestamp,
  double accuracy = 20,
  double lat = 19.07,
  double lon = 72.87,
}) {
  return Position(
    latitude: lat,
    longitude: lon,
    timestamp: timestamp,
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
}

void main() {
  final now = DateTime(2026, 10, 29, 16, 45);

  group('isGpsPositionFresh / isGpsAccuracyAcceptable', () {
    test('fresh within TTL', () {
      final p = _pos(timestamp: now.subtract(const Duration(seconds: 30)));
      expect(
        isGpsPositionFresh(p, now: now, maxAgeSeconds: 120),
        isTrue,
      );
    });

    test('stale beyond TTL', () {
      final p = _pos(timestamp: now.subtract(const Duration(minutes: 10)));
      expect(
        isGpsPositionFresh(p, now: now, maxAgeSeconds: 120),
        isFalse,
      );
    });

    test('accuracy gate', () {
      expect(isGpsAccuracyAcceptable(_pos(timestamp: now, accuracy: 50)), isTrue);
      expect(
        isGpsAccuracyAcceptable(_pos(timestamp: now, accuracy: 150)),
        isFalse,
      );
      expect(
        isGpsAccuracyAcceptable(
          _pos(timestamp: now, accuracy: 250),
          maxAccuracyMeters: AppConstants.maxGpsAccuracyMetersWeb,
        ),
        isTrue,
      );
      expect(
        isGpsAccuracyAcceptable(
          _pos(timestamp: now, accuracy: 1500),
          maxAccuracyMeters: AppConstants.maxGpsAccuracyMetersWeb,
        ),
        isFalse,
      );
    });
  });

  group('LocationDeviceDataSourceImpl', () {
    test('returns in-memory cache without calling Geolocator', () async {
      var liveCalls = 0;
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async {
          liveCalls++;
          return _pos(timestamp: now);
        },
      );

      // Seed cache via a first successful fetch.
      final first = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(first.latitude, 19.07);
      expect(liveCalls, 1);

      final second = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(second.latitude, 19.07);
      expect(liveCalls, 1); // cache hit
    });

    test('forceRefresh skips cache and last-known fast path', () async {
      var liveCalls = 0;
      var permissionRequests = 0;
      final lastKnown = _pos(
        timestamp: now.subtract(const Duration(seconds: 10)),
        accuracy: 15,
        lat: 18.5,
      );
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async {
          permissionRequests++;
          return LocationPermission.whileInUse;
        },
        getLastKnownPosition: () async => lastKnown,
        getCurrentPositionFn: (_) async {
          liveCalls++;
          return _pos(timestamp: now, lat: 19.9);
        },
      );

      await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(liveCalls, 0); // last-known
      expect(permissionRequests, 0);

      final fresh = await ds.getCurrentPosition(
        permissionAlreadyGranted: true,
        forceRefresh: true,
      );
      expect(fresh.latitude, 19.9);
      expect(liveCalls, 1);
      // Already granted + caller prompted: skip redundant requestPermission.
      expect(permissionRequests, 0);
    });

    test('clearCachedPosition drops in-memory fix', () async {
      var liveCalls = 0;
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async {
          liveCalls++;
          return _pos(timestamp: now, lat: 19.0 + liveCalls);
        },
      );

      await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(liveCalls, 1);
      ds.clearCachedPosition();
      final again = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(liveCalls, 2);
      expect(again.latitude, 21.0);
    });

    test('uses fresh last-known before waiting on live GPS', () async {
      var liveCalls = 0;
      final lastKnown = _pos(
        timestamp: now.subtract(const Duration(seconds: 20)),
        accuracy: 25,
        lat: 18.5,
      );
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => lastKnown,
        getCurrentPositionFn: (_) async {
          liveCalls++;
          await Future<void>.delayed(const Duration(seconds: 5));
          return _pos(timestamp: now, lat: 1);
        },
      );

      final pos = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(pos.latitude, 18.5);
      expect(liveCalls, 0);
    });

    test('skips stale last-known and uses medium live fix', () async {
      final usedAccuracy = <LocationAccuracy>[];
      final stale = _pos(
        timestamp: now.subtract(const Duration(minutes: 30)),
        accuracy: 15,
        lat: 10,
      );
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => stale,
        getCurrentPositionFn: (settings) async {
          usedAccuracy.add(settings.accuracy);
          return _pos(timestamp: now, accuracy: 30, lat: 19.2);
        },
      );

      final pos = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(pos.latitude, 19.2);
      expect(usedAccuracy, [LocationAccuracy.medium]);
    });

    test('falls back to high when medium is too inaccurate', () async {
      var calls = 0;
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (settings) async {
          calls++;
          if (settings.accuracy == LocationAccuracy.medium) {
            return _pos(timestamp: now, accuracy: 250, lat: 1);
          }
          return _pos(timestamp: now, accuracy: 40, lat: 19.3);
        },
      );

      final pos = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(pos.latitude, 19.3);
      expect(calls, 2);
    });

    test(
      'permissionAlreadyGranted still requests when checkPermission is denied',
      () async {
        var requestCalls = 0;
        final ds = LocationDeviceDataSourceImpl(
          clock: () => now,
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.denied,
          requestPermission: () async {
            requestCalls++;
            return LocationPermission.whileInUse;
          },
          getLastKnownPosition: () async =>
              _pos(timestamp: now, accuracy: 20, lat: 19.0),
          getCurrentPositionFn: (_) async => _pos(timestamp: now),
        );

        await ds.getCurrentPosition(permissionAlreadyGranted: true);
        expect(requestCalls, 1);
      },
    );

    test(
      'permissionAlreadyGranted skips request when already whileInUse',
      () async {
        var requestCalls = 0;
        final ds = LocationDeviceDataSourceImpl(
          clock: () => now,
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.whileInUse,
          requestPermission: () async {
            requestCalls++;
            return LocationPermission.whileInUse;
          },
          getLastKnownPosition: () async =>
              _pos(timestamp: now, accuracy: 20, lat: 19.0),
          getCurrentPositionFn: (_) async => _pos(timestamp: now),
        );

        await ds.getCurrentPosition(permissionAlreadyGranted: true);
        expect(requestCalls, 0);
      },
    );

    test('denied permission still throws when not granted after request', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.denied,
        requestPermission: () async => LocationPermission.denied,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async => _pos(timestamp: now),
      );

      await expectLater(
        ds.getCurrentPosition(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
    });

    test('deniedForever throws permanently denied on native', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: false,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.deniedForever,
        requestPermission: () async => LocationPermission.deniedForever,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async => _pos(timestamp: now),
      );

      await expectLater(
        ds.getCurrentPosition(),
        throwsA(isA<LocationPermissionPermanentlyDeniedException>()),
      );
    });

    test('web deniedForever is recoverable soft deny (not blocked)', () async {
      var requestCalls = 0;
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.deniedForever,
        requestPermission: () async {
          requestCalls++;
          return LocationPermission.deniedForever;
        },
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async => _pos(timestamp: now),
      );

      await expectLater(
        ds.getCurrentPosition(),
        throwsA(isA<LocationPermissionDeniedException>()),
      );
      expect(requestCalls, 1);
    });

    test(
      'services off after deny prefers LocationServiceDisabledException',
      () async {
        final ds = LocationDeviceDataSourceImpl(
          clock: () => now,
          isWebOverride: true,
          isLocationServiceEnabled: () async => false,
          checkPermission: () async => LocationPermission.deniedForever,
          requestPermission: () async => LocationPermission.deniedForever,
          getLastKnownPosition: () async => null,
          getCurrentPositionFn: (_) async => _pos(timestamp: now),
        );

        await expectLater(
          ds.getCurrentPosition(),
          throwsA(isA<LocationServiceDisabledException>()),
        );
      },
    );

    test('services disabled throws LocationServiceDisabledException', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => false,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async => _pos(timestamp: now),
      );

      await expectLater(
        ds.getCurrentPosition(permissionAlreadyGranted: true),
        throwsA(isA<LocationServiceDisabledException>()),
      );
    });

    test('web uses high accuracy and the web medium timeout', () async {
      final limits = <int>[];
      final accuracies = <LocationAccuracy>[];
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (settings) async {
          limits.add(settings.timeLimit?.inSeconds ?? -1);
          accuracies.add(settings.accuracy);
          expect(settings, isA<WebSettings>());
          return _pos(timestamp: now, accuracy: 25, lat: 19.4);
        },
      );

      await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(limits, [LocationDeviceDataSourceImpl.webMediumGpsTimeoutSeconds]);
      expect(accuracies, [LocationAccuracy.high]);
    });

    test(
      'web skips throwing last-known and returns the live fix',
      () async {
        var lastKnownCalls = 0;
        final ds = LocationDeviceDataSourceImpl(
          clock: () => now,
          isWebOverride: true,
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.whileInUse,
          requestPermission: () async => LocationPermission.whileInUse,
          getLastKnownPosition: () async {
            lastKnownCalls++;
            throw UnsupportedError(
              'getLastKnownPosition is not supported on the web platform.',
            );
          },
          getCurrentPositionFn: (settings) async {
            expect(settings.accuracy, LocationAccuracy.high);
            return _pos(timestamp: now, accuracy: 20, lat: 19.5);
          },
        );

        final pos = await ds.getCurrentPosition(
          permissionAlreadyGranted: true,
        );
        expect(pos.latitude, 19.5);
        expect(lastKnownCalls, 0);

        final refreshed = await ds.getCurrentPosition(
          permissionAlreadyGranted: true,
          forceRefresh: true,
        );
        expect(refreshed.latitude, 19.5);
        expect(lastKnownCalls, 0);
      },
    );

    test('web accepts Wi‑Fi-grade accuracy within the web cap', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async =>
            _pos(timestamp: now, accuracy: 250, lat: 19.1),
      );

      final pos = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(pos.accuracy, 250);
      expect(pos.latitude, 19.1);
    });

    test('web rejects accuracy above the web cap', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async =>
            _pos(timestamp: now, accuracy: 2500, lat: 19.1),
      );

      await expectLater(
        ds.getCurrentPosition(permissionAlreadyGranted: true),
        throwsA(
          isA<LocationAccuracyTooLowException>().having(
            (e) => e.technicalMessage,
            'technicalMessage',
            contains('2500'),
          ),
        ),
      );
    });

    test('web accepts first good-enough fix on short retry', () async {
      var calls = 0;
      final limits = <int>[];
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (settings) async {
          calls++;
          limits.add(settings.timeLimit?.inSeconds ?? -1);
          // Primary exceeds web cap; short retry is usable (no 3rd attempt).
          if (calls == 1) {
            return _pos(timestamp: now, accuracy: 1800, lat: 1);
          }
          return _pos(timestamp: now, accuracy: 220, lat: 19.2);
        },
      );

      final pos = await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(calls, 2);
      expect(limits, [
        LocationDeviceDataSourceImpl.webMediumGpsTimeoutSeconds,
        LocationDeviceDataSourceImpl.webHighGpsTimeoutSeconds,
      ]);
      expect(pos.accuracy, 220);
      expect(pos.latitude, 19.2);
    });

    test('web does not run a third live attempt after retry miss', () async {
      var calls = 0;
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async {
          calls++;
          return _pos(timestamp: now, accuracy: 1800, lat: 1.0 + calls);
        },
      );

      await expectLater(
        ds.getCurrentPosition(permissionAlreadyGranted: true),
        throwsA(isA<LocationAccuracyTooLowException>()),
      );
      expect(calls, 2);
    });

    test(
      'web live miss after a throwing last-known is LocationTimeoutException',
      () async {
        var lastKnownCalls = 0;
        var liveCalls = 0;
        final ds = LocationDeviceDataSourceImpl(
          clock: () => now,
          isWebOverride: true,
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.whileInUse,
          requestPermission: () async => LocationPermission.whileInUse,
          getLastKnownPosition: () async {
            lastKnownCalls++;
            throw UnsupportedError(
              'getLastKnownPosition is not supported on the web platform.',
            );
          },
          getCurrentPositionFn: (_) async {
            liveCalls++;
            throw TimeoutException('browser geolocation timed out');
          },
        );

        await expectLater(
          ds.getCurrentPosition(
            permissionAlreadyGranted: true,
            forceRefresh: true,
          ),
          throwsA(isA<LocationTimeoutException>()),
        );
        expect(lastKnownCalls, 0);
        // Primary + one short retry only.
        expect(liveCalls, 2);
      },
    );

    test(
      'native swallows UnsupportedError from last-known and uses live fix',
      () async {
        final ds = LocationDeviceDataSourceImpl(
          clock: () => now,
          isWebOverride: false,
          isLocationServiceEnabled: () async => true,
          checkPermission: () async => LocationPermission.whileInUse,
          getLastKnownPosition: () async {
            throw UnsupportedError('last known unavailable');
          },
          getCurrentPositionFn: (settings) async {
            expect(settings.accuracy, LocationAccuracy.medium);
            return _pos(timestamp: now, accuracy: 15, lat: 19.8);
          },
        );

        final pos = await ds.getCurrentPosition(
          permissionAlreadyGranted: true,
        );
        expect(pos.latitude, 19.8);
      },
    );

    test('web timeout after failed fixes throws LocationTimeoutException', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        requestPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (_) async {
          throw Exception('timeout');
        },
      );

      await expectLater(
        ds.getCurrentPosition(
          permissionAlreadyGranted: true,
          forceRefresh: true,
        ),
        throwsA(isA<LocationTimeoutException>()),
      );
    });

    test('native keeps shorter medium timeout', () async {
      final limits = <int>[];
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: false,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (settings) async {
          limits.add(settings.timeLimit?.inSeconds ?? -1);
          return _pos(timestamp: now, accuracy: 25);
        },
      );

      await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(
        limits.first,
        LocationDeviceDataSourceImpl.nativeMediumGpsTimeoutSeconds,
      );
    });
  });
}
