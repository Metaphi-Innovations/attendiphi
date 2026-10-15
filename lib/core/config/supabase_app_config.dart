import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../app/config/environment.dart';

/// Attendiphi Supabase project (data + Auth) — sole backend for the app.
///
/// Prefer `--dart-define=SUPABASE_URL=...` and `SUPABASE_ANON_KEY=...`.
/// [scripts/build_web_release.sh] injects the same values into Dart and
/// `web/index.html` meta tags so they cannot drift.
///
/// Do not put service-role keys here.
class SupabaseAppConfig {
  SupabaseAppConfig._();

  /// Production Attendiphi project (publishable anon only).
  static const defaultUrl = 'https://fzghxzybyygslfjyfewu.supabase.co';

  /// Publishable anon / gateway key (safe for client; not a service-role secret).
  static const defaultAnonKey =
      'sb_publishable_sxoF5zOkdBhDJOm3EH6PjA_uSswNowX';

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

  static Environment _environment = Environment.production;

  /// Called from [bootstrap] so staging/dev can resolve different defines.
  static void bindEnvironment(Environment environment) {
    _environment = environment;
  }

  static Environment get environment => _environment;

  static String get url {
    final stagingUrl = dartDefinedStagingUrl.trim();
    if (_environment == Environment.staging && stagingUrl.isNotEmpty) {
      return stagingUrl;
    }
    final fromEnv = dartDefinedUrl.trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    // Release builds must not silently ship an accidental empty key — fall
    // back to the known prod project only when a default is allowed.
    if (kReleaseMode && _environment != Environment.development) {
      return defaultUrl;
    }
    return defaultUrl;
  }

  static String get anonKey {
    final stagingKey = dartDefinedStagingAnonKey.trim();
    if (_environment == Environment.staging && stagingKey.isNotEmpty) {
      return stagingKey;
    }
    final fromEnv = dartDefinedAnonKey.trim();
    if (fromEnv.isNotEmpty) return fromEnv;
    return defaultAnonKey;
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
