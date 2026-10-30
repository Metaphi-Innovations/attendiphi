import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/domain/employee_lookup.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import 'admin_auth_provider.dart';

/// Represents the attendance status of a member on a specific Thursday meeting.
enum MemberAttendanceStatus {
  present('Present', 'P'),
  substitute('Substitute', 'S'),
  absent('Absent', 'A'),
  upcoming('Upcoming', '-');

  const MemberAttendanceStatus(this.label, this.code);
  final String label;
  final String code;

  bool get isPresent => this == MemberAttendanceStatus.present;
  bool get isSubstitute => this == MemberAttendanceStatus.substitute;
  bool get isAbsent => this == MemberAttendanceStatus.absent;
  bool get isUpcoming => this == MemberAttendanceStatus.upcoming;
}

/// Detailed information for a single member's attendance on a given day.
class MemberDayAttendance {
  const MemberDayAttendance({
    required this.date,
    required this.status,
    this.submission,
    this.substituteName,
    this.isEdited = false,
  });

  final DateTime date;
  final MemberAttendanceStatus status;
  final CheckInSubmission? submission;
  final String? substituteName;
  final bool isEdited;
}

/// Aggregated row data for a single member across all Thursday dates.
class MemberAttendanceRow {
  const MemberAttendanceRow({
    required this.member,
    required this.attendanceMap,
    required this.presentCount,
    required this.substituteCount,
    required this.absentCount,
    required this.attendanceRate,
  });

  final Employee member;
  final Map<String, MemberDayAttendance> attendanceMap;
  final int presentCount;
  final int substituteCount;
  final int absentCount;
  final double attendanceRate;

  String _dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  MemberDayAttendance getAttendanceForDate(DateTime date) {
    return attendanceMap[_dateKey(date)] ??
        MemberDayAttendance(
          date: date,
          status: date.isAfter(DateTime.now())
              ? MemberAttendanceStatus.upcoming
              : MemberAttendanceStatus.absent,
        );
  }
}

/// Filter state for the Attendance Overview screen.
class AttendanceOverviewFilterState {
  const AttendanceOverviewFilterState({
    this.searchQuery = '',
    this.selectedMonth,
  });

  final String searchQuery;
  final DateTime? selectedMonth;

  AttendanceOverviewFilterState copyWith({
    String? searchQuery,
    DateTime? Function()? selectedMonth,
  }) {
    return AttendanceOverviewFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMonth: selectedMonth != null
          ? selectedMonth()
          : this.selectedMonth,
    );
  }
}

/// Default month for the overview matrix (clamped to Sep 2026 – Sep 2027).
///
/// Opening on "All Months" builds ~140×57 cells and feels laggy on web; start
/// on the current month (~4–5 date columns) instead.
DateTime attendanceOverviewDefaultMonth([DateTime? now]) {
  final n = now ?? DateTime.now();
  final candidate = DateTime(n.year, n.month, 1);
  final start = DateTime(2026, 9, 1);
  final end = DateTime(2027, 9, 1);
  if (candidate.isBefore(start)) return start;
  if (candidate.isAfter(end)) return end;
  return candidate;
}

/// Notifier to control filtering in Attendance Overview.
class AttendanceOverviewFilterNotifier
    extends Notifier<AttendanceOverviewFilterState> {
  @override
  AttendanceOverviewFilterState build() {
    return AttendanceOverviewFilterState(
      selectedMonth: attendanceOverviewDefaultMonth(),
    );
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void setSelectedMonth(DateTime? month) {
    state = state.copyWith(selectedMonth: () => month);
  }

  void resetFilters() {
    state = AttendanceOverviewFilterState(
      selectedMonth: attendanceOverviewDefaultMonth(),
    );
  }
}

final attendanceOverviewFilterProvider =
    NotifierProvider<
      AttendanceOverviewFilterNotifier,
      AttendanceOverviewFilterState
    >(AttendanceOverviewFilterNotifier.new);

/// Session dates for admin pickers / overview matrix.
///
/// Date restriction ON → Thursdays only (Sep 2026 – Sep 2027).
/// Date restriction OFF → every calendar day in that range.
final allThursdayDatesProvider = Provider<List<DateTime>>((ref) {
  final dateRestrictionEnabled = ref.watch(dateRestrictionEnabledProvider);
  final end = DateTime(2027, 9, 30);

  if (!dateRestrictionEnabled) {
    final days = <DateTime>[];
    var current = DateTime(2026, 9, 1);
    while (!current.isAfter(end)) {
      days.add(DateTime(current.year, current.month, current.day));
      current = current.add(const Duration(days: 1));
    }
    return days;
  }

  final thursdays = <DateTime>[];
  DateTime current = DateTime(2026, 9, 1);

  // Advance to first Thursday
  while (current.weekday != DateTime.thursday) {
    current = current.add(const Duration(days: 1));
  }

  while (!current.isAfter(end)) {
    thursdays.add(DateTime(current.year, current.month, current.day));
    current = current.add(const Duration(days: 7));
  }

  return thursdays;
});

/// Generates list of all unique months (Sep 2026 to Sep 2027) for month filtering.
final meetingMonthsProvider = Provider<List<DateTime>>((ref) {
  final months = <DateTime>[];
  DateTime current = DateTime(2026, 9, 1);
  final end = DateTime(2027, 9, 1);

  while (!current.isAfter(end)) {
    months.add(DateTime(current.year, current.month, 1));
    current = DateTime(
      current.month == 12 ? current.year + 1 : current.year,
      current.month == 12 ? 1 : current.month + 1,
      1,
    );
  }
  return months;
});

String _overviewYmd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Month-scoped check-ins for Attendance Overview (avoids full-history dumps).
///
/// When [AttendanceOverviewFilterState.selectedMonth] is null (All Months),
/// fetch the full Sep 2026 – Sep 2027 window so every visible column has data.
final overviewCheckInsStreamProvider = StreamProvider<List<CheckInSubmission>>((
  ref,
) {
  final auth = ref.watch(adminAuthProvider);
  if (!auth.sessionResolved) {
    return pendingStreamController<List<CheckInSubmission>>(
      onDispose: ref.onDispose,
    ).stream;
  }
  if (!auth.isAuthenticated) {
    return Stream.value(const <CheckInSubmission>[]);
  }
  final filters = ref.watch(attendanceOverviewFilterProvider);
  final DateTime from;
  final DateTime to;
  final month = filters.selectedMonth;
  if (month == null) {
    from = DateTime(2026, 9, 1);
    to = DateTime(2027, 9, 30);
  } else {
    from = DateTime(month.year, month.month, 1);
    to = DateTime(month.year, month.month + 1, 0);
  }
  final repository = ref.watch(checkInRepositoryProvider);
  return repository.streamCheckIns(
    sessionDateFrom: _overviewYmd(from),
    sessionDateTo: _overviewYmd(to),
  );
});

/// Computed attendance matrix rows for all members based on real-time check-ins.
final attendanceMatrixProvider = Provider<AsyncValue<List<MemberAttendanceRow>>>((
  ref,
) {
  final employeesAsync = ref.watch(employeesStreamProvider);
  final checkInsAsync = ref.watch(overviewCheckInsStreamProvider);
  final allThursdays = ref.watch(allThursdayDatesProvider);
  final filters = ref.watch(attendanceOverviewFilterProvider);

  if (employeesAsync.isLoading || checkInsAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (employeesAsync.hasError) {
    return AsyncValue.error(
      employeesAsync.error!,
      employeesAsync.stackTrace ?? StackTrace.current,
    );
  }

  if (checkInsAsync.hasError) {
    return AsyncValue.error(
      checkInsAsync.error!,
      checkInsAsync.stackTrace ?? StackTrace.current,
    );
  }

  final employees = employeesAsync.value ?? [];
  final checkIns = checkInsAsync.value ?? [];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // Only build cells for the filtered month (All Months → full range).
  final relevantThursdays = filters.selectedMonth == null
      ? allThursdays
      : allThursdays
            .where(
              (d) =>
                  d.year == filters.selectedMonth!.year &&
                  d.month == filters.selectedMonth!.month,
            )
            .toList(growable: false);

  // Per-day indexes for O(1) member resolution (avoids O(members × days ×
  // check-ins) EmployeeLookup scans on every rebuild).
  final byDate = <String, _OverviewDayIndex>{};
  for (final sub in checkIns) {
    if (sub.type.isVisitor) continue;
    final key = dateKey(sub.timestamp);
    final day = byDate.putIfAbsent(key, _OverviewDayIndex.new);
    day.add(sub);
  }

  final filteredEmployees = employees.where((emp) {
    if (filters.searchQuery.isEmpty) return true;
    final query = filters.searchQuery.toLowerCase();
    return emp.name.toLowerCase().contains(query) ||
        emp.phone.toLowerCase().contains(query) ||
        emp.role.toLowerCase().contains(query);
  }).toList();

  final rows = <MemberAttendanceRow>[];

  for (final member in filteredEmployees) {
    final attendanceMap = <String, MemberDayAttendance>{};
    var presentCount = 0;
    var substituteCount = 0;
    var absentCount = 0;
    final memberPhoneDigits = EmployeeLookup.digits(member.phone);
    final memberNameKey = EmployeeLookup.normalizeName(member.name);

    for (final thursday in relevantThursdays) {
      final key = dateKey(thursday);
      final isTodayOrFuture = !thursday.isBefore(today);
      final latest = byDate[key]?.resolve(
        memberId: member.id,
        phoneDigits: memberPhoneDigits,
        nameKey: memberNameKey,
        memberPhone: member.phone,
        memberName: member.name,
      );

      if (latest != null) {
        if (latest.type == CheckInType.absent) {
          attendanceMap[key] = MemberDayAttendance(
            date: thursday,
            status: MemberAttendanceStatus.absent,
            submission: latest,
            isEdited: latest.isEdited,
          );
          absentCount++;
        } else if (latest.type == CheckInType.substitute) {
          attendanceMap[key] = MemberDayAttendance(
            date: thursday,
            status: MemberAttendanceStatus.substitute,
            submission: latest,
            substituteName: latest.userName,
            isEdited: latest.isEdited,
          );
          substituteCount++;
        } else {
          attendanceMap[key] = MemberDayAttendance(
            date: thursday,
            status: MemberAttendanceStatus.present,
            submission: latest,
            isEdited: latest.isEdited,
          );
          presentCount++;
        }
      } else if (isTodayOrFuture) {
        // Today / future: open session (aligns with Daily "Not Checked In").
        attendanceMap[key] = MemberDayAttendance(
          date: thursday,
          status: MemberAttendanceStatus.upcoming,
        );
      } else {
        attendanceMap[key] = MemberDayAttendance(
          date: thursday,
          status: MemberAttendanceStatus.absent,
        );
        absentCount++;
      }
    }

    final totalCompletedMeetings = presentCount + substituteCount + absentCount;
    final attendanceRate = totalCompletedMeetings > 0
        ? ((presentCount + substituteCount) / totalCompletedMeetings) * 100
        : 0.0;

    rows.add(
      MemberAttendanceRow(
        member: member,
        attendanceMap: attendanceMap,
        presentCount: presentCount,
        substituteCount: substituteCount,
        absentCount: absentCount,
        attendanceRate: attendanceRate,
      ),
    );
  }

  return AsyncValue.data(rows);
});

/// Per-session-day check-in index for the overview matrix.
class _OverviewDayIndex {
  final Map<String, CheckInSubmission> memberById = {};
  final Map<String, CheckInSubmission> memberByPhone = {};
  final Map<String, CheckInSubmission> memberByName = {};
  final Map<String, CheckInSubmission> substituteByCoveredId = {};
  final Map<String, CheckInSubmission> substituteByCoveredName = {};
  final List<CheckInSubmission> substituteLegacy = [];

  static void _putLatest(
    Map<String, CheckInSubmission> map,
    String key,
    CheckInSubmission sub,
  ) {
    final existing = map[key];
    if (existing == null || sub.timestamp.isAfter(existing.timestamp)) {
      map[key] = sub;
    }
  }

  static void _putPhoneKeys(
    Map<String, CheckInSubmission> map,
    String? phone,
    CheckInSubmission sub,
  ) {
    final digits = EmployeeLookup.digits(phone);
    if (digits.isEmpty) return;
    _putLatest(map, digits, sub);
    if (digits.length > 10) {
      _putLatest(map, digits.substring(digits.length - 10), sub);
    }
  }

  void add(CheckInSubmission sub) {
    if (sub.type.isSubstitute) {
      final coveredId = (sub.memberId ?? '').trim();
      if (coveredId.isNotEmpty) {
        _putLatest(substituteByCoveredId, coveredId, sub);
        return;
      }
      final coveredName = EmployeeLookup.normalizeName(sub.substituteForMember);
      if (coveredName.isNotEmpty) {
        _putLatest(substituteByCoveredName, coveredName, sub);
        return;
      }
      // Admin-converted / legacy: no covered id/name — match by phone/name later.
      substituteLegacy.add(sub);
      return;
    }

    final memberId = (sub.memberId ?? '').trim();
    if (memberId.isNotEmpty) {
      _putLatest(memberById, memberId, sub);
      return;
    }
    _putPhoneKeys(memberByPhone, sub.userPhone, sub);
    final nameKey = EmployeeLookup.normalizeName(sub.userName);
    if (nameKey.isNotEmpty) {
      _putLatest(memberByName, nameKey, sub);
    }
  }

  CheckInSubmission? resolve({
    required String memberId,
    required String phoneDigits,
    required String nameKey,
    required String memberPhone,
    required String memberName,
  }) {
    CheckInSubmission? best;

    void consider(CheckInSubmission? candidate) {
      if (candidate == null) return;
      if (best == null || candidate.timestamp.isAfter(best!.timestamp)) {
        best = candidate;
      }
    }

    consider(substituteByCoveredId[memberId]);
    if (nameKey.isNotEmpty) {
      consider(substituteByCoveredName[nameKey]);
    }
    for (final legacy in substituteLegacy) {
      if (EmployeeLookup.phonesMatch(legacy.userPhone, memberPhone) ||
          EmployeeLookup.normalizeName(legacy.userName) == nameKey) {
        consider(legacy);
      }
    }

    consider(memberById[memberId]);
    if (phoneDigits.isNotEmpty) {
      consider(memberByPhone[phoneDigits]);
      if (phoneDigits.length > 10) {
        consider(memberByPhone[phoneDigits.substring(phoneDigits.length - 10)]);
      }
    }
    if (nameKey.isNotEmpty) {
      consider(memberByName[nameKey]);
    }

    return best;
  }
}

/// Overall Summary Statistics Provider for the Attendance Overview screen.
class AttendanceOverviewStats {
  const AttendanceOverviewStats({
    required this.totalMembers,
    required this.totalCheckIns,
    required this.totalPresents,
    required this.totalSubstitutes,
    required this.totalAbsences,
    required this.overallAttendanceRate,
  });

  final int totalMembers;
  final int totalCheckIns;
  final int totalPresents;
  final int totalSubstitutes;
  final int totalAbsences;
  final double overallAttendanceRate;
}

final attendanceOverviewStatsProvider =
    Provider<AsyncValue<AttendanceOverviewStats>>((ref) {
      final matrixAsync = ref.watch(attendanceMatrixProvider);

      return matrixAsync.whenData((rows) {
        int totalPresents = 0;
        int totalSubstitutes = 0;
        int totalAbsences = 0;

        for (final row in rows) {
          totalPresents += row.presentCount;
          totalSubstitutes += row.substituteCount;
          totalAbsences += row.absentCount;
        }

        final totalAttended = totalPresents + totalSubstitutes;
        final totalMeetingsRecorded = totalAttended + totalAbsences;
        final rate = totalMeetingsRecorded > 0
            ? (totalAttended / totalMeetingsRecorded) * 100
            : 0.0;

        return AttendanceOverviewStats(
          totalMembers: rows.length,
          totalCheckIns: totalAttended,
          totalPresents: totalPresents,
          totalSubstitutes: totalSubstitutes,
          totalAbsences: totalAbsences,
          overallAttendanceRate: rate,
        );
      });
    });
