import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../../checkin/domain/repositories/check_in_repository.dart';
import '../../../checkin/presentation/providers/checkin_providers.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
/// Filter selection for the admin dashboard.
enum AdminFilterType {
  all('All Records'),
  member('Members Only'),
  substitute('Substitutes Only'),
  absent('Absent Only');

  const AdminFilterType(this.label);
  final String label;
}

/// Real-time stream provider for check-ins across the unified database.
final checkInsStreamProvider = StreamProvider<List<CheckInSubmission>>((ref) {
  final repository = ref.watch(checkInRepositoryProvider);
  return repository.streamCheckIns();
});

/// Search and filter query state.
class AdminDashboardFilterState {
  const AdminDashboardFilterState({
    this.searchQuery = '',
    this.filterType = AdminFilterType.all,
    this.selectedLocationId,
    this.selectedDate,
  });

  final String searchQuery;
  final AdminFilterType filterType;
  final String? selectedLocationId;
  final DateTime? selectedDate;

  AdminDashboardFilterState copyWith({
    String? searchQuery,
    AdminFilterType? filterType,
    String? selectedLocationId,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
  }) {
    return AdminDashboardFilterState(
      searchQuery: searchQuery ?? this.searchQuery,
      filterType: filterType ?? this.filterType,
      selectedLocationId: selectedLocationId ?? this.selectedLocationId,
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
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

  void setLocationId(String? locationId) {
    state = state.copyWith(selectedLocationId: locationId);
  }

  void setSelectedDate(DateTime? date) {
    state = state.copyWith(
      selectedDate: date,
      clearSelectedDate: date == null,
    );
  }
}

final adminDashboardFilterProvider = NotifierProvider<
    AdminDashboardFilterNotifier, AdminDashboardFilterState>(() {
  return AdminDashboardFilterNotifier();
});

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
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  bool get isEmpty => items.isEmpty && !isLoadingFirstPage;

  PaginatedCheckInsState copyWith({
    List<CheckInSubmission>? items,
    bool? isLoadingFirstPage,
    bool? isLoadingMore,
    bool? hasReachedEnd,
    String? error,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool clearError = false,
  }) {
    return PaginatedCheckInsState(
      items: items ?? this.items,
      isLoadingFirstPage: isLoadingFirstPage ?? this.isLoadingFirstPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedEnd: hasReachedEnd ?? this.hasReachedEnd,
      error: clearError ? null : (error ?? this.error),
      lastDocument: lastDocument ?? this.lastDocument,
    );
  }
}

/// Notifier managing incremental cursor-based page loading from Firestore.
class PaginatedCheckInsNotifier extends Notifier<PaginatedCheckInsState> {
  @override
  PaginatedCheckInsState build() {
    // Listen to real-time Firestore stream
    ref.listen<AsyncValue<List<CheckInSubmission>>>(
      checkInsStreamProvider,
      (previous, next) {
        next.when(
          data: (streamItems) {
            state = state.copyWith(
              items: streamItems,
              isLoadingFirstPage: false,
              hasReachedEnd: true,
              clearError: true,
            );
          },
          loading: () {
            if (state.items.isEmpty) {
              state = state.copyWith(isLoadingFirstPage: true);
            }
          },
          error: (err, stack) {
            if (state.items.isEmpty) {
              state = state.copyWith(
                isLoadingFirstPage: false,
                error: err.toString(),
              );
            }
          },
        );
      },
    );

    final currentStream = ref.read(checkInsStreamProvider);
    if (currentStream.hasValue && currentStream.value != null) {
      return PaginatedCheckInsState(
        items: currentStream.value!,
        isLoadingFirstPage: false,
        hasReachedEnd: true,
      );
    }

    return PaginatedCheckInsState(
      isLoadingFirstPage: currentStream.isLoading,
      error: currentStream.hasError ? currentStream.error.toString() : null,
    );
  }

  CheckInRepository get _repository => ref.read(checkInRepositoryProvider);

  /// Reloads the real-time stream.
  Future<void> loadFirstPage() async {
    ref.invalidate(checkInsStreamProvider);
  }

  /// Loads the next page using startAfterDocument cursor.
  Future<void> loadNextPage() async {
    if (state.isLoadingFirstPage || state.isLoadingMore || state.hasReachedEnd) {
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
      state = state.copyWith(
        isLoadingMore: false,
        error: e.toString(),
      );
    }
  }

  /// Refreshes the list from stream.
  Future<void> refresh() async {
    ref.invalidate(checkInsStreamProvider);
  }

  /// Optimistically removes a deleted item.
  void removeCheckIn(String checkInId) {
    state = state.copyWith(
      items: state.items.where((i) => i.id != checkInId).toList(),
    );
  }

  /// Optimistically updates an item in the list.
  void updateCheckInItem(CheckInSubmission updated) {
    state = state.copyWith(
      items: state.items.map((i) => i.id == updated.id ? updated : i).toList(),
    );
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
final filteredPaginatedCheckInsProvider =
    Provider<List<CheckInSubmission>>((ref) {
  final filteredAsync = ref.watch(filteredCheckInsProvider);
  return filteredAsync.value ?? [];
});

/// Base records for the dashboard: applies date filter and generates dummy absent records.
final baseDashboardRecordsProvider =
    Provider<AsyncValue<List<CheckInSubmission>>>((ref) {
  final checkInsAsync = ref.watch(checkInsStreamProvider);
  final filters = ref.watch(adminDashboardFilterProvider);
  final employeesAsync = ref.watch(employeesStreamProvider);

  return checkInsAsync.whenData((records) {
    List<CheckInSubmission> filtered = records.toList();
    
    // 1. Apply date filter and dummy absent records if a specific date is selected
    if (filters.selectedDate != null) {
      final d = filters.selectedDate!;
      
      filtered = filtered.where((r) {
        final rec = r.timestamp;
        return rec.year == d.year && rec.month == d.month && rec.day == d.day;
      }).toList();

      if (employeesAsync.value != null) {
        final activeEmployees = employeesAsync.value!.where((e) => e.isActive).toList();
        
        for (final emp in activeEmployees) {
          final hasCheckedIn = filtered.any((r) => 
              (r.type.isMember && r.userName == emp.name) ||
              (r.type.isSubstitute && r.substituteForMember == emp.name) ||
              (r.type.isAbsent && r.userName == emp.name));
              
          if (!hasCheckedIn) {
            filtered.add(
              CheckInSubmission(
                id: 'absent_${emp.id}_${d.millisecondsSinceEpoch}',
                locationId: '',
                locationName: '—',
                userName: emp.name,
                userPhone: emp.phone,
                type: CheckInType.absent,
                userLatitude: 0,
                userLongitude: 0,
                gpsAccuracy: 0,
                distanceMeters: 0,
                timestamp: DateTime(d.year, d.month, d.day, 12, 0),
                isVerified: true,
              ),
            );
          }
        }
      }
    }
    return filtered;
  });
});


class _FilterPayload {
  final List<CheckInSubmission> records;
  final AdminDashboardFilterState filters;
  _FilterPayload(this.records, this.filters);
}

List<CheckInSubmission> _filterAndSortRecords(_FilterPayload payload) {
  final records = payload.records;
  final filters = payload.filters;

  return records.where((record) {
    if (record.type.isVisitor) return false;
    if (filters.filterType == AdminFilterType.member && !record.type.isMember) return false;
    if (filters.filterType == AdminFilterType.substitute && !record.type.isSubstitute) return false;
    if (filters.filterType == AdminFilterType.absent && !record.type.isAbsent) return false;
    if (filters.selectedLocationId != null && filters.selectedLocationId!.isNotEmpty && record.locationId != filters.selectedLocationId) return false;
    if (filters.searchQuery.isNotEmpty) {
      final query = filters.searchQuery.toLowerCase();
      final matchesName = record.userName.toLowerCase().contains(query);
      final matchesPhone = record.userPhone.toLowerCase().contains(query);
      if (!matchesName && !matchesPhone) return false;
    }
    return true;
  }).toList()
    ..sort((a, b) {
      final aTime = a.createdAt ?? a.timestamp;
      final bTime = b.createdAt ?? b.timestamp;
      final cmp = bTime.compareTo(aTime);
      if (cmp != 0) return cmp;
      return b.timestamp.compareTo(a.timestamp);
    });
}

/// Filtered view over the real-time check-in stream based on search and attendance type filters.
final filteredCheckInsProvider =
    FutureProvider<List<CheckInSubmission>>((ref) async {
  final baseRecordsAsync = ref.watch(baseDashboardRecordsProvider);
  if (baseRecordsAsync.isLoading) return [];
  if (baseRecordsAsync.hasError) throw baseRecordsAsync.error!;
  
  final records = baseRecordsAsync.value ?? [];
  final filters = ref.watch(adminDashboardFilterProvider);

  return await compute(_filterAndSortRecords, _FilterPayload(records, filters));
});

