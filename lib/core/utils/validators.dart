import '../constants/app_constants.dart';
import '../l10n/app_strings.dart';

/// Form validation utilities.
///
/// Each validator returns `null` if valid, or an error message string if invalid.
/// These are designed for use with Flutter's [TextFormField.validator].
class Validators {
  Validators._();

  /// Validates a person's name.
  ///
  /// Rules:
  /// - Required (non-empty after trimming)
  /// - At least [AppConstants.nameMinLength] characters
  /// - At most [AppConstants.nameMaxLength] characters
  /// - Only letters, spaces, hyphens, apostrophes, and periods
  static String? validateName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return AppStrings.validationNameRequired;
    }
    if (trimmed.length < AppConstants.nameMinLength) {
      return AppStrings.validationNameTooShort;
    }
    if (trimmed.length > AppConstants.nameMaxLength) {
      return AppStrings.validationNameTooLong;
    }
    // Allow Unicode letters, spaces, hyphens, apostrophes, periods
    final namePattern = RegExp(r"^[\p{L}\s\-'.]+$", unicode: true);
    if (!namePattern.hasMatch(trimmed)) {
      return AppStrings.validationNameInvalid;
    }
    return null;
  }

  /// Validates an Indian phone number.
  ///
  /// Rules:
  /// - Required (non-empty)
  /// - Exactly 10 digits
  /// - Starts with 6, 7, 8, or 9
  /// - No spaces or special characters (after normalization)
  static String? validatePhone(String? value) {
    final cleaned = (value ?? '').replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    if (cleaned.isEmpty) {
      return AppStrings.validationPhoneRequired;
    }

    // Remove country code prefix if present
    final digits = cleaned.startsWith('91') && cleaned.length == 12
        ? cleaned.substring(2)
        : cleaned;

    if (digits.length != AppConstants.phoneNumberLength) {
      return AppStrings.validationPhoneInvalid;
    }

    // Indian mobile numbers start with 6-9
    final phonePattern = RegExp(r'^[6-9]\d{9}$');
    if (!phonePattern.hasMatch(digits)) {
      return AppStrings.validationPhoneInvalid;
    }

    return null;
  }

  /// Normalizes a phone number to a consistent format.
  ///
  /// Returns just the 10-digit number without country code.
  static String normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.startsWith('91') && digits.length == 12) {
      return digits.substring(2);
    }
    if (digits.startsWith('0') && digits.length == 11) {
      return digits.substring(1);
    }
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Returns the full phone number with Indian country code.
  static String formatPhoneWithCountryCode(String phone) {
    final normalized = normalizePhone(phone);
    return '${AppConstants.phoneCountryCode}$normalized';
  }

  /// Validates an email address.
  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email address is required.';
    }
    final emailPattern = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailPattern.hasMatch(trimmed)) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Masks a phone number for display (privacy).
  ///
  /// Example: "9876543210" → "98****3210"
  static String maskPhone(String phone) {
    final normalized = normalizePhone(phone);
    if (normalized.length < 6) return normalized;
    return '${normalized.substring(0, 2)}****${normalized.substring(normalized.length - 4)}';
  }
}
