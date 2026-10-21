import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../../checkin/domain/repositories/check_in_repository.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/domain/employee_lookup.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../../domain/substitute_check_in_mapping.dart';
import 'admin_auth_provider.dart';

/// Default session day for Daily Attendance.
///
/// Date restriction ON: current or previous Thursday (session stays open until
/// the next Thursday starts).
/// Date restriction OFF: today (everyday check-ins).
DateTime defaultAttendanceSessionDate(
  DateTime now, {
  bool? dateRestrictionEnabled,

  /// Legacy alias — prefer [dateRestrictionEnabled].
  bool? restrictionsEnabled,
}) {
  final dateOn = dateRestrictionEnabled ?? restrictionsEnabled ?? true;
  final today = DateTime(now.year, now.month, now.day);

  if (!dateOn) return today;
  if (today.weekday == DateTime.thursday) return today;

  var daysSinceThursday = (today.weekday - DateTime.thursday) % 7;
  if (daysSinceThursday <= 0) daysSinceThursday += 7;
  return today.subtract(Duration(days: daysSinceThursday));
}

/// Filter selection for the admin dashboard.
enum AdminFilterType {
  all('All Records'),
  member('Members Only'),
  substitute('Substitutes Only'),
  absent('Absent Only');

  const AdminFilterType(this.label);
  final String label;
}

/// Sort order for the daily attendance list.
enum AdminDashboardSortMode {
  recent('Recent'),
  alphabetical('Name A–Z');

  const AdminDashboardSortMode(this.label);
  final String label;
}

String _ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Live check-ins for Daily Attendance — narrowed by session date (+ location).
final checkInsStreamProvider = StreamProvider<List<CheckInSubmission>>((ref) {
  final auth = ref.watch(adminAuthProvider);
  if (!auth.sessionResolved) {
    return pendingStreamController<List<CheckInSubmission>>(
      onDispose: ref.onDispose,
    ).stream;
  }
  if (!auth.isAuthenticated) {
    return Stream.value(const <CheckInSubmission>[]);
  }
  final filters = ref.watch(adminDashboardFilterProvider);
  final dateRestrictionEnabled = ref.watch(dateRestrictionEnabledProvider);
  final target =
      filters.selectedDate ??
      defaultAttendanceSessionDate(
        DateTime.now(),
        dateRestrictionEnabled: dateRestrictionEnabled,
      );
  final repository = ref.watch(checkInRepositoryProvider);
  final assigned = auth.currentAdmin?.assignedLocationIds ?? const <String>[];
  var locationId = filters.selectedLocationId?.trim();
  if (locationId != null && locationId.isEmpty) locationId = null;
  // Non-superadmin with assigned locations: clamp stream to that set.
  if (auth.currentAdmin != null &&
      !auth.currentAdmin!.isSuperAdmin &&
      assigned.isNotEmpty) {
    if (locationId == null || !assigned.contains(locationId)) {
      locationId = assigned.length == 1 ? assigned.first : locationId;
    }
  }
  return repository.streamCheckIns(
    locationId: locationId,
    sessionDateYmd: _ymd(target),
  );
});

/// Search and filter query state.
class AdminDashboardFilterState {
  const AdminDashboardFilterState({
    this.searchQuery = '',
    this.filterType = AdminFilterType.all,
    this.sortMode = AdminDashboardSortMode.alphabetical,
    this.selectedLocationId,
    this.selectedDate,
  });

  final String searchQuery;
  final AdminFilterType filterType;
  final AdminDashboardSortMode sortMode;
  final String? selectedLocationId;
  final DateTime? selectedDate;

  AdminDashboardFilterState copyWith({
    String? searchQuery,
    AdminFilterType? filterType,
    AdminDashboardSortMode? sortMode,
    String? selectedLocationId,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
  }) {
    return AdminDashboardFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      filterType: filterType ?? this.filterType,
      sortMode: sortMode ?? this.sortMode,
      selectedLocationId: selectedLocationId ?? this.selectedLocationId,
      selectedDate: clearSelectedDate
          ? null
          : (selectedDate ?? this.selectedDate),
    );
  }
}

/// Notifier managing search query and filters.
class AdminDashboardFilterNotifier extends Notifier<AdminDashboardFilterState> {
  @override
  AdminDashboardFilterState build() {
    return const AdminDashboardFilterState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setFilterType(AdminFilterType type) {
    state = state.copyWith(filterType: type);
  }

  void setSortMode(AdminDashboardSortMode mode) {
    state = state.copyWith(sortMode: mode);
  }

  void setLocationId(String? locationId) {
    state = state.copyWith(selectedLocationId: locationId);
  }

  void setSelectedDate(DateTime? date) {
    state = state.copyWith(selectedDate: date, clearSelectedDate: date == null);
  }
}

final adminDashboardFilterProvider =
    NotifierProvider<AdminDashboardFilterNotifier, AdminDashboardFilterState>(
      () {
        return AdminDashboardFilterNotifier();
      },
    );

/// Immutable state for paginated check-in records.
class PaginatedCheckInsState {
  const PaginatedCheckInsState({
    this.items = const [],
    this.isLoadingFirstPage = false,
    this.isLoadingMore = false,
    this.hasReachedEnd = false,
    this.error,
    this.lastDocument,
  });

  final List<CheckInSubmission> items;
  final bool isLoadingFirstPage;
  final bool isLoadingMore;
  final bool hasReachedEnd;
  final String? error;
  final Object? lastDocument;

  bool get isEmpty => items.isEmpty && !isLoadingFirstPage;

  PaginatedCheckInsState copyWith({
    List<CheckInSubmission>? items,
    bool? isLoadingFirstPage,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    String? error,
    Object? lastDocument,
    bool clearError = false,
    bool clearLastDocument = false,
  }) {
    return PaginatedCheckInsState(
      items: items ?? this.items,
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      error: clearError ? null : (error ?? this.error),
      lastDocument: clearLastDocument
          ? null
          : (lastDocument ?? this.lastDocument),
    );
  }
}

/// Notifier managing incremental cursor-based page loading from Firestore.
/// Uses real `getPaginatedCheckIns` pages (not a full-collection stream dump).
class PaginatedCheckInsNotifier extends Notifier<PaginatedCheckInsState> {
  @override
  PaginatedCheckInsState build() {
    Future.microtask(loadFirstPage);
    return const PaginatedCheckInsState(isLoadingFirstPage: true);
  }

  CheckInRepository get _repository => ref.read(checkInRepositoryProvider);

  /// Loads the first cursor page from Firestore.
  Future<void> loadFirstPage() async {
    state = state.copyWith(
      isLoadingFirstPage: true,
      items: const [],
      hasReachedEnd: false,
      clearError: true,
      clearLastDocument: true,
    );

    try {
      final result = await _repository.getPaginatedCheckIns(
        limit: AppConstants.dashboardPageSize,
      );
      state = state.copyWith(
        items: result.items,
        lastDocument: result.lastDocument,
        hasReachedEnd: !result.hasMore,
        isLoadingFirstPage: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoadingFirstPage: false, error: e.toString());
    }
  }

  /// Loads the next page using startAfterDocument cursor.
  Future<void> loadNextPage() async {
    if (state.isLoadingFirstPage ||
        state.isLoadingMore ||
        state.hasReachedEnd) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, clearError: true);

    try {
      final result = await _repository.getPaginatedCheckIns(
        limit: AppConstants.dashboardPageSize,
        startAfter: state.lastDocument,
      );

      state = state.copyWith(
        items: [...state.items, ...result.items],
        lastDocument: result.lastDocument ?? state.lastDocument,
        hasReachedEnd: !result.hasMore,
        isLoadingMore: false,
        clearError: true,
      );
    } catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  /// Reloads from the first page.
  Future<void> refresh() async {
    await loadFirstPage();
  }

  /// Optimistically removes a deleted item.
  void removeCheckIn(String checkInId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != checkInId).toList(),
    );
  }

  /// Optimistically updates an item in the list.
  ///
  /// [replaceId] swaps a placeholder / previous id when admin materializes a
  /// new Firestore document (e.g. Not Checked In → Absent).
  void updateCheckInItem(CheckInSubmission updated, {String? replaceId}) {
    final fromId = replaceId ?? updated.id;
    var replaced = false;
    final items = state.items.map((item) {
      final match =
          item.id == fromId ||
          item.id == updated.id ||
          (updated.memberId != null &&
              updated.memberId!.isNotEmpty &&
              item.memberId == updated.memberId &&
              item.type.isNotCheckedIn);
      if (!match) return item;
      replaced = true;
      return updated;
    }).toList();
    state = state.copyWith(items: replaced ? items : [...items, updated]);
  }

  /// Clears all items locally after bulk delete.
  void clearAll() {
    state = state.copyWith(items: [], hasReachedEnd: true);
  }
}

final paginatedCheckInsProvider =
    NotifierProvider<PaginatedCheckInsNotifier, PaginatedCheckInsState>(() {
      return PaginatedCheckInsNotifier();
    });

/// Filtered view over the real-time check-in stream based on search and attendance type filters.
final filteredPaginatedCheckInsProvider = Provider<List<CheckInSubmission>>((
  ref,
) {
  final filteredAsync = ref.watch(filteredCheckInsProvider);
  // Prefer last good data while a refresh is in flight; never invent [].
  return filteredAsync.asData?.value ?? const [];
});

/// Base records for the dashboard: maps all active members and their check-in status for the target Thursday.
final baseDashboardRecordsProvider = Provider<AsyncValue<List<CheckInSubmission>>>((
  ref,
) {
  final checkInsAsync = ref.watch(checkInsStreamProvider);
  final filters = ref.watch(adminDashboardFilterProvider);
  final employeesAsync = ref.watch(employeesStreamProvider);

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

  final records = checkInsAsync.value ?? [];
  final employees = employeesAsync.value ?? [];
  final activeEmployees = employees.where((e) => e.isActive).toList();
  final dateRestrictionEnabled = ref.watch(dateRestrictionEnabledProvider);

  final now = DateTime.now();
  final DateTime targetDate =
      filters.selectedDate ??
      defaultAttendanceSessionDate(
        now,
        dateRestrictionEnabled: dateRestrictionEnabled,
      );

  final daySubmissions = records.where((r) {
    final rec = r.timestamp;
    return rec.year == targetDate.year &&
        rec.month == targetDate.month &&
        rec.day == targetDate.day;
  }).toList();

  final resultRows = <CheckInSubmission>[];

  for (final emp in activeEmployees) {
    CheckInSubmission? matchedSubmission;

    if (daySubmissions.isNotEmpty) {
      // 1. Check if a substitute checked in for this member
      final subMatches = daySubmissions
          .where((r) => substituteCheckInCoversMember(raw: r, member: emp))
          .toList();

      if (subMatches.isNotEmpty) {
        subMatches.sort(
          (a, b) => (b.createdAt ?? b.timestamp).compareTo(
            a.createdAt ?? a.timestamp,
          ),
        );
        matchedSubmission = mapSubstituteCheckInForMember(
          raw: subMatches.first,
          member: emp,
        );
      } else {
        // 2. Check if member checked in directly or was marked absent
        final memberMatches = daySubmissions.where((r) {
          if (r.type.isVisitor) return false;
          if (r.type.isSubstitute) return false;
          final matched = EmployeeLookup.forCheckIn([emp], r);
          return matched != null;
        }).toList();

        if (memberMatches.isNotEmpty) {
          memberMatches.sort((a, b) {
            if (a.id.startsWith('absent_') && !b.id.startsWith('absent_')) {
              return 1;
            }
            if (!a.id.startsWith('absent_') && b.id.startsWith('absent_')) {
              return -1;
            }
            return (b.createdAt ?? b.timestamp).compareTo(
              a.createdAt ?? a.timestamp,
            );
          });
          final m = memberMatches.first;
          matchedSubmission = m.copyWith(
            userName: emp.name,
            userPhone: emp.phone,
            userEmail: emp.email,
            substituteName: null,
            memberId: emp.id,
          );
        }
      }
    }

    if (matchedSubmission != null) {
      resultRows.add(matchedSubmission);
    } else {
      // Active member has not checked in yet
      final dateForPlaceholder = targetDate;
      resultRows.add(
        CheckInSubmission(
          id: 'not_checked_in_${emp.id}_${dateForPlaceholder.millisecondsSinceEpoch}',
          locationId: '',
          locationName: '—',
          userName: emp.name,
          userPhone: emp.phone,
          type: CheckInType.notCheckedIn,
          userLatitude: 0,
          userLongitude: 0,
          gpsAccuracy: 0,
          distanceMeters: 0,
          timestamp: DateTime(
            dateForPlaceholder.year,
            dateForPlaceholder.month,
            dateForPlaceholder.day,
            0,
            0,
          ),
          isVerified: false,
          memberId: emp.id,
        ),
      );
    }
  }

  return AsyncValue.data(resultRows);
});

/// Filters and sorts daily attendance records. Exposed for unit tests.
List<CheckInSubmission> filterAndSortDashboardRecords({
  required List<CheckInSubmission> records,
  required AdminDashboardFilterState filters,
}) {
  final filtered = records.where((record) {
    if (record.type.isVisitor) return false;
    if (filters.filterType == AdminFilterType.member && !record.type.isMember) {
      return false;
    }
    if (filters.filterType == AdminFilterType.substitute &&
        !record.type.isSubstitute) {
      return false;
    }
    if (filters.filterType == AdminFilterType.absent && !record.type.isAbsent) {
      return false;
    }
    if (filters.selectedLocationId != null &&
        filters.selectedLocationId!.isNotEmpty &&
        record.locationId != filters.selectedLocationId &&
        !record.type.isNotCheckedIn) {
      return false;
    }
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      final matchesName = record.userName.toLowerCase().contains(query);
      final matchesPhone = record.userPhone.toLowerCase().contains(query);
      final matchesSub = (record.substituteName ?? '').toLowerCase().contains(
        query,
      );
      if (!matchesName && !matchesPhone && !matchesSub) return false;
    }
    return true;
  }).toList();

  if (filters.sortMode == AdminDashboardSortMode.alphabetical) {
    filtered.sort((a, b) {
      final byName = a.userName.toLowerCase().compareTo(
        b.userName.toLowerCase(),
      );
      if (byName != 0) return byName;
      final aTime = a.createdAt ?? a.timestamp;
      final bTime = b.createdAt ?? b.timestamp;
      return bTime.compareTo(aTime);
    });
  } else {
    filtered.sort((a, b) {
      // Show checked in members first, then not checked in
      if (a.type.isNotCheckedIn && !b.type.isNotCheckedIn) return 1;
      if (!a.type.isNotCheckedIn && b.type.isNotCheckedIn) return -1;
      final aTime = a.createdAt ?? a.timestamp;
      final bTime = b.createdAt ?? b.timestamp;
      final cmp = bTime.compareTo(aTime);
      if (cmp != 0) return cmp;
      return a.userName.toLowerCase().compareTo(b.userName.toLowerCase());
    });
  }

  return filtered;
}

/// Filtered view over the real-time check-in stream based on search and attendance type filters.
///
/// Preserves loading/error from [baseDashboardRecordsProvider] instead of
/// collapsing them to an empty list (which looked like "no data").
final filteredCheckInsProvider = Provider<AsyncValue<List<CheckInSubmission>>>((
  ref,
) {
  final baseRecordsAsync = ref.watch(baseDashboardRecordsProvider);
  final filters = ref.watch(adminDashboardFilterProvider);

  return baseRecordsAsync.when(
    loading: () => const AsyncValue.loading(),
    error: AsyncValue.error,
    data: (records) {
      final filtered = filterAndSortDashboardRecords(
        records: records,
        filters: filters,
      );
      return AsyncValue.data(filtered);
    },
  );
});
