import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/location/domain/venue_radius.dart';

void main() {
  group('VenueRadius conversion', () {
    test('km to meters', () {
      expect(VenueRadius.toMeters(30, VenueRadiusUnit.kilometers), 30000);
      expect(VenueRadius.toMeters(0.7, VenueRadiusUnit.kilometers), 700);
    });

    test('meters to meters is identity', () {
      expect(VenueRadius.toMeters(700, VenueRadiusUnit.meters), 700);
    });

    test('fromMeters converts for display', () {
      expect(
        VenueRadius.fromMeters(30000, VenueRadiusUnit.kilometers),
        30,
      );
      expect(VenueRadius.fromMeters(700, VenueRadiusUnit.meters), 700);
      expect(VenueRadius.fromMeters(700, VenueRadiusUnit.kilometers), 0.7);
    });

    test('preferredUnit uses km for >= 1000 m', () {
      expect(VenueRadius.preferredUnit(500), VenueRadiusUnit.meters);
      expect(VenueRadius.preferredUnit(999), VenueRadiusUnit.meters);
      expect(VenueRadius.preferredUnit(1000), VenueRadiusUnit.kilometers);
      expect(VenueRadius.preferredUnit(30000), VenueRadiusUnit.kilometers);
    });

    test('formatForDisplay trims trailing zeros', () {
      expect(
        VenueRadius.formatForDisplay(700, VenueRadiusUnit.kilometers),
        '0.7',
      );
      expect(
        VenueRadius.formatForDisplay(30000, VenueRadiusUnit.kilometers),
        '30',
      );
      expect(VenueRadius.formatForDisplay(500, VenueRadiusUnit.meters), '500');
    });
  });

  group('VenueRadius.tryParseToMeters', () {
    test('parses valid km and m', () {
      expect(
        VenueRadius.tryParseToMeters('30', VenueRadiusUnit.kilometers),
        30000,
      );
      expect(
        VenueRadius.tryParseToMeters('700', VenueRadiusUnit.meters),
        700,
      );
      expect(
        VenueRadius.tryParseToMeters('0.7', VenueRadiusUnit.kilometers),
        700,
      );
    });

    test('rejects empty, non-numeric, zero, negative', () {
      expect(VenueRadius.tryParseToMeters('', VenueRadiusUnit.meters), isNull);
      expect(
        VenueRadius.tryParseToMeters('abc', VenueRadiusUnit.meters),
        isNull,
      );
      expect(VenueRadius.tryParseToMeters('0', VenueRadiusUnit.meters), isNull);
      expect(
        VenueRadius.tryParseToMeters('-5', VenueRadiusUnit.meters),
        isNull,
      );
    });

    test('rejects above max 100 km', () {
      expect(
        VenueRadius.tryParseToMeters('100001', VenueRadiusUnit.meters),
        isNull,
      );
      expect(
        VenueRadius.tryParseToMeters('101', VenueRadiusUnit.kilometers),
        isNull,
      );
      expect(
        VenueRadius.tryParseToMeters('100', VenueRadiusUnit.kilometers),
        100000,
      );
    });
  });

  group('VenueRadius.formatFriendly', () {
    test('uses km for radii >= 1000 m', () {
      expect(VenueRadius.formatFriendly(50000), '50 km');
      expect(VenueRadius.formatFriendly(30000), '30 km');
      expect(VenueRadius.formatFriendly(1000), '1 km');
      expect(VenueRadius.formatFriendly(700), '700 m');
      expect(VenueRadius.formatFriendly(500), '500 m');
    });
  });

  group('VenueRadius.matchesLoadedMeters', () {
    test('detects unchanged loaded value vs edited draft', () {
      expect(
        VenueRadius.matchesLoadedMeters(
          raw: '500',
          unit: VenueRadiusUnit.meters,
          loadedMeters: 500,
        ),
        isTrue,
      );
      expect(
        VenueRadius.matchesLoadedMeters(
          raw: '50',
          unit: VenueRadiusUnit.meters,
          loadedMeters: 500,
        ),
        isFalse,
      );
    });
  });
}
