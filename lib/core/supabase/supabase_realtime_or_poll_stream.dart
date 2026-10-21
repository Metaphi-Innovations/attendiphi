import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logger/app_logger.dart';

/// Optional local patch from a Realtime row event.
///
/// Return the next snapshot to emit (no REST). Return `null` to fall back to
/// a full [fetch].
typedef RealtimeEventPatcher<T> =
    T? Function(T current, PostgresChangePayload payload);

/// Returns `true` when [next] is equivalent to [previous] for UI purposes.
///
/// When true, the stream skips `add` so Riverpod/UI do not rebuild on identical
/// reconcile polls.
typedef SnapshotUnchanged<T> = bool Function(T previous, T next);

/// Whether [next] should be pushed to stream listeners.
@visibleForTesting
bool shouldEmitRealtimeSnapshot<T>({
  required T? previous,
  required T next,
  SnapshotUnchanged<T>? isUnchanged,
}) {
  if (previous == null || isUnchanged == null) return true;
  return !isUnchanged(previous, next);
}

/// Streams table snapshots via Supabase Realtime + optional reconcile poll.
///
/// 1. Emits one immediate [fetch] result.
/// 2. Subscribes to `postgres_changes` on [table].
/// 3. Prefer [applyRealtimeEvent] to patch local state **without REST**.
///    Incomplete payloads fall back to a debounced full [fetch].
/// 4. If the channel drops, resubscribes with backoff, then runs **one**
///    reconcile [fetch] after subscribe succeeds.
/// 5. Skips refetch while the app/tab is not visible; when it becomes visible
///    again after events were deferred, one refresh runs.
/// 6. Optional slow [reconcileInterval] REST poll only when stale (`null` =
///    no idle poll; reconnect + visibility still reconcile).
Stream<T> supabaseRealtimeOrPollStream<T>({
  required SupabaseClient client,
  required String table,
  required Future<T> Function() fetch,
  String schema = 'public',
  PostgresChangeFilter? filter,
  Duration debounce = const Duration(milliseconds: 150),
  Duration resubscribeBackoff = const Duration(seconds: 3),
  /// Slow safety-net REST poll while the tab is visible. `null` = no idle poll.
  /// Default is 5 minutes — Realtime + reconnect/visibility are primary.
  Duration? reconcileInterval = const Duration(minutes: 5),
  /// When set, INSERT/UPDATE/DELETE update the UI from the WS payload first.
  RealtimeEventPatcher<T>? applyRealtimeEvent,
  /// When set, identical snapshots after fetch/patch are not re-emitted.
  SnapshotUnchanged<T>? isUnchanged,
  String tag = 'SupabaseRealtime',
  @Deprecated('Use reconcileInterval') Duration? pollFallbackInterval,
}) {
  final effectiveReconcile = pollFallbackInterval ?? reconcileInterval;

  return Stream<T>.multi((multi) async {
    T? last;
    var pendingWhileHidden = false;
    var reconcileAfterSubscribe = false;
    Timer? debounceTimer;
    Timer? resubscribeTimer;
    Timer? reconcileTimer;
    RealtimeChannel? channel;
    var disposed = false;
    var channelSeq = 0;
    var refreshInFlight = false;
    DateTime? lastSuccessAt;

    void emitIfChanged(T value, {required String reason}) {
      final previous = last;
      last = value;
      lastSuccessAt = DateTime.now();
      if (!shouldEmitRealtimeSnapshot(
        previous: previous,
        next: value,
        isUnchanged: isUnchanged,
      )) {
        AppLogger.info('reconcile-skipped-unchanged ($reason)', tag: tag);
        return;
      }
      if (!multi.isClosed) multi.add(value);
      AppLogger.info(reason, tag: tag);
    }

    Future<void> refresh({required String reason}) async {
      if (!_isAppVisible) {
        pendingWhileHidden = true;
        return;
      }
      if (refreshInFlight) return;
      pendingWhileHidden = false;
      refreshInFlight = true;
      try {
        final value = await fetch();
        emitIfChanged(value, reason: reason);
      } catch (e) {
        AppLogger.warning('Refresh failed ($reason): $e', tag: tag);
        if (last == null && !multi.isClosed) {
          multi.addError(e);
        }
      } finally {
        refreshInFlight = false;
      }
    }

    void scheduleRefresh(String reason) {
      debounceTimer?.cancel();
      debounceTimer = Timer(debounce, () {
        unawaited(refresh(reason: reason));
      });
    }

    void onRealtimePayload(PostgresChangePayload payload) {
      if (!_isAppVisible) {
        pendingWhileHidden = true;
        return;
      }
      final patcher = applyRealtimeEvent;
      final current = last;
      if (patcher != null && current != null) {
        try {
          final next = patcher(current, payload);
          if (next != null) {
            emitIfChanged(next, reason: 'realtime-patch');
            return;
          }
        } catch (e) {
          AppLogger.warning(
            'Realtime patch failed, falling back to fetch: $e',
            tag: tag,
          );
        }
      }
      scheduleRefresh('realtime-fetch-fallback');
    }

    try {
      last = await fetch();
      lastSuccessAt = DateTime.now();
      multi.add(last as T);
      AppLogger.info('initial-fetch', tag: tag);
    } catch (e, st) {
      multi.addError(e, st);
      return;
    }

    Future<void> attachChannel() async {
      if (disposed) return;
      final seq = ++channelSeq;
      final channelName = 'attendiphi-$table-$seq';

      try {
        final previous = channel;
        channel = null;
        if (previous != null) {
          try {
            await client.removeChannel(previous);
          } catch (_) {}
        }

        final next = client.channel(channelName);
        next.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: schema,
          table: table,
          filter: filter,
          callback: onRealtimePayload,
        );
        next.subscribe((status, [error]) {
          if (disposed || seq != channelSeq) return;
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              AppLogger.info(
                'Realtime subscribed for $schema.$table',
                tag: tag,
              );
              if (reconcileAfterSubscribe) {
                reconcileAfterSubscribe = false;
                unawaited(refresh(reason: 'resubscribe'));
              }
            case RealtimeSubscribeStatus.channelError:
            case RealtimeSubscribeStatus.timedOut:
            case RealtimeSubscribeStatus.closed:
              AppLogger.warning(
                'Realtime $status for $schema.$table'
                '${error != null ? ': $error' : ''} — will resubscribe',
                tag: tag,
              );
              reconcileAfterSubscribe = true;
              resubscribeTimer?.cancel();
              resubscribeTimer = Timer(resubscribeBackoff, () {
                AppLogger.info('resubscribe', tag: tag);
                unawaited(attachChannel());
              });
          }
        });
        channel = next;
      } catch (e) {
        AppLogger.warning(
          'Realtime setup failed for $schema.$table: $e — will retry',
          tag: tag,
        );
        reconcileAfterSubscribe = true;
        resubscribeTimer?.cancel();
        resubscribeTimer = Timer(resubscribeBackoff, () {
          AppLogger.info('resubscribe', tag: tag);
          unawaited(attachChannel());
        });
      }
    }

    await attachChannel();

    if (effectiveReconcile != null && effectiveReconcile > Duration.zero) {
      // Check less often than the stale window; poll only when truly stale.
      final tick = Duration(
        milliseconds: (effectiveReconcile.inMilliseconds / 2)
            .clamp(30 * 1000, effectiveReconcile.inMilliseconds)
            .toInt(),
      );
      reconcileTimer = Timer.periodic(tick, (_) {
        if (disposed || !_isAppVisible) return;
        final lastOk = lastSuccessAt;
        if (lastOk != null &&
            DateTime.now().difference(lastOk) < effectiveReconcile) {
          return;
        }
        unawaited(refresh(reason: 'reconcile-poll'));
      });
    }

    final lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.resumed && pendingWhileHidden) {
          scheduleRefresh('tab-visible');
        }
      },
    );

    multi.onCancel = () async {
      disposed = true;
      debounceTimer?.cancel();
      resubscribeTimer?.cancel();
      reconcileTimer?.cancel();
      lifecycle.dispose();
      final ch = channel;
      channel = null;
      if (ch != null) {
        try {
          await client.removeChannel(ch);
        } catch (_) {}
      }
    };
  });
}

bool get _isAppVisible {
  final state = WidgetsBinding.instance.lifecycleState;
  if (state == null) return true;
  return state == AppLifecycleState.resumed ||
      state == AppLifecycleState.inactive;
}
