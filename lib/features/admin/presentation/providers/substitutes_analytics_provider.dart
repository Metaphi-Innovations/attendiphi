import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/supabase/resilient_poll_stream.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../../domain/substitutes_analytics.dart';
import 'admin_auth_provider.dart';

/// Filter / sort state for the Substitutes overview.
class SubstitutesFilterState {
  const SubstitutesFilterState({
    this.searchQuery = '',
    this.rangeStart,
    this.rangeEnd,
    this.coveredMemberKey,
    this.sort = SubstituteSortOption.visitsDesc,
  });

  final String searchQuery;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String? coveredMemberKey;
  final SubstituteSortOption sort;

  SubstitutesFilterState copyWith({
    String? searchQuery,
    DateTime? rangeStart,
    DateTime? rangeEnd,
    String? coveredMemberKey,
    SubstituteSortOption? sort,
    bool clearRange = false,
    bool clearCoveredMember = false,
  }) {
    return SubstitutesFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      rangeStart: clearRange ? null : (rangeStart ?? this.rangeStart),
      rangeEnd: clearRange ? null : (rangeEnd ?? this.rangeEnd),
      coveredMemberKey: clearCoveredMember
          ? null
          : (coveredMemberKey ?? this.coveredMemberKey),
      sort: sort ?? this.sort,
    );
  }
}

class SubstitutesFilterNotifier extends Notifier<SubstitutesFilterState> {
  @override
  SubstitutesFilterState build() => const SubstitutesFilterState();

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setSort(SubstituteSortOption sort) {
    state = state.copyWith(sort: sort);
  }

  void setDateRange(DateTimeRange? range) {
    if (range == null) {
      state = state.copyWith(clearRange: true);
      return;
    }
    state = state.copyWith(rangeStart: range.start, rangeEnd: range.end);
  }

  /// Filters to a single Thursday session day (same UX as Daily Attendance).
  void setSessionDate(DateTime? date) {
    if (date == null) {
      state = state.copyWith(clearRange: true);
      return;
    }
    final day = DateTime(date.year, date.month, date.day);
    state = state.copyWith(rangeStart: day, rangeEnd: day);
  }

  void setCoveredMemberKey(String? key) {
    if (key == null || key.isEmpty) {
      state = state.copyWith(clearCoveredMember: true);
      return;
    }
    state = state.copyWith(coveredMemberKey: key);
  }

  void reset() {
    state = const SubstitutesFilterState();
  }
}

final substitutesFilterProvider =
    NotifierProvider<SubstitutesFilterNotifier, SubstitutesFilterState>(
      SubstitutesFilterNotifier.new,
    );

String _subYmd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}

/// Range-scoped substitute check-ins (default last 90 days).
final substitutesCheckInsStreamProvider =
    StreamProvider<List<CheckInSubmission>>((ref) {
      final auth = ref.watch(adminAuthProvider);
      if (!auth.sessionResolved) {
        return pendingStreamController<List<CheckInSubmission>>(
          onDispose: ref.onDispose,
        ).stream;
      }
      if (!auth.isAuthenticated) {
        return Stream.value(const <CheckInSubmission>[]);
      }
      final filters = ref.watch(substitutesFilterProvider);
      final now = DateTime.now();
      final from = filters.rangeStart ?? now.subtract(const Duration(days: 90));
      final to = filters.rangeEnd ?? now;
      final repository = ref.watch(checkInRepositoryProvider);
      return repository.streamCheckIns(
        sessionDateFrom: _subYmd(DateTime(from.year, from.month, from.day)),
        sessionDateTo: _subYmd(DateTime(to.year, to.month, to.day)),
      );
    });

/// Aggregated substitute analytics from a date-scoped check-in stream + roster.
final substitutesAnalyticsProvider = Provider<AsyncValue<SubstitutesAnalytics>>(
  (ref) {
    final checkInsAsync = ref.watch(substitutesCheckInsStreamProvider);
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

    return AsyncValue.data(
      buildSubstitutesAnalytics(
        checkIns: checkInsAsync.value ?? const [],
        employees: employeesAsync.value ?? const [],
      ),
    );
  },
);

/// Filtered / sorted overview list for the Substitutes page.
final filteredSubstituteProfilesProvider =
    Provider<AsyncValue<List<SubstituteProfile>>>((ref) {
      final analyticsAsync = ref.watch(substitutesAnalyticsProvider);
      final filters = ref.watch(substitutesFilterProvider);

      return analyticsAsync.whenData((analytics) {
        return filterAndSortSubstituteProfiles(
          profiles: analytics.profiles,
          searchQuery: filters.searchQuery,
          rangeStart: filters.rangeStart,
          rangeEnd: filters.rangeEnd,
          coveredMemberKeyFilter: filters.coveredMemberKey,
          sort: filters.sort,
        );
      });
    });

/// Lookup a single substitute profile by identity key.
final substituteProfileByKeyProvider =
    Provider.family<AsyncValue<SubstituteProfile?>, String>((ref, key) {
      final analyticsAsync = ref.watch(substitutesAnalyticsProvider);
      return analyticsAsync.whenData((analytics) {
        for (final profile in analytics.profiles) {
          if (profile.identityKey == key) return profile;
        }
        return null;
      });
    });
