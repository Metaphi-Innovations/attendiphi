import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/environment.dart';

/// Attendiphi Supabase project (data + Auth) — sole backend for the app.
///
/// Resolution by [Environment]:
/// - **development** → local Docker (`SUPABASE_URL_LOCAL` / `127.0.0.1:54321`)
/// - **staging** → attendiphi-test (`SUPABASE_URL_STAGING` / cloud defaults)
/// - **production** → live Attendiphi (`SUPABASE_URL` / production defaults)
///
/// Do not put service-role keys here.
class SupabaseAppConfig {
  SupabaseAppConfig._();

  /// Production Attendiphi project (publishable anon only).
  static const defaultUrl = 'https://fzghxzybyygslfjyfewu.supabase.co';

  /// Publishable anon / gateway key (safe for client; not a service-role secret).
  static const defaultAnonKey =
      'sb_publishable_sxoF5zOkdBhDJOm3EH6PjA_uSswNowX';

  /// Staging / attendiphi-test project (publishable anon only).
  static const defaultStagingUrl =
      'https://ofieqhdkvofsjnpxkmee.supabase.co';

  /// Staging publishable anon key (client-safe; not service-role).
  static const defaultStagingAnonKey =
      'sb_publishable_S3HgjDPER8qwglSX1HIrLg_IyFh6X2_';

  /// Local Supabase CLI default API URL (`supabase start`).
  static const defaultLocalUrl = 'http://127.0.0.1:54321';

  /// Well-known local anon JWT from Supabase CLI demo project (not a cloud secret).
  static const defaultLocalAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0';

  static const dartDefinedUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const dartDefinedAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Optional staging overrides (used when [Environment.staging] and set).
  static const dartDefinedStagingUrl = String.fromEnvironment(
    'SUPABASE_URL_STAGING',
    defaultValue: '',
  );

  static const dartDefinedStagingAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY_STAGING',
    defaultValue: '',
  );

  /// Optional local Docker overrides (used when [Environment.development]).
  static const dartDefinedLocalUrl = String.fromEnvironment(
    'SUPABASE_URL_LOCAL',
    defaultValue: '',
  );

  static const dartDefinedLocalAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY_LOCAL',
    defaultValue: '',
  );

  static Environment _environment = Environment.production;

  /// Called from [bootstrap] so staging/dev can resolve different defines.
  static void bindEnvironment(Environment environment) {
    _environment = environment;
  }

  static Environment get environment => _environment;

  static String get url {
    switch (_environment) {
      case Environment.development:
        final localUrl = dartDefinedLocalUrl.trim();
        if (localUrl.isNotEmpty) return localUrl;
        return defaultLocalUrl;
      case Environment.staging:
        final stagingUrl = dartDefinedStagingUrl.trim();
        if (stagingUrl.isNotEmpty) return stagingUrl;
        return defaultStagingUrl;
      case Environment.production:
        final fromEnv = dartDefinedUrl.trim();
        if (fromEnv.isNotEmpty) return fromEnv;
        return defaultUrl;
    }
  }

  static String get anonKey {
    switch (_environment) {
      case Environment.development:
        final localKey = dartDefinedLocalAnonKey.trim();
        if (localKey.isNotEmpty) return localKey;
        return defaultLocalAnonKey;
      case Environment.staging:
        final stagingKey = dartDefinedStagingAnonKey.trim();
        if (stagingKey.isNotEmpty) return stagingKey;
        return defaultStagingAnonKey;
      case Environment.production:
        final fromEnv = dartDefinedAnonKey.trim();
        if (fromEnv.isNotEmpty) return fromEnv;
        return defaultAnonKey;
    }
  }

  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;

  /// True when debug/profile is pointed at the production host (avoid if possible).
  static bool get isDebugUsingProductionHost {
    if (kReleaseMode) return false;
    if (_environment == Environment.production) return true;
    return Uri.tryParse(url)?.host == Uri.parse(defaultUrl).host;
  }

  /// Shared client after [Supabase.initialize]. Throws if not initialized.
  static SupabaseClient get client => Supabase.instance.client;
}
