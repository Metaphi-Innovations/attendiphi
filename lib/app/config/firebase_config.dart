import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../core/logger/app_logger.dart';
import '../../core/notifications/firebase_notification_service.dart';
import 'environment.dart';

/// Initializes Firebase services based on the current [EnvironmentConfig].
///
/// Must be called before [runApp] in each environment entry point.
class FirebaseConfig {
  FirebaseConfig._();

  static Future<void> initialize({
    required EnvironmentConfig config,
    required FirebaseOptions firebaseOptions,
  }) async {
    // Initialize Firebase Core
    await Firebase.initializeApp(options: firebaseOptions);

    // Initialize FCM Background Handler (Mobile only)
    if (!kIsWeb) {
      try {
        FirebaseMessaging.onBackgroundMessage(
          firebaseMessagingBackgroundHandler,
        );
      } catch (e) {
        AppLogger.warning(
          'Failed to register FCM background handler: $e',
          tag: 'FirebaseConfig',
        );
      }
    }

    // Initialize Crashlytics (not supported on web)
    if (!kIsWeb && config.enableCrashlytics) {
      try {
        await FirebaseCrashlytics.instance
            .setCrashlyticsCollectionEnabled(true);

        // Catch Flutter framework errors
        FlutterError.onError = (details) {
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };

        // Catch async errors
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };

        AppLogger.init(crashlytics: FirebaseCrashlytics.instance);
      } catch (e) {
        AppLogger.init();
      }
    } else {
      if (!kIsWeb) {
        try {
          await FirebaseCrashlytics.instance
              .setCrashlyticsCollectionEnabled(false);
        } catch (_) {}
      }
      AppLogger.init();
    }

    // Initialize App Check (mobile platforms)
    if (!kIsWeb && config.enableAppCheck) {
      try {
        // ignore: deprecated_member_use
        await FirebaseAppCheck.instance.activate(
          // ignore: deprecated_member_use
          androidProvider: config.appCheckDebugMode
              ? AndroidProvider.debug
              : AndroidProvider.playIntegrity,
          // ignore: deprecated_member_use
          appleProvider: config.appCheckDebugMode
              ? AppleProvider.debug
              : AppleProvider.appAttest,
        );
      } catch (_) {}
    }

    AppLogger.info(
      'Firebase initialized for ${config.environment.name}',
      tag: 'FirebaseConfig',
    );
  }
}
