import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

/// Optional release crash reporting hook.
///
/// Pass `--dart-define=SENTRY_DSN=...` to enable. When unset, [recordError] is
/// a no-op beyond debug console. Add `sentry_flutter` later without changing
/// call sites.
class CrashReporting {
  CrashReporting._();

  static const _dsn = String.fromEnvironment('SENTRY_DSN', defaultValue: '');
  static bool _enabled = false;

  static bool get isEnabled => _enabled;

  /// Call once from bootstrap when [enable] is true for the environment.
  static Future<void> init({required bool enable}) async {
    final dsn = _dsn.trim();
    if (!enable || dsn.isEmpty) {
      _enabled = false;
      if (kDebugMode && enable && dsn.isEmpty) {
        developer.log(
          'Crash reporting skipped (SENTRY_DSN empty)',
          name: 'CrashReporting',
        );
      }
      return;
    }
    _enabled = true;
    if (kDebugMode) {
      developer.log(
        'Crash reporting enabled (DSN configured; SDK hook ready)',
        name: 'CrashReporting',
      );
    }
  }

  static Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    bool fatal = false,
    String? context,
  }) async {
    if (!_enabled) return;
    if (kDebugMode) {
      developer.log(
        'recordError fatal=$fatal context=$context',
        name: 'CrashReporting',
        error: error,
        stackTrace: stackTrace,
      );
    }
    // Future: Sentry.captureException(error, stackTrace: stackTrace);
  }
}
