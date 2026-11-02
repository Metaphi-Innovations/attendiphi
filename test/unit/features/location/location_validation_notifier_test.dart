import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart'
    hide LocationServiceDisabledException;
import 'package:qr_checkin/core/errors/app_exception.dart';
import 'package:qr_checkin/core/permissions/permission_service.dart';
import 'package:qr_checkin/features/app_config/presentation/providers/check_in_restrictions_provider.dart';
import 'package:qr_checkin/features/location/data/datasources/location_device_data_source.dart';
import 'package:qr_checkin/features/location/domain/entities/location_config.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_providers.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_validation_provider.dart';
import 'package:qr_checkin/features/location/presentation/providers/location_validation_state.dart';

const _venue = LocationConfig(
  id: 'venue',
  name: 'Test Venue',
  latitude: 19.0829524,
  longitude: 72.9129274,
  radiusMeters: 500,
);

Position _fix({double? lat, double? lon, double accuracy = 20}) => Position(
  latitude: lat ?? _venue.latitude,
  longitude: lon ?? _venue.longitude,
  timestamp: DateTime(2026, 11, 2, 10),
  accuracy: accuracy,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

class _FakeDevice implements LocationDeviceDataSource {
  _FakeDevice(this.handler);

  Future<Position> Function() handler;
  int calls = 0;
  int clears = 0;

  @override
  Future<Position> getCurrentPosition({
    bool permissionAlreadyGranted = false,
    bool forceRefresh = false,
  }) {
    calls++;
    return handler();
  }

  @override
  void clearCachedPosition() => clears++;
}

/// Mutable device / browser state behind a real [PermissionService].
class _Env {
  _Env({
    this.permission = LocationPermission.whileInUse,
    this.gpsOn = true,
    this.isWeb = false,
    LocationPermission? afterRequest,
  }) : afterRequest = afterRequest ?? LocationPermission.whileInUse;

  LocationPermission permission;
  LocationPermission afterRequest;
  bool gpsOn;
  final bool isWeb;
  int requests = 0;

  PermissionService get service => PermissionService(
    isWebOverride: isWeb,
    isLocationServiceEnabled: () async => gpsOn,
    checkPermission: () async => permission,
    requestPermission: () async {
      requests++;
      permission = afterRequest;
      return permission;
    },
    getCurrentPositionFn: (_) async {
      requests++;
      permission = afterRequest;
      if (permission != LocationPermission.whileInUse) {
        throw const PermissionDeniedException('denied');
      }
      return _fix();
    },
    webPromptTimeout: const Duration(milliseconds: 50),
  );
}

ProviderContainer _container(
  _Env env,
  _FakeDevice device, {
  bool locationRestriction = true,
}) {
  final c = ProviderContainer(
    overrides: [
      permissionServiceProvider.overrideWithValue(env.service),
      locationDeviceDataSourceProvider.overrideWithValue(device),
      locationRestrictionEnabledProvider.overrideWithValue(locationRestriction),
    ],
  );
  addTearDown(c.dispose);
  return c;
}

void main() {
  LocationValidationNotifier notifierOf(ProviderContainer c) =>
      c.read(locationValidationFamilyProvider(_venue).notifier);
  LocationValidationState stateOf(ProviderContainer c) =>
      c.read(locationValidationFamilyProvider(_venue));

  group('LocationValidationNotifier', () {
    test('1. GPS disabled → ServiceDisabled, no prompt, no fix', () async {
      final env = _Env(gpsOn: false, permission: LocationPermission.denied);
      final device = _FakeDevice(() async => _fix());
      final c = _container(env, device);

      await notifierOf(c).validateLocation();

      expect(stateOf(c), isA<LocationValidationServiceDisabled>());
      expect(env.requests, 0);
      expect(device.calls, 0);
    });

    test('2+4. GPS enabled and permission granted → verified success', () async {
      final env = _Env();
      final device = _FakeDevice(() async => _fix());
      final c = _container(env, device);

      final status = await notifierOf(c).checkAccessOnEntry();

      expect(status, LocationAccessStatus.granted);
      final s = stateOf(c);
      expect(s, isA<LocationValidationSuccess>());
      expect((s as LocationValidationSuccess).result.isVerified, isTrue);
      expect(env.requests, 0);
    });

    test('3. permission not decided → entry auto-prompts then verifies', () async {
      final env = _Env(permission: LocationPermission.denied);
      final device = _FakeDevice(() async => _fix());
      final c = _container(env, device);

      final status = await notifierOf(c).checkAccessOnEntry();

      expect(status, LocationAccessStatus.needsPrompt);
      expect(env.requests, 1);
      expect(device.calls, 1);
      expect(stateOf(c), isA<LocationValidationSuccess>());
    });

    test('5. permission denied → PermissionDenied', () async {
      final env = _Env(
        permission: LocationPermission.denied,
        afterRequest: LocationPermission.denied,
      );
      final c = _container(env, _FakeDevice(() async => _fix()));

      await notifierOf(c).validateLocation();

      expect(stateOf(c), isA<LocationValidationPermissionDenied>());
    });

    test('6. permanently denied → PermissionBlocked, never re-prompts', () async {
      final env = _Env(permission: LocationPermission.deniedForever);
      final device = _FakeDevice(() async => _fix());
      final c = _container(env, device);

      await notifierOf(c).checkAccessOnEntry();
      expect(stateOf(c), isA<LocationValidationPermissionBlocked>());

      await notifierOf(c).validateLocation();
      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationPermissionBlocked>());
      expect(env.requests, 0);
      expect(device.calls, 0);
    });

    test('7. location timeout → Timeout', () async {
      final c = _container(
        _Env(),
        _FakeDevice(() async => throw const LocationTimeoutException()),
      );
      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationTimeout>());
    });

    test('8. location unavailable → Unavailable', () async {
      final c = _container(
        _Env(),
        _FakeDevice(() async => throw const LocationUnavailableException()),
      );
      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationUnavailable>());
    });

    test('9. accuracy wider than the radius → AccuracyInsufficient', () async {
      final c = _container(
        _Env(),
        _FakeDevice(() async => _fix(accuracy: 800)),
      );
      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationAccuracyInsufficient>());
    });

    test('10. within 500 m → success with verified result', () async {
      final c = _container(
        _Env(),
        // ~200 m north of the venue.
        _FakeDevice(() async => _fix(lat: 19.08475)),
      );
      await notifierOf(c).validateLocation();
      final s = stateOf(c) as LocationValidationSuccess;
      expect(s.result.isVerified, isTrue);
      expect(s.result.isWithinRadius, isTrue);
      expect(s.result.allowedRadiusMeters, 500);
    });

    test('11. outside 500 m → OutsideRadius', () async {
      final c = _container(
        _Env(),
        _FakeDevice(() async => _fix(lat: 19.10295)),
      );
      await notifierOf(c).validateLocation();
      final s = stateOf(c);
      expect(s, isA<LocationValidationOutsideRadius>());
      expect((s as LocationValidationOutsideRadius).allowedRadiusMeters, 500);
    });

    test('12. restriction disabled → bypass success, never verified', () async {
      final env = _Env(permission: LocationPermission.deniedForever);
      final c = _container(
        env,
        _FakeDevice(() async => _fix()),
        locationRestriction: false,
      );

      await notifierOf(c).checkAccessOnEntry();

      final s = stateOf(c) as LocationValidationSuccess;
      expect(s.result.isVerified, isFalse);
      expect(env.requests, 0);
    });

    test('12b. restriction disabled + outside radius still records fix', () async {
      final c = _container(
        _Env(),
        _FakeDevice(() async => _fix(lat: 19.10295)),
        locationRestriction: false,
      );
      await notifierOf(c).validateLocation();
      final s = stateOf(c) as LocationValidationSuccess;
      expect(s.result.isWithinRadius, isFalse);
      expect(s.result.isVerified, isFalse);
    });

    test('13. retry after GPS activation (native resume) verifies once', () async {
      final env = _Env(gpsOn: false);
      final device = _FakeDevice(() async => _fix());
      final c = _container(env, device);

      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationServiceDisabled>());

      env.gpsOn = true;
      await notifierOf(c).recheckAfterResume();
      expect(stateOf(c), isA<LocationValidationSuccess>());
      expect(device.calls, 1);
    });

    test('13b. web services-off: resume does not auto-run, Retry does', () async {
      final env = _Env(isWeb: true);
      final device = _FakeDevice(
        () async => throw const LocationServiceDisabledException(),
      );
      final c = _container(env, device);

      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationServiceDisabled>());

      device.handler = () async => _fix();
      await notifierOf(c).recheckAfterResume();
      expect(stateOf(c), isA<LocationValidationServiceDisabled>());
      expect(device.calls, 1);

      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationSuccess>());
    });

    test('14. retry after browser permission change (Block → Allow)', () async {
      final env = _Env(isWeb: true, permission: LocationPermission.deniedForever);
      final device = _FakeDevice(() async => _fix());
      final c = _container(env, device);

      await notifierOf(c).checkAccessOnEntry();
      expect(stateOf(c), isA<LocationValidationPermissionBlocked>());

      env.permission = LocationPermission.whileInUse;
      final status = await notifierOf(c).recheckAfterResume();
      expect(status, LocationAccessStatus.granted);
      expect(stateOf(c), isA<LocationValidationSuccess>());
      expect(env.requests, 0);
    });

    test('14b. Block → Ask on resume auto-starts verification', () async {
      final env = _Env(isWeb: true, permission: LocationPermission.deniedForever);
      final device = _FakeDevice(() async => _fix());
      final c = _container(env, device);

      await notifierOf(c).checkAccessOnEntry();
      env.permission = LocationPermission.denied;
      env.afterRequest = LocationPermission.whileInUse;
      final status = await notifierOf(c).recheckAfterResume();

      expect(status, LocationAccessStatus.needsPrompt);
      expect(env.requests, 1);
      expect(device.calls, 1);
      expect(stateOf(c), isA<LocationValidationSuccess>());
    });

    test('14c. resume recovery runs at most once per failure', () async {
      final env = _Env(permission: LocationPermission.denied,
          afterRequest: LocationPermission.denied);
      final device = _FakeDevice(
        () async => throw const LocationServiceDisabledException(),
      );
      final c = _container(env, device);

      await notifierOf(c).validateLocation();
      expect(stateOf(c), isA<LocationValidationPermissionDenied>());

      env.permission = LocationPermission.whileInUse;
      await notifierOf(c).recheckAfterResume();
      expect(stateOf(c), isA<LocationValidationServiceDisabled>());
      await notifierOf(c).recheckAfterResume();
      await notifierOf(c).recheckAfterResume();
      expect(device.calls, 1);
    });

    test('15. concurrent retries run a single verification', () async {
      final gate = Completer<Position>();
      final device = _FakeDevice(() => gate.future);
      final c = _container(_Env(), device);

      final first = notifierOf(c).validateLocation();
      await Future<void>.delayed(Duration.zero);
      expect(notifierOf(c).isBusy, isTrue);
      await notifierOf(c).validateLocation();
      await notifierOf(c).resetAndValidate();
      gate.complete(_fix());
      await first;

      expect(device.calls, 1);
      expect(stateOf(c), isA<LocationValidationSuccess>());
      expect(notifierOf(c).isBusy, isFalse);
    });

    test('Allow dialog cancel continues only when restriction is OFF', () {
      final on = _container(_Env(), _FakeDevice(() async => _fix()));
      expect(notifierOf(on).continueWithoutLocationIfAllowed(), isFalse);
      expect(stateOf(on), isA<LocationValidationInitial>());

      final off = _container(
        _Env(),
        _FakeDevice(() async => _fix()),
        locationRestriction: false,
      );
      expect(notifierOf(off).continueWithoutLocationIfAllowed(), isTrue);
      expect(stateOf(off), isA<LocationValidationSuccess>());
    });
  });
}
