/// Unit for editing venue check-in radius in the admin restrictions UI.
enum VenueRadiusUnit { meters, kilometers }

/// Conversion + validation for venue radius (always stored as meters).
class VenueRadius {
  VenueRadius._();

  /// Max allowed radius: 100 km.
  static const double maxMeters = 100000;

  /// Min allowed radius (strictly greater than 0).
  static const double minMeters = 0.01;

  static double toMeters(double value, VenueRadiusUnit unit) {
    return switch (unit) {
      VenueRadiusUnit.meters => value,
      VenueRadiusUnit.kilometers => value * 1000,
    };
  }

  static double fromMeters(double meters, VenueRadiusUnit unit) {
    return switch (unit) {
      VenueRadiusUnit.meters => meters,
      VenueRadiusUnit.kilometers => meters / 1000,
    };
  }

  /// Prefer meters for values under 1000 m so the UI stays readable;
  /// otherwise default to kilometers.
  static VenueRadiusUnit preferredUnit(double meters) {
    return meters >= 1000 ? VenueRadiusUnit.kilometers : VenueRadiusUnit.meters;
  }

  /// Parses a display string for [unit] into meters, or null if invalid.
  static double? tryParseToMeters(String raw, VenueRadiusUnit unit) {
    final trimmed = raw.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return null;
    final value = double.tryParse(trimmed);
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (value <= 0) return null;
    final meters = toMeters(value, unit);
    if (meters < minMeters || meters > maxMeters) return null;
    return meters;
  }

  /// Formats meters for display in [unit] without trailing junk.
  static String formatForDisplay(double meters, VenueRadiusUnit unit) {
    final value = fromMeters(meters, unit);
    if (value == value.roundToDouble()) {
      return value.round().toString();
    }
    // Keep up to 3 decimal places for km (e.g. 0.7), trim trailing zeros.
    final fixed = value.toStringAsFixed(3);
    return fixed.replaceFirst(RegExp(r'\.?0+$'), '');
  }
}
