import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/domain/employee_lookup.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import 'admin_auth_provider.dart';

/// Date range filter presets for Visitor screen.
enum VisitorDateFilterPreset {
  all('All Dates'),
  today('Today'),
  thisWeek('This Week'),
  thisMonth('This Month'),
  custom('Custom Range');

  const VisitorDateFilterPreset(this.label);
  final String label;
}

/// Filter state for the Visitor Management & Records Screen.
class VisitorFilterState {
  const VisitorFilterState({
    this.searchQuery = '',
    this.selectedDate,
    this.datePreset = VisitorDateFilterPreset.all,
    this.customDateRange,
    this.selectedCategory,
  });

  final String searchQuery;
  final DateTime? selectedDate;
  final VisitorDateFilterPreset datePreset;
  final DateTimeRange? customDateRange;
  final String? selectedCategory;

  VisitorFilterState copyWith({
    String? searchQuery,
    DateTime? Function()? selectedDate,
    VisitorDateFilterPreset? datePreset,
    DateTimeRange? Function()? customDateRange,
    String? Function()? selectedCategory,
  }) {
    return VisitorFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      selectedDate: selectedDate != null ? selectedDate() : this.selectedDate,
      datePreset: datePreset ?? this.datePreset,
      customDateRange: customDateRange != null
          ? customDateRange()
          : this.customDateRange,
      selectedCategory: selectedCategory != null
          ? selectedCategory()
          : this.selectedCategory,
    );
  }
}

/// Filter notifier for Visitor screen.
class VisitorFilterNotifier extends Notifier<VisitorFilterState> {
  @override
  VisitorFilterState build() {
    return const VisitorFilterState();
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query.trim());
  }

  void setSelectedDate(DateTime? date) {
    state = state.copyWith(selectedDate: () => date);
  }

  void setDatePreset(VisitorDateFilterPreset preset) {
    state = state.copyWith(datePreset: preset, customDateRange: () => null);
  }

  void setCustomDateRange(DateTimeRange? range) {
    state = state.copyWith(
      datePreset: VisitorDateFilterPreset.custom,
      customDateRange: () => range,
    );
  }

  void setSelectedCategory(String? category) {
    state = state.copyWith(selectedCategory: () => category);
  }

  void resetFilters() {
    state = const VisitorFilterState();
  }
}

final visitorFilterProvider =
    NotifierProvider<VisitorFilterNotifier, VisitorFilterState>(
      VisitorFilterNotifier.new,
    );

String _visitorYmd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Visitors-owned check-in stream (not Daily Attendance's single-day feed).
///
/// - Selected Thursday → that `session_date` only
/// - All / presets → bounded `session_date` range so Oct 8 data is reachable
///   while Daily Attendance stays on a different day (e.g. Oct 15)
final visitorsCheckInsStreamProvider = StreamProvider<List<CheckInSubmission>>((
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

  final filters = ref.watch(visitorFilterProvider);
  final repository = ref.watch(checkInRepositoryProvider);
  final now = DateTime.now();

  if (filters.selectedDate != null) {
    final day = DateTime(
      filters.selectedDate!.year,
      filters.selectedDate!.month,
      filters.selectedDate!.day,
    );
    return repository.streamCheckIns(sessionDateYmd: _visitorYmd(day));
  }

  late final DateTime from;
  late final DateTime to;
  switch (filters.datePreset) {
    case VisitorDateFilterPreset.today:
      from = DateTime(now.year, now.month, now.day);
      to = from;
    case VisitorDateFilterPreset.thisWeek:
      final monday = now.subtract(Duration(days: now.weekday - 1));
      from = DateTime(monday.year, monday.month, monday.day);
      to = from.add(const Duration(days: 6));
    case VisitorDateFilterPreset.thisMonth:
      from = DateTime(now.year, now.month, 1);
      to = DateTime(now.year, now.month + 1, 0);
    case VisitorDateFilterPreset.custom:
      final range = filters.customDateRange;
      if (range != null) {
        from = DateTime(range.start.year, range.start.month, range.start.day);
        to = DateTime(range.end.year, range.end.month, range.end.day);
      } else {
        from = now.subtract(const Duration(days: 180));
        to = now;
      }
    case VisitorDateFilterPreset.all:
      // Default window so historical Thursdays (e.g. 08 Oct) load without
      // dumping unbounded history.
      from = now.subtract(const Duration(days: 180));
      to = now;
  }

  return repository.streamCheckIns(
    sessionDateFrom: _visitorYmd(from),
    sessionDateTo: _visitorYmd(to),
  );
});

/// Deduplicated visitor check-ins for the Visitors screen.
final allVisitorsProvider = Provider<AsyncValue<List<CheckInSubmission>>>((
  ref,
) {
  final checkInsAsync = ref.watch(visitorsCheckInsStreamProvider);

  return checkInsAsync.whenData((checkIns) {
    final employees = ref.watch(employeesStreamProvider).value ?? [];
    final rawVisitors = checkIns
        .where((c) => c.type == CheckInType.visitor)
        .toList();
    rawVisitors.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    final seenKeys = <String>{};
    final uniqueVisitors = <CheckInSubmission>[];

    for (final v in rawVisitors) {
      final liveInviter = EmployeeLookup.liveDisplayName(
        employees,
        v.invitedByMember,
      );
      final resolved =
          liveInviter.isNotEmpty && liveInviter != v.invitedByMember
          ? v.copyWith(invitedByMember: liveInviter)
          : v;
      final key =
          '${resolved.userName.trim().toLowerCase()}_${resolved.userPhone.trim()}_'
          '${resolved.timestamp.year}-${resolved.timestamp.month}-${resolved.timestamp.day}_'
          '${resolved.timestamp.hour}:${resolved.timestamp.minute}';
      if (seenKeys.add(key)) {
        uniqueVisitors.add(resolved);
      }
    }

    return uniqueVisitors;
  });
});

/// Filtered list of visitors based on search query, date filter presets/range, and category.
final filteredVisitorsProvider = Provider<AsyncValue<List<CheckInSubmission>>>((
  ref,
) {
  final visitorsAsync = ref.watch(allVisitorsProvider);
  final filterState = ref.watch(visitorFilterProvider);

  return visitorsAsync.whenData((visitors) {
    return visitors.where((v) {
      // 1. Search Query
      if (filterState.searchQuery.isNotEmpty) {
        final q = filterState.searchQuery.toLowerCase();
        final matchName = v.userName.toLowerCase().contains(q);
        final matchPhone = v.userPhone.toLowerCase().contains(q);
        final matchEmail = (v.userEmail ?? '').toLowerCase().contains(q);
        final matchCompany = (v.companyName ?? '').toLowerCase().contains(q);
        final matchCategory = (v.category ?? '').toLowerCase().contains(q);
        final matchInviter = (v.invitedByMember ?? '').toLowerCase().contains(
          q,
        );

        if (!matchName &&
            !matchPhone &&
            !matchEmail &&
            !matchCompany &&
            !matchCategory &&
            !matchInviter) {
          return false;
        }
      }

      // 2. Date scope is applied in [visitorsCheckInsStreamProvider]
      // (session_date). Do not re-filter by timestamp day — that hid Oct 8
      // rows when timestamp and session_date differed slightly.

      // 3. Category Filter
      if (filterState.selectedCategory != null &&
          filterState.selectedCategory!.isNotEmpty) {
        if ((v.category ?? '').toLowerCase() !=
            filterState.selectedCategory!.toLowerCase()) {
          return false;
        }
      }

      return true;
    }).toList();
  });
});

/// Unique categories extracted from all visitor records.
final uniqueVisitorCategoriesProvider = Provider<List<String>>((ref) {
  final visitorsAsync = ref.watch(allVisitorsProvider);
  final visitors = visitorsAsync.value ?? [];
  final categories = <String>{};

  for (final v in visitors) {
    if (v.category != null && v.category!.trim().isNotEmpty) {
      categories.add(v.category!.trim());
    }
  }

  final sorted = categories.toList()..sort();
  return sorted;
});

/// Aggregate summary metrics for visitors calculated accurately from deduplicated records.
class VisitorOverviewStats {
  const VisitorOverviewStats({
    required this.totalVisitors,
    required this.uniqueCompanies,
    required this.uniqueCategories,
    required this.topInviter,
    required this.topInviterCount,
  });

  final int totalVisitors;
  final int uniqueCompanies;
  final int uniqueCategories;
  final String topInviter;
  final int topInviterCount;
}

final visitorOverviewStatsProvider = Provider<AsyncValue<VisitorOverviewStats>>(
  (ref) {
    final visitorsAsync = ref.watch(allVisitorsProvider);

    return visitorsAsync.whenData((visitors) {
      final companies = <String>{};
      final categories = <String>{};
      final inviterCounts = <String, int>{};

      for (final v in visitors) {
        if (v.companyName != null && v.companyName!.trim().isNotEmpty) {
          companies.add(v.companyName!.trim().toLowerCase());
        }
        if (v.category != null && v.category!.trim().isNotEmpty) {
          categories.add(v.category!.trim().toLowerCase());
        }
        if (v.invitedByMember != null && v.invitedByMember!.trim().isNotEmpty) {
          final inviter = v.invitedByMember!.trim();
          inviterCounts[inviter] = (inviterCounts[inviter] ?? 0) + 1;
        }
      }

      String topInviter = 'None';
      int topCount = 0;
      inviterCounts.forEach((inviter, count) {
        if (count > topCount) {
          topCount = count;
          topInviter = inviter;
        }
      });

      return VisitorOverviewStats(
        totalVisitors: visitors.length,
        uniqueCompanies: companies.length,
        uniqueCategories: categories.length,
        topInviter: topInviter,
        topInviterCount: topCount,
      );
    });
  },
);
