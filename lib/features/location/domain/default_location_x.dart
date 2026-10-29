import '../../../app/config/environment.dart';
import '../../../core/config/supabase_app_config.dart';
import '../../../core/constants/app_constants.dart';
import 'entities/location_config.dart';

/// Canonical `location_x` venue defaults by app environment.
///
/// - **Production** → Jade Luxury Banquets (live pin).
/// - **Staging** → Metaphi staging test pin (for attendiphi.staging.metaphi.in).
/// - **Development** → same as production fallback (local/prod-shaped defaults);
///   use `main_staging.dart` / staging seed when testing the staging pin.
class DefaultLocationX {
  DefaultLocationX._();

  static const id = 'location_x';

  /// Live production venue (attendiphi.metaphi.in).
  static const production = LocationConfig(
    id: id,
    name: 'Jade Luxury Banquets, Mumbai',
    latitude: 18.9888622,
    longitude: 72.8152475,
    radiusMeters: AppConstants.defaultRadiusMeters,
    isActive: true,
    address:
        'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
  );

  /// Staging / attendiphi-test venue (attendiphi.staging.metaphi.in).
  static const staging = LocationConfig(
    id: id,
    name: 'Attendiphi Staging Test Venue',
    latitude: 19.083304,
    longitude: 72.913425,
    radiusMeters: AppConstants.defaultRadiusMeters,
    isActive: true,
    address: 'https://maps.app.goo.gl/oNVd6NJVhc5ZfSY99?g_st=ic',
  );

  /// Resolves default `location_x` for [environment].
  static LocationConfig forEnvironment(Environment environment) {
    switch (environment) {
      case Environment.staging:
        return staging;
      case Environment.development:
      case Environment.production:
        return production;
    }
  }

  /// Uses [SupabaseAppConfig.environment] bound at bootstrap.
  static LocationConfig current() =>
      forEnvironment(SupabaseAppConfig.environment);
}
