import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'app/config/environment.dart';
import 'app/config/supabase_bootstrap.dart';
import 'app/router/configure_url_strategy.dart';
import 'core/config/supabase_app_config.dart';
import 'core/logger/app_logger.dart';
import 'core/observability/crash_reporting.dart';
import 'features/checkin/data/datasources/device_checkin_service.dart';

/// Application bootstrap entry point (Supabase-only — no Firebase).
Future<void> bootstrap({required EnvironmentConfig config}) async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      configureUrlStrategy();
      AppLogger.init();
      SupabaseAppConfig.bindEnvironment(config.environment);
      // Release uses CSS / bundled fonts; avoid runtime Google Fonts CDN fetch.
      GoogleFonts.config.allowRuntimeFetching = !kReleaseMode;
      await CrashReporting.init(enable: config.enableCrashReporting);

      if (SupabaseAppConfig.isDebugUsingProductionHost &&
          config.isDevelopment) {
        AppLogger.warning(
          'Debug build is using production Supabase host '
          '(${Uri.parse(SupabaseAppConfig.url).host}). Prefer '
          'SUPABASE_URL_STAGING / a non-prod project when testing.',
          tag: 'Bootstrap',
        );
      }

      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        AppLogger.warning(
          'Failed to initialize SharedPreferences: $e',
          tag: 'Bootstrap',
        );
      }

      try {
        await SupabaseBootstrap.initialize();
      } catch (e, st) {
        AppLogger.error(
          'Failed to initialize Supabase: $e',
          error: e,
          stackTrace: st,
          tag: 'Bootstrap',
        );
      }

      runApp(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(AppConfig(environment: config)),
            if (prefs != null)
              sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const QrCheckInApp(),
        ),
      );
    },
    (error, stackTrace) {
      AppLogger.error(
        'Uncaught error in runZonedGuarded',
        error: error,
        stackTrace: stackTrace,
        tag: 'Bootstrap',
        fatal: true,
      );
    },
  );
}

/// Default entry point configured for live production.
void main() {
  bootstrap(config: EnvironmentConfig.production);
}
