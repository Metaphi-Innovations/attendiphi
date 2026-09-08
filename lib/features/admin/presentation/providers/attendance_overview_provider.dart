import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import 'admin_dashboard_provider.dart';

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
      selectedMonth:
          selectedMonth != null ? selectedMonth() : this.selectedMonth,
    );
  }
}

/// Notifier to control filtering in Attendance Overview.
class AttendanceOverviewFilterNotifier
    extends Notifier<AttendanceOverviewFilterState> {
  @override
  AttendanceOverviewFilterState build() {
    return const AttendanceOverviewFilterState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void setSelectedMonth(DateTime? month) {
    state = state.copyWith(selectedMonth: () => month);
  }

  void resetFilters() {
    state = const AttendanceOverviewFilterState();
  }
}

final attendanceOverviewFilterProvider = NotifierProvider<
    AttendanceOverviewFilterNotifier, AttendanceOverviewFilterState>(
  AttendanceOverviewFilterNotifier.new,
);

/// Generates all Thursday dates from September 2026 to September 2027 inclusive.
final allThursdayDatesProvider = Provider<List<DateTime>>((ref) {
  final thursdays = <DateTime>[];
  DateTime current = DateTime(2026, 9, 1);
  final end = DateTime(2027, 9, 30);

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

/// Computed attendance matrix rows for all members based on real-time check-ins.
final attendanceMatrixProvider =
    Provider<AsyncValue<List<MemberAttendanceRow>>>((ref) {
  final employeesAsync = ref.watch(employeesStreamProvider);
  final checkInsAsync = ref.watch(checkInsStreamProvider);
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

  // Helper to format date keys
  String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  // Filter members matching search query
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
    int presentCount = 0;
    int substituteCount = 0;
    int absentCount = 0;

    for (final thursday in allThursdays) {
      final key = dateKey(thursday);
      final isFutureDate = thursday.isAfter(now);

      // Find matching check-in for this member on this Thursday
      final matchingSubmissions = checkIns.where((sub) {
        final subDate = sub.timestamp;
        final isSameDay = subDate.year == thursday.year &&
            subDate.month == thursday.month &&
            subDate.day == thursday.day;
        if (!isSameDay) return false;

        // Check if directly checked in as member or absent
        final isDirectMember =
            sub.userName.trim().toLowerCase() == member.name.trim().toLowerCase();

        // Check if substitute checked in for this member
        final isSubstituteForMember = sub.type == CheckInType.substitute &&
            sub.substituteForMember != null &&
            sub.substituteForMember!.trim().toLowerCase() ==
                member.name.trim().toLowerCase();

        return isDirectMember || isSubstituteForMember;
      }).toList();

      if (matchingSubmissions.isNotEmpty) {
        // Sort by timestamp descending (latest check-in takes precedence)
        matchingSubmissions.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final latest = matchingSubmissions.first;

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
          // Member / Visitor (Present)
          attendanceMap[key] = MemberDayAttendance(
            date: thursday,
            status: MemberAttendanceStatus.present,
            submission: latest,
            isEdited: latest.isEdited,
          );
          presentCount++;
        }
      } else {
        if (isFutureDate) {
          attendanceMap[key] = MemberDayAttendance(
            date: thursday,
            status: MemberAttendanceStatus.upcoming,
          );
        } else {
          // Past meeting date with no check-in is Absent
          attendanceMap[key] = MemberDayAttendance(
            date: thursday,
            status: MemberAttendanceStatus.absent,
          );
          absentCount++;
        }
      }
    }

    final totalCompletedMeetings = presentCount + substituteCount + absentCount;
    final double attendanceRate = totalCompletedMeetings > 0
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
