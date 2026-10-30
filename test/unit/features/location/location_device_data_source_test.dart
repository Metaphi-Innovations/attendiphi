import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
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
      final lastKnown = _pos(
        timestamp: now.subtract(const Duration(seconds: 10)),
        accuracy: 15,
        lat: 18.5,
      );
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => lastKnown,
        getCurrentPositionFn: (_) async {
          liveCalls++;
          return _pos(timestamp: now, lat: 19.9);
        },
      );

      await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(liveCalls, 0); // last-known

      final fresh = await ds.getCurrentPosition(
        permissionAlreadyGranted: true,
        forceRefresh: true,
      );
      expect(fresh.latitude, 19.9);
      expect(liveCalls, 1);
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
      var usedAccuracy = <LocationAccuracy>[];
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

    test('deniedForever throws permanently denied', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
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

    test('web uses longer medium/high timeouts', () async {
      final limits = <int>[];
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
        getLastKnownPosition: () async => null,
        getCurrentPositionFn: (settings) async {
          limits.add(settings.timeLimit?.inSeconds ?? -1);
          return _pos(timestamp: now, accuracy: 25, lat: 19.4);
        },
      );

      await ds.getCurrentPosition(permissionAlreadyGranted: true);
      expect(limits, isNotEmpty);
      expect(
        limits.first,
        LocationDeviceDataSourceImpl.webMediumGpsTimeoutSeconds,
      );
    });

    test('web timeout after failed fixes throws LocationTimeoutException', () async {
      final ds = LocationDeviceDataSourceImpl(
        clock: () => now,
        isWebOverride: true,
        isLocationServiceEnabled: () async => true,
        checkPermission: () async => LocationPermission.whileInUse,
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
