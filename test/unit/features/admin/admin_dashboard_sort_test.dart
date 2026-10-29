import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/admin/presentation/providers/admin_dashboard_provider.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_submission.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';

CheckInSubmission _record({
  required String id,
  required String name,
  required CheckInType type,
  required DateTime timestamp,
}) {
  return CheckInSubmission(
    id: id,
    locationId: 'loc',
    locationName: 'Venue',
    userName: name,
    userPhone: '9876543210',
    type: type,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 0,
    distanceMeters: 0,
    timestamp: timestamp,
  );
}

void main() {
  final records = [
    _record(
      id: '1',
      name: 'Zara Khan',
      type: CheckInType.member,
      timestamp: DateTime(2026, 10, 9, 10),
    ),
    _record(
      id: '2',
      name: 'amit shah',
      type: CheckInType.notCheckedIn,
      timestamp: DateTime(2026, 10, 9, 9),
    ),
    _record(
      id: '3',
      name: 'Meera Joshi',
      type: CheckInType.member,
      timestamp: DateTime(2026, 10, 9, 11),
    ),
  ];

  test('default filter sort is Name A–Z', () {
    expect(
      const AdminDashboardFilterState().sortMode,
      AdminDashboardSortMode.alphabetical,
    );
  });

  test('alphabetical sort orders by name case-insensitively', () {
    final sorted = filterAndSortDashboardRecords(
      records: records,
      filters: const AdminDashboardFilterState(
        sortMode: AdminDashboardSortMode.alphabetical,
      ),
    );

    expect(sorted.map((r) => r.userName).toList(), [
      'amit shah',
      'Meera Joshi',
      'Zara Khan',
    ]);
  });

  test('recent sort keeps checked-in before absent, then newest first', () {
    final sorted = filterAndSortDashboardRecords(
      records: records,
      filters: const AdminDashboardFilterState(
        sortMode: AdminDashboardSortMode.recent,
      ),
    );

    expect(sorted.map((r) => r.userName).toList(), [
      'Meera Joshi',
      'Zara Khan',
      'amit shah',
    ]);
  });

  group('mergeCheckInOverrides', () {
    test('injects optimistic verify before stream catches up', () {
      final stamped = DateTime(2026, 10, 9, 16, 30);
      final optimistic = _record(
        id: 'new-uuid',
        name: 'amit shah',
        type: CheckInType.member,
        timestamp: stamped,
      ).copyWith(memberId: 'emp_amit', isVerified: true);

      final merged = mergeCheckInOverrides(
        streamRows: const [],
        overrides: {optimistic.id: optimistic},
      );

      expect(merged, hasLength(1));
      expect(merged.single.id, 'new-uuid');
      expect(merged.single.isVerified, isTrue);
      expect(merged.single.timestamp, stamped);
    });

    test('patches existing stream row isVerified without dropping others', () {
      final existing = _record(
        id: '1',
        name: 'Zara Khan',
        type: CheckInType.member,
        timestamp: DateTime(2026, 10, 9, 10),
      ).copyWith(memberId: 'emp_zara', isVerified: false);
      final other = _record(
        id: '3',
        name: 'Meera Joshi',
        type: CheckInType.member,
        timestamp: DateTime(2026, 10, 9, 11),
      ).copyWith(memberId: 'emp_meera');
      final patched = existing.copyWith(isVerified: true);

      final merged = mergeCheckInOverrides(
        streamRows: [existing, other],
        overrides: {patched.id: patched},
      );

      expect(merged, hasLength(2));
      expect(
        merged.firstWhere((r) => r.id == '1').isVerified,
        isTrue,
      );
      expect(merged.any((r) => r.id == '3'), isTrue);
    });
  });
}
