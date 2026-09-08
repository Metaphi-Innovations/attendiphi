import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/location/data/models/location_config_model.dart';

void main() {
  group('LocationConfigModel', () {
    test('fromMap creates valid LocationConfigModel with defaults', () {
      final map = {
        'name': 'Main Branch',
        'latitude': 19.0760,
        'longitude': 72.8777,
        'radiusMeters': 500,
        'isActive': true,
        'address': 'Nariman Point, Mumbai',
      };

      final model = LocationConfigModel.fromMap('loc_001', map);

      expect(model.id, 'loc_001');
      expect(model.name, 'Main Branch');
      expect(model.latitude, 19.0760);
      expect(model.longitude, 72.8777);
      expect(model.radiusMeters, 500.0);
      expect(model.isActive, isTrue);
      expect(model.address, 'Nariman Point, Mumbai');
    });

    test('toMap serializes properly', () {
      const model = LocationConfigModel(
        id: 'loc_002',
        name: 'Delhi Office',
        latitude: 28.6139,
        longitude: 77.2090,
        radiusMeters: 750.0,
        isActive: false,
      );

      final map = model.toMap();

      expect(map['name'], 'Delhi Office');
      expect(map['latitude'], 28.6139);
      expect(map['longitude'], 77.2090);
      expect(map['radiusMeters'], 750.0);
      expect(map['isActive'], isFalse);
    });

    test('handles missing or stringified numbers gracefully', () {
      final map = {
        'name': 'Fallback Test',
        'latitude': '19.1234',
        'longitude': '72.5678',
      };

      final model = LocationConfigModel.fromMap('loc_003', map);

      expect(model.latitude, 19.1234);
      expect(model.longitude, 72.5678);
      expect(model.radiusMeters, 500.0); // Default fallback
      expect(model.isActive, isTrue); // Default fallback
    });
  });
}
