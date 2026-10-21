import 'package:supabase_flutter/supabase_flutter.dart';

/// Applies a Postgres Realtime row change to an in-memory list without REST.
///
/// Returns `null` when the payload is incomplete so the caller can fall back
/// to a full fetch.
List<T>? patchRealtimeListById<T>({
  required List<T> current,
  required PostgresChangePayload payload,
  required String Function(T item) idOf,
  required T? Function(Map<String, dynamic> row) fromRow,
  /// When false, remove the item if present (row left the stream filter).
  bool Function(T item)? include,
}) {
  switch (payload.eventType) {
    case PostgresChangeEvent.insert:
    case PostgresChangeEvent.update:
      final raw = payload.newRecord;
      if (raw.isEmpty || raw['id'] == null) return null;
      final item = fromRow(Map<String, dynamic>.from(raw));
      if (item == null) return null;
      final id = idOf(item);

      if (include != null && !include(item)) {
        final next = current.where((e) => idOf(e) != id).toList();
        return next.length == current.length ? current : next;
      }

      final index = current.indexWhere((e) => idOf(e) == id);
      if (index < 0) return [item, ...current];
      final next = List<T>.from(current);
      next[index] = item;
      return next;

    case PostgresChangeEvent.delete:
      final id = payload.oldRecord['id']?.toString();
      if (id == null || id.isEmpty) return null;
      final next = current.where((e) => idOf(e) != id).toList();
      return next.length == current.length ? current : next;

    case PostgresChangeEvent.all:
      return null;
  }
}
