import 'dart:async';

import 'package:flutter/widgets.dart';

import '../logger/app_logger.dart';

/// REST poll stream that survives transient network / JWT / RLS blips.
///
/// Unlike a bare `Stream.periodic.asyncMap(fetch)`, a single failed tick does
/// **not** kill the stream. After at least one successful value, later failures
/// keep emitting the last good snapshot so admin dashboards stay populated.
///
/// Polling pauses while the app/tab is not visible to avoid burning API quota
/// when the admin dashboard sits open in a background tab.
Stream<T> resilientPollStream<T>({
  required Future<T> Function() fetch,
  Duration interval = const Duration(seconds: 30),
  Duration initialRetryDelay = const Duration(seconds: 1),
  int maxInitialAttempts = 5,
  String tag = 'ResilientPoll',
}) async* {
  T? last;
  var attempt = 0;

  while (last == null) {
    attempt++;
    try {
      final value = await fetch();
      last = value;
      yield value;
    } catch (e, st) {
      AppLogger.warning(
        'Initial poll failed (attempt $attempt/$maxInitialAttempts): $e',
        tag: tag,
      );
      if (attempt >= maxInitialAttempts) {
        Error.throwWithStackTrace(e, st);
      }
      await Future<void>.delayed(initialRetryDelay);
    }
  }

  while (true) {
    await Future<void>.delayed(interval);
    if (!_isAppVisible) {
      // Skip network while tab/app is backgrounded; keep last snapshot.
      continue;
    }
    try {
      final value = await fetch();
      last = value;
      yield value;
    } catch (e) {
      AppLogger.warning('Poll tick failed (keeping last data): $e', tag: tag);
      // Keep UI on last good data; do not forward the error.
    }
  }
}

bool get _isAppVisible {
  final state = WidgetsBinding.instance.lifecycleState;
  if (state == null) return true;
  return state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;
}

/// Holds a [StreamProvider] in loading until the caller closes the controller.
///
/// Use while admin auth is still hydrating so REST polls do not race the JWT.
StreamController<T> pendingStreamController<T>({
  required void Function(void Function() dispose) onDispose,
}) {
  final controller = StreamController<T>();
  onDispose(controller.close);
  return controller;
}
