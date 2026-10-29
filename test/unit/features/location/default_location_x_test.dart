import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/app/config/environment.dart';
import 'package:qr_checkin/features/location/domain/default_location_x.dart';

void main() {
  group('DefaultLocationX', () {
    test('production keeps Jade coordinates', () {
      final loc = DefaultLocationX.forEnvironment(Environment.production);
      expect(loc.id, 'location_x');
      expect(loc.name, 'Jade Luxury Banquets, Mumbai');
      expect(loc.latitude, 18.9888622);
      expect(loc.longitude, 72.8152475);
      expect(loc.radiusMeters, 500);
    });

    test('staging uses Metaphi Excel Plaza pin (not Jade)', () {
      final loc = DefaultLocationX.forEnvironment(Environment.staging);
      expect(loc.id, 'location_x');
      expect(loc.name, 'Metaphi');
      expect(loc.latitude, 19.083304);
      expect(loc.longitude, 72.913425);
      expect(loc.address, contains('Excel Plaza'));
      expect(loc.address, contains('Ghatkopar East'));
      expect(loc.address, isNot(contains('maps.app.goo.gl')));
      expect(loc.latitude, isNot(DefaultLocationX.production.latitude));
      expect(loc.longitude, isNot(DefaultLocationX.production.longitude));
    });

    test('development defaults to production Jade fallback', () {
      final loc = DefaultLocationX.forEnvironment(Environment.development);
      expect(loc.latitude, DefaultLocationX.production.latitude);
      expect(loc.longitude, DefaultLocationX.production.longitude);
    });
  });
}
