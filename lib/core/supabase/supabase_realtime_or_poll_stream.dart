import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logger/app_logger.dart';

/// Streams table snapshots via Supabase Realtime only (no periodic REST poll).
///
/// 1. Emits one immediate [fetch] result.
/// 2. Subscribes to `postgres_changes` on [table].
/// 3. Each Realtime event debounces a single [fetch] (full snapshot — avoids
///    applying partial payloads / replica-identity gaps).
/// 4. If the channel drops, resubscribes with backoff — still no timer poll.
/// 5. Skips refetch while the app/tab is not visible; when it becomes visible
///    again after events were deferred, one refresh runs.
Stream<T> supabaseRealtimeOrPollStream<T>({
  required SupabaseClient client,
  required String table,
  required Future<T> Function() fetch,
  String schema = 'public',
  PostgresChangeFilter? filter,
  Duration debounce = const Duration(milliseconds: 500),
  Duration resubscribeBackoff = const Duration(seconds: 3),
  String tag = 'SupabaseRealtime',
  // Ignored — kept so older call sites compile; polling is disabled.
  @Deprecated('Realtime-only: periodic poll removed')
  Duration? pollFallbackInterval,
  @Deprecated('Realtime-only: reconcile poll removed')
  Duration? reconcileInterval,
}) {
  return Stream<T>.multi((multi) async {
    T? last;
    var pendingWhileHidden = false;
    Timer? debounceTimer;
    Timer? resubscribeTimer;
    RealtimeChannel? channel;
    var disposed = false;
    var channelSeq = 0;

    Future<void> refresh({required String reason}) async {
      if (!_isAppVisible) {
        pendingWhileHidden = true;
        return;
      }
      pendingWhileHidden = false;
      try {
        final value = await fetch();
        last = value;
        if (!multi.isClosed) multi.add(value);
      } catch (e) {
        AppLogger.warning('Refresh failed ($reason): $e', tag: tag);
        if (last == null && !multi.isClosed) {
          multi.addError(e);
        }
      }
    }

    void scheduleRefresh(String reason) {
      debounceTimer?.cancel();
      debounceTimer = Timer(debounce, () {
        unawaited(refresh(reason: reason));
      });
    }

    try {
      last = await fetch();
      multi.add(last as T);
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
          callback: (_) => scheduleRefresh('realtime-event'),
        );
        next.subscribe((status, [error]) {
          if (disposed || seq != channelSeq) return;
          switch (status) {
            case RealtimeSubscribeStatus.subscribed:
              AppLogger.info(
                'Realtime subscribed for $schema.$table',
                tag: tag,
              );
            case RealtimeSubscribeStatus.channelError:
            case RealtimeSubscribeStatus.timedOut:
            case RealtimeSubscribeStatus.closed:
              AppLogger.warning(
                'Realtime $status for $schema.$table'
                '${error != null ? ': $error' : ''} — will resubscribe',
                tag: tag,
              );
              resubscribeTimer?.cancel();
              resubscribeTimer = Timer(resubscribeBackoff, () {
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
        resubscribeTimer?.cancel();
        resubscribeTimer = Timer(resubscribeBackoff, () {
          unawaited(attachChannel());
        });
      }
    }

    await attachChannel();

    // One catch-up fetch when returning to a visible tab (not a periodic poll).
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
