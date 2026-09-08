import 'dart:developer' as developer;

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';

/// Structured logging utility with Crashlytics integration.
///
/// In debug mode, logs are printed to the console.
/// In release mode, errors are sent to Firebase Crashlytics.
///
/// **Never log sensitive data** (phone numbers, photos, tokens).
class AppLogger {
  AppLogger._();

  static FirebaseCrashlytics? _crashlytics;

  /// Initialize the logger with a Crashlytics instance.
  ///
  /// Should be called once during app startup after Firebase initialization.
  static void init({FirebaseCrashlytics? crashlytics}) {
    _crashlytics = crashlytics;
  }

  /// Log a debug-level message.
  ///
  /// Only appears in debug mode. Never sent to Crashlytics.
  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(message, name: tag ?? 'APP');
    }
  }

  /// Log an informational message.
  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('[INFO] $message', name: tag ?? 'APP');
    }
    _crashlytics?.log(message);
  }

  /// Log a warning.
  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('[WARN] $message', name: tag ?? 'APP');
    }
    _crashlytics?.log('[WARN] $message');
  }

  /// Log an error with optional exception and stack trace.
  ///
  /// Automatically records to Crashlytics in release builds.
  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    bool fatal = false,
  }) {
    if (kDebugMode) {
      developer.log(
        '[ERROR] $message',
        name: tag ?? 'APP',
        error: error,
        stackTrace: stackTrace,
      );
    }

    if (error != null) {
      _crashlytics?.recordError(
        error,
        stackTrace ?? StackTrace.current,
        reason: message,
        fatal: fatal,
      );
    } else {
      _crashlytics?.log('[ERROR] $message');
    }
  }

  /// Log an [AppException] with context.
  ///
  /// Uses the technical message for logging (not the user message).
  static void logException(
    AppException exception, {
    String? context,
    String? tag,
  }) {
    final contextPrefix = context != null ? '[$context] ' : '';
    error(
      '$contextPrefix${exception.technicalMessage}',
      error: exception.originalError ?? exception,
      stackTrace: exception.stackTrace,
      tag: tag,
    );
  }

  /// Set a Crashlytics key-value pair for additional context.
  ///
  /// **Never set sensitive values** (phone numbers, tokens, etc.)
  static void setContext(String key, String value) {
    _crashlytics?.setCustomKey(key, value);
  }
}
