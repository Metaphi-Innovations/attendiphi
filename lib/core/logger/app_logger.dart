import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import '../errors/app_exception.dart';
import '../observability/crash_reporting.dart';

/// Structured logging utility (console in debug; optional crash reporting).
///
/// **Never log sensitive data** (phone numbers, photos, tokens).
class AppLogger {
  AppLogger._();

  /// Initialize the logger (no-op hook kept for bootstrap call sites).
  static void init() {}

  /// Redacts common PII patterns from log / crash messages.
  static String redact(String input) {
    var out = input;
    // E.164 / Indian mobiles (+91XXXXXXXXXX or 10-digit)
    out = out.replaceAllMapped(
      RegExp(r'\+?91[\s-]*[6-9]\d{9}\b|[6-9]\d{9}\b'),
      (_) => '[phone]',
    );
    // Emails
    out = out.replaceAllMapped(
      RegExp(r'[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}', caseSensitive: false),
      (_) => '[email]',
    );
    // Long base64-ish blobs
    out = out.replaceAllMapped(
      RegExp(r'(?:[A-Za-z0-9+/]{40,}={0,2})'),
      (_) => '[redacted-blob]',
    );
    // Bearer / JWT fragments
    out = out.replaceAllMapped(
      RegExp(r'(Bearer\s+)[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      (m) => '${m[1]}[token]',
    );
    return out;
  }

  static void debug(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log(redact(message), name: tag ?? 'APP');
    }
  }

  static void info(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('[INFO] ${redact(message)}', name: tag ?? 'APP');
    }
  }

  static void warning(String message, {String? tag}) {
    if (kDebugMode) {
      developer.log('[WARN] ${redact(message)}', name: tag ?? 'APP');
    }
  }

  static void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? tag,
    bool fatal = false,
  }) {
    final safe = redact(message);
    if (kDebugMode) {
      developer.log(
        '[ERROR] $safe${fatal ? ' (fatal)' : ''}',
        name: tag ?? 'APP',
        error: error,
        stackTrace: stackTrace,
      );
    }
    if (CrashReporting.isEnabled) {
      // Fire-and-forget; never block UI on reporting.
      // ignore: unawaited_futures
      CrashReporting.recordError(
        error ?? safe,
        stackTrace,
        fatal: fatal,
        context: tag,
      );
    }
  }

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

  static void setContext(String key, String value) {
    if (kDebugMode) {
      developer.log('context $key=${redact(value)}', name: 'APP');
    }
  }
}
