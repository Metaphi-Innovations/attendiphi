import '../../../core/utils/validators.dart';
import 'entities/check_in_type.dart';

/// Helpers for public create-once session lock document IDs.
class SessionLockIds {
  SessionLockIds._();

  /// Normalizes to 10-digit Indian mobile digits for lock document IDs.
  static String phoneDigits(String phone) {
    final normalized = Validators.normalizePhone(phone);
    if (normalized.length >= 10) {
      return normalized.substring(normalized.length - 10);
    }
    return normalized;
  }

  /// Phone lock bucket: member | substitute | visitor (matches RPC).
  static String phoneLockType(CheckInType type) {
    if (type.isSubstitute) return 'substitute';
    if (type.isVisitor) return 'visitor';
    return 'member';
  }

  /// `{phone}_{yyyy-MM-dd}_{member|substitute|visitor}`.
  static String phoneLockId(
    String phone,
    String sessionDateYmd, {
    CheckInType type = CheckInType.member,
  }) {
    return '${phoneDigits(phone)}_${sessionDateYmd}_${phoneLockType(type)}';
  }

  static String memberLockId(String memberId, String sessionDateYmd) {
    return '${memberId.trim()}_$sessionDateYmd';
  }

  static String deviceLockId(String deviceId, String sessionDateYmd) {
    return '${deviceId.trim()}_$sessionDateYmd';
  }

  /// yyyy-MM-dd from QR session string or submission timestamp.
  static String sessionDateYmd({
    String? sessionDateStr,
    required DateTime fallbackTimestamp,
  }) {
    final fromQr = sessionDateStr?.trim() ?? '';
    if (fromQr.length >= 10) return fromQr.substring(0, 10);
    final t = fallbackTimestamp;
    final m = t.month.toString().padLeft(2, '0');
    final d = t.day.toString().padLeft(2, '0');
    return '${t.year}-$m-$d';
  }
}
