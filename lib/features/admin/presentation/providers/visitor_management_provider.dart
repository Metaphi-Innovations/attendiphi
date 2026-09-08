import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import 'admin_dashboard_provider.dart';

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
      selectedDate: selectedDate != null
          ? selectedDate()
          : this.selectedDate,
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
    state = state.copyWith(
      selectedDate: () => date,
    );
  }

  void setDatePreset(VisitorDateFilterPreset preset) {
    state = state.copyWith(
      datePreset: preset,
      customDateRange: () => null,
    );
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

/// Stream provider for all visitor check-in submissions, deduplicated at the data layer.
final allVisitorsProvider =
    Provider<AsyncValue<List<CheckInSubmission>>>((ref) {
  final checkInsAsync = ref.watch(checkInsStreamProvider);

  return checkInsAsync.whenData((checkIns) {
    final rawVisitors =
        checkIns.where((c) => c.type == CheckInType.visitor).toList();
    // Sort descending by timestamp first
    rawVisitors.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Deduplicate by composite identity: (name, phone, date & time minute)
    final seenKeys = <String>{};
    final uniqueVisitors = <CheckInSubmission>[];

    for (final v in rawVisitors) {
      final key = '${v.userName.trim().toLowerCase()}_${v.userPhone.trim()}_'
          '${v.timestamp.year}-${v.timestamp.month}-${v.timestamp.day}_'
          '${v.timestamp.hour}:${v.timestamp.minute}';
      if (seenKeys.add(key)) {
        uniqueVisitors.add(v);
      }
    }

    return uniqueVisitors;
  });
});

/// Filtered list of visitors based on search query, date filter presets/range, and category.
final filteredVisitorsProvider =
    Provider<AsyncValue<List<CheckInSubmission>>>((ref) {
  final visitorsAsync = ref.watch(allVisitorsProvider);
  final filterState = ref.watch(visitorFilterProvider);

  return visitorsAsync.whenData((visitors) {
    final now = DateTime.now();

    return visitors.where((v) {
      // 1. Search Query
      if (filterState.searchQuery.isNotEmpty) {
        final q = filterState.searchQuery.toLowerCase();
        final matchName = v.userName.toLowerCase().contains(q);
        final matchPhone = v.userPhone.toLowerCase().contains(q);
        final matchEmail = (v.userEmail ?? '').toLowerCase().contains(q);
        final matchCompany = (v.companyName ?? '').toLowerCase().contains(q);
        final matchCategory = (v.category ?? '').toLowerCase().contains(q);
        final matchInviter =
            (v.invitedByMember ?? '').toLowerCase().contains(q);

        if (!matchName &&
            !matchPhone &&
            !matchEmail &&
            !matchCompany &&
            !matchCategory &&
            !matchInviter) {
          return false;
        }
      }

      // 2. Thursday Session Date Filter
      if (filterState.selectedDate != null) {
        final d = filterState.selectedDate!;
        final isSameDate = v.timestamp.year == d.year &&
            v.timestamp.month == d.month &&
            v.timestamp.day == d.day;
        if (!isSameDate) return false;
      } else {
        // Fallback to datePreset if set
        switch (filterState.datePreset) {
          case VisitorDateFilterPreset.all:
            break;
          case VisitorDateFilterPreset.today:
            final isToday = v.timestamp.year == now.year &&
                v.timestamp.month == now.month &&
                v.timestamp.day == now.day;
            if (!isToday) return false;
            break;
          case VisitorDateFilterPreset.thisWeek:
            final monday = now.subtract(Duration(days: now.weekday - 1));
            final startOfWeek = DateTime(monday.year, monday.month, monday.day);
            final endOfWeek = startOfWeek.add(const Duration(days: 7));
            if (v.timestamp.isBefore(startOfWeek) ||
                v.timestamp.isAfter(endOfWeek)) {
              return false;
            }
            break;
          case VisitorDateFilterPreset.thisMonth:
            final isThisMonth = v.timestamp.year == now.year &&
                v.timestamp.month == now.month;
            if (!isThisMonth) return false;
            break;
          case VisitorDateFilterPreset.custom:
            if (filterState.customDateRange != null) {
              final range = filterState.customDateRange!;
              final start = DateTime(range.start.year, range.start.month, range.start.day);
              final end = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
              if (v.timestamp.isBefore(start) || v.timestamp.isAfter(end)) {
                return false;
              }
            }
            break;
        }
      }

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

final visitorOverviewStatsProvider =
    Provider<AsyncValue<VisitorOverviewStats>>((ref) {
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
});
