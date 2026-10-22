import '../../employee/domain/employee_lookup.dart';
import '../../employee/domain/entities/employee.dart';

/// Result of filtering the QR member typeahead against session attendance.
class SessionMemberTypeaheadResult {
  const SessionMemberTypeaheadResult({
    required this.scopedEmployees,
    required this.availableEmployees,
    required this.filteredEmployees,
    required this.emptyMessage,
  });

  final List<Employee> scopedEmployees;
  final List<Employee> availableEmployees;
  final List<Employee> filteredEmployees;

  /// Non-null when [filteredEmployees] is empty.
  final String? emptyMessage;
}

/// Builds the QR name list: active (+ optional admin) members not yet in
/// [checkedInMemberIds].
///
/// Empty-state rules (avoid the false "everyone checked in" banner):
/// - no roster loaded → ask to retry
/// - roster exists but every id is checked in → all checked in
/// - query matches nothing → no matching members
SessionMemberTypeaheadResult buildSessionMemberTypeahead({
  required List<Employee> allEmployees,
  required Set<String> checkedInMemberIds,
  String? adminId,
  String query = '',
  bool excludeCheckedIn = true,
  String? sessionDateYmd,
}) {
  final scoped = EmployeeLookup.scoped(
    employees: allEmployees,
    adminId: adminId,
    activeOnly: true,
  );
  final checked = excludeCheckedIn ? checkedInMemberIds : const <String>{};
  final available = scoped
      .where((emp) => !checked.contains(emp.id))
      .toList(growable: false);

  final q = query.trim().toLowerCase();
  final filtered = q.isEmpty
      ? available
      : available
            .where((emp) {
              final name = emp.name.toLowerCase();
              final phone = emp.phone.toLowerCase();
              return name.contains(q) || phone.contains(q);
            })
            .toList(growable: false);

  final day = (sessionDateYmd ?? '').trim();
  final daySuffix = day.length == 10 ? ' ($day)' : '';

  String? emptyMessage;
  if (filtered.isEmpty) {
    if (scoped.isEmpty) {
      emptyMessage =
          'No members available. Pull to refresh or rescan the QR$daySuffix.';
    } else if (excludeCheckedIn && available.isEmpty) {
      emptyMessage =
          'All members have already checked in for this session$daySuffix';
    } else {
      emptyMessage = 'No matching members found';
    }
  }

  return SessionMemberTypeaheadResult(
    scopedEmployees: scoped,
    availableEmployees: available,
    filteredEmployees: filtered,
    emptyMessage: emptyMessage,
  );
}
