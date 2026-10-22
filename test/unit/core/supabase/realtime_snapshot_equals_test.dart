import 'package:qr_checkin/core/supabase/realtime_snapshot_equals.dart';
import 'package:qr_checkin/core/supabase/supabase_realtime_or_poll_stream.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/employee/domain/entities/employee.dart';
import 'package:flutter_test/flutter_test.dart';

Employee _member({
  required String id,
  String name = 'Ada',
  String phone = '9000000001',
  bool isActive = true,
  String? photoUrl,
  DateTime? updatedAt,
  bool faceEnrolled = false,
  int templateCount = 0,
}) {
  return Employee(
    id: id,
    name: name,
    phone: phone,
    isActive: isActive,
    photoUrl: photoUrl,
    updatedAt: updatedAt,
    faceEnrolled: faceEnrolled,
    faceTemplates: templateCount == 0
        ? null
        : List.generate(templateCount, (_) => List.filled(128, 0.1)),
  );
}

CheckInSubmission _checkIn({
  required String id,
  String memberId = 'm1',
  String userName = 'Ada',
  CheckInType type = CheckInType.member,
  DateTime? timestamp,
  bool isVerified = false,
  bool isFlagged = false,
}) {
  final ts = timestamp ?? DateTime.utc(2026, 10, 21, 5);
  return CheckInSubmission(
    id: id,
    locationId: 'loc_1',
    locationName: 'Hall',
    userName: userName,
    userPhone: '9000000001',
    type: type,
    userLatitude: 19.0,
    userLongitude: 72.0,
    gpsAccuracy: 10,
    distanceMeters: 5,
    timestamp: ts,
    memberId: memberId,
    isVerified: isVerified,
    isFlagged: isFlagged,
  );
}

void main() {
  group('shouldEmitRealtimeSnapshot', () {
    test('emits when previous is null', () {
      expect(
        shouldEmitRealtimeSnapshot<int>(
          previous: null,
          next: 1,
          isUnchanged: (a, b) => a == b,
        ),
        isTrue,
      );
    });

    test('emits when isUnchanged is null', () {
      expect(
        shouldEmitRealtimeSnapshot<int>(previous: 1, next: 1),
        isTrue,
      );
    });

    test('skips emit when unchanged', () {
      expect(
        shouldEmitRealtimeSnapshot<int>(
          previous: 1,
          next: 1,
          isUnchanged: (a, b) => a == b,
        ),
        isFalse,
      );
    });

    test('emits when changed', () {
      expect(
        shouldEmitRealtimeSnapshot<int>(
          previous: 1,
          next: 2,
          isUnchanged: (a, b) => a == b,
        ),
        isTrue,
      );
    });
  });

  group('employeesSnapshotUnchanged', () {
    test('true for identical roster fingerprints', () {
      final updated = DateTime.utc(2026, 10, 1);
      final a = [
        _member(id: '1', photoUrl: 'data:x', updatedAt: updated),
        _member(id: '2', name: 'Bob', phone: '9000000002', updatedAt: updated),
      ];
      final b = [
        _member(id: '2', name: 'Bob', phone: '9000000002', updatedAt: updated),
        _member(id: '1', photoUrl: 'data:x', updatedAt: updated),
      ];
      expect(employeesSnapshotUnchanged(a, b), isTrue);
    });

    test('false when photo or name changes', () {
      final updated = DateTime.utc(2026, 10, 1);
      final a = [_member(id: '1', photoUrl: 'old', updatedAt: updated)];
      final b = [_member(id: '1', photoUrl: 'new', updatedAt: updated)];
      expect(employeesSnapshotUnchanged(a, b), isFalse);

      final c = [_member(id: '1', name: 'Ada', updatedAt: updated)];
      final d = [_member(id: '1', name: 'Ada Lovelace', updatedAt: updated)];
      expect(employeesSnapshotUnchanged(c, d), isFalse);
    });

    test('false when length differs', () {
      expect(
        employeesSnapshotUnchanged([_member(id: '1')], [
          _member(id: '1'),
          _member(id: '2'),
        ]),
        isFalse,
      );
    });
  });

  group('faceCandidatesSnapshotUnchanged', () {
    test('false when template count changes', () {
      final a = [_member(id: '1', faceEnrolled: true, templateCount: 3)];
      final b = [_member(id: '1', faceEnrolled: true, templateCount: 4)];
      expect(faceCandidatesSnapshotUnchanged(a, b), isFalse);
    });
  });

  group('checkInsSnapshotUnchanged', () {
    test('true for same id-keyed UI fields', () {
      final ts = DateTime.utc(2026, 10, 21, 5);
      final a = [_checkIn(id: 'c1', timestamp: ts)];
      final b = [_checkIn(id: 'c1', timestamp: ts)];
      expect(checkInsSnapshotUnchanged(a, b), isTrue);
    });

    test('false when verified or type changes', () {
      final ts = DateTime.utc(2026, 10, 21, 5);
      final a = [_checkIn(id: 'c1', timestamp: ts)];
      final b = [_checkIn(id: 'c1', timestamp: ts, isVerified: true)];
      expect(checkInsSnapshotUnchanged(a, b), isFalse);

      final c = [_checkIn(id: 'c1', timestamp: ts)];
      final d = [
        _checkIn(id: 'c1', timestamp: ts, type: CheckInType.substitute),
      ];
      expect(checkInsSnapshotUnchanged(c, d), isFalse);
    });
  });

  group('stringSetSnapshotUnchanged', () {
    test('order-independent set equality', () {
      expect(
        stringSetSnapshotUnchanged({'a', 'b'}, {'b', 'a'}),
        isTrue,
      );
      expect(
        stringSetSnapshotUnchanged({'a'}, {'a', 'b'}),
        isFalse,
      );
    });
  });
}
