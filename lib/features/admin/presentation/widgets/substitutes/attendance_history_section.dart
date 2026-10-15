import 'package:flutter/material.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../domain/substitutes_analytics.dart';
import 'attendance_history_filters.dart';
import 'member_attendance_card.dart';

/// Attendance history for one substitute: filters + expandable member cards.
class AttendanceHistorySection extends StatelessWidget {
  const AttendanceHistorySection({
    super.key,
    required this.groups,
    required this.totalVisits,
    required this.uniqueMembers,
    required this.expandedKeys,
    required this.onToggleExpanded,
    required this.searchQuery,
    required this.rangeStart,
    required this.rangeEnd,
    required this.sort,
    required this.onSearchChanged,
    required this.onRangeChanged,
    required this.onSortChanged,
    required this.onClearFilters,
    required this.hasActiveFilters,
  });

  final List<SubstituteMemberGroup> groups;
  final int totalVisits;
  final int uniqueMembers;
  final Set<String> expandedKeys;
  final ValueChanged<String> onToggleExpanded;
  final String searchQuery;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final AttendanceHistorySort sort;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final ValueChanged<AttendanceHistorySort> onSortChanged;
  final VoidCallback onClearFilters;
  final bool hasActiveFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final newestFirst = sort == AttendanceHistorySort.newestFirst;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attendance History',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'View every member represented by this substitute.',
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$totalVisits ${totalVisits == 1 ? 'visit' : 'visits'} · '
          '$uniqueMembers ${uniqueMembers == 1 ? 'member' : 'members'}',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
        const SizedBox(height: 12),
        AttendanceHistoryFilters(
          searchQuery: searchQuery,
          rangeStart: rangeStart,
          rangeEnd: rangeEnd,
          sort: sort,
          resultCount: groups.length,
          onSearchChanged: onSearchChanged,
          onRangeChanged: onRangeChanged,
          onSortChanged: onSortChanged,
          onClear: onClearFilters,
        ),
        const SizedBox(height: 12),
        if (groups.isEmpty)
          _EmptyHistory(hasFilters: hasActiveFilters)
        else
          ...groups.map(
            (group) => Padding(
              key: ValueKey('member-${group.memberKey}'),
              padding: const EdgeInsets.only(bottom: 10),
              child: MemberAttendanceCard(
                group: group,
                expanded: expandedKeys.contains(group.memberKey),
                newestFirst: newestFirst,
                onToggle: () => onToggleExpanded(group.memberKey),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(isDark ? 40 : 22),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFilters
                  ? Icons.filter_alt_off_rounded
                  : Icons.event_busy_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            hasFilters
                ? 'No records match these filters.'
                : 'No substitute attendance recorded yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try adjusting search, date range, or sort options.'
                : 'Attendance records will appear here after a verified '
                      'substitute check-in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
