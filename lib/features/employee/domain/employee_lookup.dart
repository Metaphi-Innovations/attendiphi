import '../../checkin/domain/entities/check_in_submission.dart';
import 'entities/employee.dart';

/// Resolves live [Employee] records from the streamed employee list.
///
/// Check-in documents store denormalized name/phone snapshots. Admin edits
/// must still resolve through this lookup so dashboards, reports, and
/// check-in UI show the current profile.
class EmployeeLookup {
  EmployeeLookup._();

  static String normalizeName(String? value) =>
      (value ?? '').trim().toLowerCase();

  static String digits(String? phone) =>
      (phone ?? '').replaceAll(RegExp(r'\D'), '');

  static bool phonesMatch(String? a, String? b) {
    final left = digits(a);
    final right = digits(b);
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    return left.endsWith(right) || right.endsWith(left);
  }

  static Employee? byId(Iterable<Employee> employees, String? id) {
    final target = (id ?? '').trim();
    if (target.isEmpty) return null;
    for (final emp in employees) {
      if (emp.id == target) return emp;
    }
    return null;
  }

  static Employee? byPhone(Iterable<Employee> employees, String? phone) {
    if (digits(phone).isEmpty) return null;
    for (final emp in employees) {
      if (phonesMatch(emp.phone, phone)) return emp;
    }
    return null;
  }

  static Employee? byName(Iterable<Employee> employees, String? name) {
    final target = normalizeName(name);
    if (target.isEmpty) return null;
    for (final emp in employees) {
      if (normalizeName(emp.name) == target) return emp;
    }
    return null;
  }

  /// Resolves the registered member represented by a check-in row.
  ///
  /// For substitutes this is the member being covered (not the attending
  /// substitute). Prefer [CheckInSubmission.memberId] when present.
  static Employee? forCheckIn(
    Iterable<Employee> employees,
    CheckInSubmission record,
  ) {
    final byMemberId = byId(employees, record.memberId);
    if (byMemberId != null) return byMemberId;

    if (record.type.isSubstitute) {
      return forNamedMember(employees, record.substituteForMember);
    }

    if (record.type.isVisitor) return null;

    final byUserPhone = byPhone(employees, record.userPhone);
    if (byUserPhone != null) return byUserPhone;

    return byName(employees, record.userName);
  }

  static Employee? forNamedMember(
    Iterable<Employee> employees,
    String? name, {
    String? phone,
  }) {
    final fromPhone = byPhone(employees, phone);
    if (fromPhone != null) return fromPhone;
    return byName(employees, name);
  }

  /// Workspace-scoped member list used by check-in and admin screens.
  static List<Employee> scoped({
    required Iterable<Employee> employees,
    String? adminId,
    bool activeOnly = false,
    bool includeUnscoped = true,
  }) {
    final admin = adminId?.trim() ?? '';
    return employees.where((emp) {
      if (activeOnly && !emp.isActive) return false;
      if (admin.isEmpty) return true;
      final empAdmin = emp.adminId?.trim() ?? '';
      if (includeUnscoped && empAdmin.isEmpty) return true;
      return empAdmin == admin;
    }).toList();
  }

  static String liveDisplayName(
    Iterable<Employee> employees,
    String? storedName, {
    String? memberId,
    String? phone,
  }) {
    final live =
        byId(employees, memberId) ??
        byPhone(employees, phone) ??
        byName(employees, storedName);
    if (live != null && live.name.trim().isNotEmpty) return live.name;
    return (storedName ?? '').trim();
  }

  /// Identity for the Successful screen: the submitted [memberId] only.
  /// Never falls back to phone or name matching.
  static Employee? bySubmittedMemberId(
    Iterable<Employee> employees,
    CheckInSubmission? record, {
    String? memberId,
  }) {
    final id = (memberId ?? record?.memberId)?.trim() ?? '';
    if (id.isEmpty) return null;
    return byId(employees, id);
  }

  /// Returns the live member name for [memberId], or null when that document
  /// is not loaded yet. Does not return [submission.userName] when a memberId
  /// is present, so a stale denormalized snapshot cannot replace the member.
  static String? successDisplayName({
    CheckInSubmission? submission,
    Iterable<Employee> employees = const [],
    String? memberId,
    Employee? authoritativeMember,
  }) {
    final fromDoc = authoritativeMember?.name.trim() ?? '';
    if (fromDoc.isNotEmpty) return fromDoc;

    final id = (memberId ?? submission?.memberId)?.trim() ?? '';
    if (id.isNotEmpty) {
      final live = byId(employees, id);
      final name = live?.name.trim() ?? '';
      if (name.isNotEmpty) return name;
      final snapshot = submission?.userName.trim() ?? '';
      if (snapshot.isNotEmpty) return snapshot;
      return null;
    }

    return submission?.userName.trim();
  }

  static String? successDisplayPhone({
    CheckInSubmission? submission,
    Iterable<Employee> employees = const [],
    String? memberId,
    Employee? authoritativeMember,
  }) {
    final fromDoc = authoritativeMember?.phone.trim() ?? '';
    if (fromDoc.isNotEmpty) return fromDoc;

    final id = (memberId ?? submission?.memberId)?.trim() ?? '';
    if (id.isNotEmpty) {
      final live = byId(employees, id);
      final phone = live?.phone.trim() ?? '';
      if (phone.isNotEmpty) return phone;
      final snapshot = submission?.userPhone.trim() ?? '';
      if (snapshot.isNotEmpty) return snapshot;
      return null;
    }

    return submission?.userPhone.trim();
  }
}
