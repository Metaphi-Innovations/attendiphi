import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/supabase_app_config.dart';
import '../../core/logger/app_logger.dart';

/// Initializes the Attendiphi Supabase client (data + auth project).
///
/// Supabase-only bootstrap — no Firebase.
class SupabaseBootstrap {
  SupabaseBootstrap._();

  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  static Future<void> initialize() async {
    if (_initialized) return;

    if (!SupabaseAppConfig.isConfigured) {
      AppLogger.warning(
        'Supabase skipped: URL or anon key missing.',
        tag: 'SupabaseBootstrap',
      );
      return;
    }

    await Supabase.initialize(
      url: SupabaseAppConfig.url,
      // supabase_flutter 2.18+ prefers publishableKey (anon key still works as value).
      publishableKey: SupabaseAppConfig.anonKey,
    );
    _initialized = true;
    AppLogger.info(
      'Supabase initialized (${Uri.parse(SupabaseAppConfig.url).host})',
      tag: 'SupabaseBootstrap',
    );
  }
}
