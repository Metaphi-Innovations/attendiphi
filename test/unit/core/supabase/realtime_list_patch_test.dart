import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/core/supabase/realtime_list_patch.dart';
import 'package:realtime_client/realtime_client.dart';

void main() {
  PostgresChangePayload payload({
    required PostgresChangeEvent eventType,
    Map<String, dynamic> newRecord = const {},
    Map<String, dynamic> oldRecord = const {},
  }) {
    return PostgresChangePayload(
      schema: 'public',
      table: 'check_ins',
      commitTimestamp: DateTime(2026, 10, 19),
      eventType: eventType,
      newRecord: newRecord,
      oldRecord: oldRecord,
      errors: null,
    );
  }

  test('insert prepends without REST', () {
    final next = patchRealtimeListById<Map<String, dynamic>>(
      current: [
        {'id': 'a', 'name': 'A'},
      ],
      payload: payload(
        eventType: PostgresChangeEvent.insert,
        newRecord: {'id': 'b', 'name': 'B'},
      ),
      idOf: (m) => m['id'] as String,
      fromRow: (row) => row,
    );

    expect(next!.map((e) => e['id']), ['b', 'a']);
  });

  test('update replaces matching id', () {
    final next = patchRealtimeListById<Map<String, dynamic>>(
      current: [
        {'id': 'a', 'name': 'Old'},
      ],
      payload: payload(
        eventType: PostgresChangeEvent.update,
        newRecord: {'id': 'a', 'name': 'New'},
      ),
      idOf: (m) => m['id'] as String,
      fromRow: (row) => row,
    );

    expect(next!.single['name'], 'New');
  });

  test('delete removes by id', () {
    final next = patchRealtimeListById<Map<String, dynamic>>(
      current: [
        {'id': 'a'},
        {'id': 'b'},
      ],
      payload: payload(
        eventType: PostgresChangeEvent.delete,
        oldRecord: {'id': 'a'},
      ),
      idOf: (m) => m['id'] as String,
      fromRow: (row) => row,
    );

    expect(next!.map((e) => e['id']), ['b']);
  });

  test('incomplete payload returns null for fetch fallback', () {
    final next = patchRealtimeListById<Map<String, dynamic>>(
      current: const [],
      payload: payload(eventType: PostgresChangeEvent.insert),
      idOf: (m) => m['id'] as String,
      fromRow: (row) => row,
    );
    expect(next, isNull);
  });
}
