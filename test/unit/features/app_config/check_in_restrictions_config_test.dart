import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/app_config/domain/entities/check_in_restrictions_config.dart';

void main() {
  group('CheckInRestrictionsConfig', () {
    test('legacy master maps all three flags', () {
      final on = CheckInRestrictionsConfig.fromLegacyMaster(true);
      expect(on.locationRestrictionEnabled, isTrue);
      expect(on.dateRestrictionEnabled, isTrue);
      expect(on.deviceRestrictionEnabled, isTrue);
      expect(on.restrictionsEnabled, isTrue);

      final off = CheckInRestrictionsConfig.fromLegacyMaster(false);
      expect(off.locationRestrictionEnabled, isFalse);
      expect(off.dateRestrictionEnabled, isFalse);
      expect(off.deviceRestrictionEnabled, isFalse);
      expect(off.restrictionsEnabled, isFalse);
    });

    test('combined getter is OR of granular flags', () {
      const locationOnly = CheckInRestrictionsConfig(
        locationRestrictionEnabled: true,
        dateRestrictionEnabled: false,
        deviceRestrictionEnabled: false,
      );
      expect(locationOnly.restrictionsEnabled, isTrue);

      const dateOnly = CheckInRestrictionsConfig(
        locationRestrictionEnabled: false,
        dateRestrictionEnabled: true,
        deviceRestrictionEnabled: false,
      );
      expect(dateOnly.restrictionsEnabled, isTrue);

      const deviceOnly = CheckInRestrictionsConfig(
        locationRestrictionEnabled: false,
        dateRestrictionEnabled: false,
        deviceRestrictionEnabled: true,
      );
      expect(deviceOnly.restrictionsEnabled, isTrue);

      const neither = CheckInRestrictionsConfig(
        locationRestrictionEnabled: false,
        dateRestrictionEnabled: false,
        deviceRestrictionEnabled: false,
      );
      expect(neither.restrictionsEnabled, isFalse);
    });
  });
}
