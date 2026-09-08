import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app.dart';
import 'app/config/app_config.dart';
import 'app/config/environment.dart';
import 'app/config/firebase_config.dart';
import 'core/logger/app_logger.dart';
import 'features/checkin/data/datasources/device_checkin_service.dart';
import 'firebase_options.dart';

/// Application bootstrap entry point.
Future<void> bootstrap({
  required EnvironmentConfig config,
}) async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      SharedPreferences? prefs;
      try {
        prefs = await SharedPreferences.getInstance();
      } catch (e) {
        AppLogger.warning('Failed to initialize SharedPreferences: $e', tag: 'Bootstrap');
      }

      try {
        await FirebaseConfig.initialize(
          config: config,
          firebaseOptions: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e, st) {
        AppLogger.error(
          'Failed to initialize Firebase: $e',
          error: e,
          stackTrace: st,
          tag: 'Bootstrap',
        );
      }

      runApp(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(
              AppConfig(environment: config),
            ),
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
