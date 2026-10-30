import 'package:flutter_test/flutter_test.dart';
import 'package:qr_checkin/features/checkin/domain/entities/check_in_type.dart';
import 'package:qr_checkin/features/checkin/domain/session_lock_ids.dart';

void main() {
  group('SessionLockIds', () {
    test('normalizes phone digits and builds typed phone lock id', () {
      expect(SessionLockIds.phoneDigits('+91 98765-43210'), '9876543210');
      expect(
        SessionLockIds.phoneLockId('+919876543210', '2026-10-08'),
        '9876543210_2026-10-08_member',
      );
      expect(
        SessionLockIds.phoneLockId(
          '+919876543210',
          '2026-10-08',
          type: CheckInType.substitute,
        ),
        '9876543210_2026-10-08_substitute',
      );
    });

    test('builds member and device lock ids', () {
      expect(
        SessionLockIds.memberLockId('emp_1', '2026-10-08'),
        'emp_1_2026-10-08',
      );
      expect(
        SessionLockIds.deviceLockId('dev-abc', '2026-10-08'),
        'dev-abc_2026-10-08',
      );
    });

    test('prefers QR sessionDateStr over timestamp for ymd', () {
      expect(
        SessionLockIds.sessionDateYmd(
          sessionDateStr: '2026-10-08T10:00:00',
          fallbackTimestamp: DateTime(2026, 10, 7, 14, 0),
        ),
        '2026-10-08',
      );
      expect(
        SessionLockIds.sessionDateYmd(
          sessionDateStr: null,
          fallbackTimestamp: DateTime(2026, 9, 3, 10, 0),
        ),
        '2026-09-03',
      );
    });
  });
}
