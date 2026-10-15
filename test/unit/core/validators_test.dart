import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/l10n/app_strings.dart';
import 'package:qr_checkin/core/utils/validators.dart';

void main() {
  group('Validators - validateName', () {
    test('returns error when name is null or empty', () {
      expect(Validators.validateName(null), AppStrings.validationNameRequired);
      expect(Validators.validateName(''), AppStrings.validationNameRequired);
      expect(Validators.validateName('   '), AppStrings.validationNameRequired);
    });

    test('returns error when name is too short', () {
      expect(Validators.validateName('A'), AppStrings.validationNameTooShort);
    });

    test('returns error when name is too long (> 100 chars)', () {
      final longName = 'A' * 101;
      expect(
        Validators.validateName(longName),
        AppStrings.validationNameTooLong,
      );
    });

    test('returns null for valid names', () {
      expect(Validators.validateName('John Doe'), isNull);
      expect(Validators.validateName("Jane O'Connor"), isNull);
      expect(Validators.validateName('Dr. Alice Smith-Jones'), isNull);
      expect(Validators.validateName('Rahul Sharma'), isNull);
    });
  });

  group('Validators - validatePhone', () {
    test('returns error when phone is null or empty', () {
      expect(
        Validators.validatePhone(null),
        AppStrings.validationPhoneRequired,
      );
      expect(Validators.validatePhone(''), AppStrings.validationPhoneRequired);
    });

    test('returns error when phone number has incorrect length', () {
      expect(
        Validators.validatePhone('98765'),
        AppStrings.validationPhoneInvalid,
      );
      expect(
        Validators.validatePhone('9876543210123'),
        AppStrings.validationPhoneInvalid,
      );
    });

    test('returns error for invalid starting digit in India (not 6-9)', () {
      expect(
        Validators.validatePhone('1234567890'),
        AppStrings.validationPhoneInvalid,
      );
      expect(
        Validators.validatePhone('5555555555'),
        AppStrings.validationPhoneInvalid,
      );
    });

    test('returns null for valid Indian phone numbers', () {
      expect(Validators.validatePhone('9876543210'), isNull);
      expect(Validators.validatePhone('8765432109'), isNull);
      expect(Validators.validatePhone('7654321098'), isNull);
      expect(Validators.validatePhone('6543210987'), isNull);
      expect(Validators.validatePhone('+919876543210'), isNull);
      expect(Validators.validatePhone('+91 98765-43210'), isNull);
    });
  });

  group('Validators - normalizePhone and maskPhone', () {
    test('normalizePhone strips country code and symbols', () {
      expect(Validators.normalizePhone('+91 98765-43210'), '9876543210');
      expect(Validators.normalizePhone('919876543210'), '9876543210');
      expect(Validators.normalizePhone('09876543210'), '9876543210');
      expect(Validators.normalizePhone('(987) 654-3210'), '9876543210');
      expect(Validators.normalizePhone('+91 (98765) 43210'), '9876543210');
    });

    test('formatPhoneWithCountryCode formats with +91', () {
      expect(
        Validators.formatPhoneWithCountryCode('9876543210'),
        '+919876543210',
      );
      expect(
        Validators.formatPhoneWithCountryCode('09876543210'),
        '+919876543210',
      );
      expect(
        Validators.formatPhoneWithCountryCode('+91 98765-43210'),
        '+919876543210',
      );
    });

    test('maskPhone masks middle digits for privacy', () {
      expect(Validators.maskPhone('9876543210'), '98****3210');
      expect(Validators.maskPhone('+91 9876543210'), '98****3210');
    });
  });
}
