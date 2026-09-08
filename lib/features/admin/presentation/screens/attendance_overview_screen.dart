import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_badge.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../providers/attendance_overview_provider.dart';

/// Comprehensive Attendance Overview Matrix screen showing all members across
/// all meeting Thursdays from September 2026 to September 2027.
class AttendanceOverviewScreen extends ConsumerStatefulWidget {
  const AttendanceOverviewScreen({super.key});

  @override
  ConsumerState<AttendanceOverviewScreen> createState() =>
      _AttendanceOverviewScreenState();
}

class _AttendanceOverviewScreenState
    extends ConsumerState<AttendanceOverviewScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void dispose() {
    _searchController.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  void _showCellDetailsDialog(
    BuildContext context,
    MemberAttendanceRow row,
    DateTime date,
    MemberDayAttendance attendance,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final formattedDate = DateFormat('EEEE, dd MMMM yyyy').format(date);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.event_note_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.member.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(),
              const SizedBox(height: 8),
              _buildDetailRow(
                'Attendance Status',
                _getStatusBadgeWidget(attendance.status),
              ),
              const SizedBox(height: 12),
              if (attendance.substituteName != null) ...[
                _buildDetailRow(
                  'Substitute Attendee',
                  Text(
                    attendance.substituteName!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (attendance.submission != null) ...[
                _buildDetailRow(
                  'Recorded Time',
                  Text(
                    DateFormat('dd MMM yyyy, hh:mm a')
                        .format(attendance.submission!.timestamp),
                    style: TextStyle(
                      color: attendance.submission!.isEdited
                          ? const Color(0xFFD97706)
                          : null,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (attendance.submission!.isEdited) ...[
                  _buildDetailRow(
                    'Admin Edited',
                    const AppBadge(
                      label: 'Edited by Admin',
                      variant: AppBadgeVariant.warning,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildDetailRow(
                  'GPS Verification',
                  attendance.submission!.type.isAbsent
                      ? const Text('—')
                      : Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 14,
                              color: Color(0xFF10B981),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${attendance.submission!.distanceMeters.toStringAsFixed(1)}m from venue',
                              style: const TextStyle(
                                color: Color(0xFF10B981),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                ),
              ] else if (attendance.status.isAbsent) ...[
                Text(
                  'No check-in submission was recorded for this member on this date.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ] else if (attendance.status.isUpcoming) ...[
                Text(
                  'This meeting is scheduled for a future date.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, Widget valueWidget) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
        valueWidget,
      ],
    );
  }

  Widget _getStatusBadgeWidget(MemberAttendanceStatus status) {
    switch (status) {
      case MemberAttendanceStatus.present:
        return const AppBadge(
          label: 'Present (M)',
          variant: AppBadgeVariant.success,
        );
      case MemberAttendanceStatus.substitute:
        return const AppBadge(
          label: 'Substitute (S)',
          variant: AppBadgeVariant.warning,
        );
      case MemberAttendanceStatus.absent:
        return const AppBadge(
          label: 'Absent (-)',
          variant: AppBadgeVariant.error,
        );
      case MemberAttendanceStatus.upcoming:
        return const AppBadge(
          label: 'Upcoming',
          variant: AppBadgeVariant.neutral,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = context.isMobile;

    final matrixAsync = ref.watch(attendanceMatrixProvider);
    final allThursdays = ref.watch(allThursdayDatesProvider);
    final meetingMonths = ref.watch(meetingMonthsProvider);
    final filterState = ref.watch(attendanceOverviewFilterProvider);

    // Visible Thursdays based on month filter
    final visibleThursdays = allThursdays.where((d) {
      if (filterState.selectedMonth == null) return true;
      final selectedMonth = filterState.selectedMonth!;
      return d.year == selectedMonth.year && d.month == selectedMonth.month;
    }).toList();

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 12 : 20,
          isMobile ? 16 : 24,
          isMobile ? 80 : 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Fixed Header Section (Desktop/Tablet only; on mobile Shell AppBar shows screen title)
            if (!isMobile) ...[
              const AppPageHeader(
                title: 'Attendance Overview',
                subtitle:
                    'All members attendance matrix across all Thursdays (Sep 2026 – Sep 2027)',
              ),
              const SizedBox(height: 12),
            ],

            // 2. Fixed Filters & Legend Toolbar
            _buildToolbar(
              context,
              theme,
              isDark,
              filterState,
              meetingMonths,
              visibleThursdays.length,
            ),
            const SizedBox(height: 12),

            // 3. ONLY Data Matrix Grid is Scrollable!
            Expanded(
              child: matrixAsync.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return AppCard(
                      child: AppEmptyView(
                        icon: Icons.search_off_rounded,
                        message: filterState.searchQuery.isNotEmpty
                            ? 'No members match "${filterState.searchQuery}".'
                            : 'No members registered yet.',
                        actionLabel: filterState.searchQuery.isNotEmpty
                            ? 'Clear Search'
                            : null,
                        action: () {
                          _searchController.clear();
                          ref
                              .read(attendanceOverviewFilterProvider.notifier)
                              .resetFilters();
                        },
                      ),
                    );
                  }

                  return _buildMatrixTable(
                    context,
                    theme,
                    isDark,
                    rows,
                    visibleThursdays,
                  );
                },
                loading: () => const AppCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: 24.0,
                        horizontal: 16.0,
                      ),
                      child: MetaPhiLoadingIndicator(
                        showCard: false,
                      ),
                    ),
                  ),
                ),
                error: (err, _) => AppCard(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text('Error loading attendance matrix: $err'),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    AttendanceOverviewFilterState filterState,
    List<DateTime> meetingMonths,
    int visibleDatesCount,
  ) {
    final isMobile = context.isMobile;

    final searchInput = SizedBox(
      width: isMobile ? double.infinity : 240,
      height: 40,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search member...',
          hintStyle: TextStyle(
            fontSize: 13,
            color: isDark
                ? const Color(0xFF64748B)
                : const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(Icons.search, size: 18),
          suffixIcon: filterState.searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () {
                    _searchController.clear();
                    ref
                        .read(
                            attendanceOverviewFilterProvider.notifier)
                        .setSearchQuery('');
                  },
                )
              : null,
          filled: true,
          fillColor: isDark
              ? const Color(0xFF0F172A)
              : const Color(0xFFF1F5F9),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
        ),
        style: const TextStyle(fontSize: 13),
        onChanged: (val) {
          ref
              .read(attendanceOverviewFilterProvider.notifier)
              .setSearchQuery(val);
        },
      ),
    );

    final monthDropdown = Container(
      height: 40,
      width: isMobile ? double.infinity : null,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0F172A)
            : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: filterState.selectedMonth != null
              ? AppColors.primary
              : Colors.transparent,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<DateTime?>(
          value: filterState.selectedMonth,
          isExpanded: isMobile,
          hint: Text(
            'All Months ($visibleDatesCount Thursdays)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded),
          dropdownColor:
              isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          items: [
            const DropdownMenuItem<DateTime?>(
              value: null,
              child: Text(
                'All Months (57 Thursdays)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...meetingMonths.map((m) {
              return DropdownMenuItem<DateTime?>(
                value: m,
                child: Text(
                  DateFormat('MMMM yyyy').format(m),
                  style: const TextStyle(fontSize: 13),
                ),
              );
            }),
          ],
          onChanged: (val) {
            ref
                .read(attendanceOverviewFilterProvider.notifier)
                .setSelectedMonth(val);
          },
        ),
      ),
    );

    final legendItems = [
      _buildLegendItem(
        label: 'Present (M)',
        color: const Color(0xFF10B981),
        isDark: isDark,
      ),
      _buildLegendItem(
        label: 'Substitute (S)',
        color: const Color(0xFFF59E0B),
        isDark: isDark,
      ),
      _buildLegendItem(
        label: 'Absent (-)',
        color: const Color(0xFFEF4444),
        isDark: isDark,
      ),
      _buildLegendItem(
        label: 'Upcoming',
        color: const Color(0xFF94A3B8),
        isDark: isDark,
      ),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: AppRadius.lgAll,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : const Color(0xFFE2E8F0),
        ),
        boxShadow: AppShadows.sm,
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchInput,
                const SizedBox(height: 8),
                monthDropdown,
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: legendItems,
                ),
              ],
            )
          : Wrap(
              spacing: 16,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    searchInput,
                    const SizedBox(width: 12),
                    monthDropdown,
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (int i = 0; i < legendItems.length; i++) ...[
                      if (i > 0) const SizedBox(width: 12),
                      legendItems[i],
                    ],
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildLegendItem({
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  Widget _buildMatrixTable(
    BuildContext context,
    ThemeData theme,
    bool isDark,
    List<MemberAttendanceRow> rows,
    List<DateTime> thursdays,
  ) {
    const double memberColumnWidth = 220.0;
    const double dateColumnWidth = 72.0;
    const double summaryColumnWidth = 58.0;
    const double rateColumnWidth = 84.0;
    const double rowHeight = 54.0;
    const double headerHeight = 52.0;

    final borderColor =
        isDark ? AppColors.outlineDark : const Color(0xFFE2E8F0);

    final double totalTableWidth = memberColumnWidth +
        (thursdays.length * dateColumnWidth) +
        (3 * summaryColumnWidth) +
        rateColumnWidth;

    final isMobile = MediaQuery.of(context).size.width < 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isMobile)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.swipe_rounded,
                  size: 13,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
                const SizedBox(width: 4),
                Text(
                  'Swipe table horizontally to view all meeting dates',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : Colors.white,
              borderRadius: AppRadius.lgAll,
              border: Border.all(color: borderColor),
              boxShadow: AppShadows.sm,
            ),
            clipBehavior: Clip.antiAlias,
            child: Scrollbar(
              controller: _horizontalScrollController,
              thumbVisibility: true,
              child: ShaderMask(
                shaderCallback: (Rect bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.94, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: SingleChildScrollView(
                  controller: _horizontalScrollController,
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: totalTableWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                // 1. Sticky Header Row (MEMBER & all dates - pinned at top, does NOT scroll vertically)
                Container(
                  height: headerHeight,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    border: Border(
                      bottom: BorderSide(color: borderColor, width: 1.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      // 1st Column: Member Name
                      Container(
                        width: memberColumnWidth,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'MEMBER (${rows.length})',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                            letterSpacing: 0.5,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF475569),
                          ),
                        ),
                      ),

                      // Date Columns
                      ...thursdays.map((date) {
                        final isCurrentWeek =
                            DateTime.now().difference(date).inDays.abs() < 4;
                        return Container(
                          width: dateColumnWidth,
                          decoration: BoxDecoration(
                            color: isCurrentWeek
                                ? AppColors.primary.withAlpha(20)
                                : null,
                            border: Border(
                              left: BorderSide(
                                color: borderColor.withAlpha(80),
                              ),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                DateFormat('dd MMM').format(date),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: isCurrentWeek
                                      ? AppColors.primary
                                      : (isDark
                                          ? Colors.white
                                          : const Color(0xFF0F172A)),
                                ),
                              ),
                              Text(
                                DateFormat('yyyy').format(date),
                                style: TextStyle(
                                  fontSize: 9,
                                  color: isDark
                                      ? const Color(0xFF64748B)
                                      : const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      // Summary Columns
                      _buildSummaryHeader(
                        'P',
                        summaryColumnWidth,
                        const Color(0xFF10B981),
                        borderColor,
                      ),
                      _buildSummaryHeader(
                        'S',
                        summaryColumnWidth,
                        const Color(0xFFF59E0B),
                        borderColor,
                      ),
                      _buildSummaryHeader(
                        'A',
                        summaryColumnWidth,
                        const Color(0xFFEF4444),
                        borderColor,
                      ),
                      _buildSummaryHeader(
                        'RATE',
                        rateColumnWidth,
                        AppColors.primary,
                        borderColor,
                      ),
                    ],
                  ),
                ),

                // 2. ONLY Member Data Rows are vertically scrollable
                Expanded(
                  child: Scrollbar(
                    controller: _verticalScrollController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _verticalScrollController,
                      scrollDirection: Axis.vertical,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...rows.asMap().entries.map((entry) {
                            final index = entry.key;
                            final row = entry.value;
                            final isEven = index % 2 == 0;
                            final rowBg = isEven
                                ? Colors.transparent
                                : (isDark
                                    ? const Color(0xFF1E293B).withAlpha(50)
                                    : const Color(0xFFF8FAFC));

                            return Container(
                              height: rowHeight,
                              decoration: BoxDecoration(
                                color: rowBg,
                                border: Border(
                                  bottom: BorderSide(
                                    color: borderColor.withAlpha(60),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  // Member Name Column
                                  Container(
                                    width: memberColumnWidth,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    child: Row(
                                      children: [
                                        // Avatar circle
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: AppColors.primary
                                                .withAlpha(25),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              row.member.name.isNotEmpty
                                                  ? row.member.name[0]
                                                      .toUpperCase()
                                                  : 'M',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12,
                                                color: AppColors.primary,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Text(
                                                row.member.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 13,
                                                  color: isDark
                                                      ? Colors.white
                                                      : const Color(0xFF0F172A),
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              if (row.member.phone.isNotEmpty)
                                                Text(
                                                  row.member.phone,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: isDark
                                                        ? const Color(0xFF64748B)
                                                        : const Color(0xFF94A3B8),
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Date Cells
                                  ...thursdays.map((date) {
                                    final attendance =
                                        row.getAttendanceForDate(date);
                                    return Container(
                                      width: dateColumnWidth,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          left: BorderSide(
                                            color: borderColor.withAlpha(60),
                                          ),
                                        ),
                                      ),
                                      alignment: Alignment.center,
                                      child: _buildMatrixCellBadge(
                                        context,
                                        row,
                                        date,
                                        attendance,
                                        isDark,
                                      ),
                                    );
                                  }),

                                  // Summary Data Cells
                                  _buildSummaryCell(
                                    '${row.presentCount}',
                                    summaryColumnWidth,
                                    const Color(0xFF10B981),
                                    borderColor,
                                    isDark,
                                  ),
                                  _buildSummaryCell(
                                    '${row.substituteCount}',
                                    summaryColumnWidth,
                                    const Color(0xFFF59E0B),
                                    borderColor,
                                    isDark,
                                  ),
                                  _buildSummaryCell(
                                    '${row.absentCount}',
                                    summaryColumnWidth,
                                    const Color(0xFFEF4444),
                                    borderColor,
                                    isDark,
                                  ),
                                  _buildRateCell(
                                    row.attendanceRate,
                                    rateColumnWidth,
                                    borderColor,
                                    isDark,
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  ),
),
],
);
}

  Widget _buildSummaryHeader(
    String title,
    double width,
    Color color,
    Color borderColor,
  ) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor, width: 1.5)),
      ),
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: 11,
          color: color,
        ),
      ),
    );
  }

  Widget _buildSummaryCell(
    String text,
    double width,
    Color color,
    Color borderColor,
    bool isDark,
  ) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor.withAlpha(60))),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          color: color,
        ),
      ),
    );
  }

  Widget _buildRateCell(
    double rate,
    double width,
    Color borderColor,
    bool isDark,
  ) {
    final rateColor = rate >= 75
        ? const Color(0xFF10B981)
        : (rate >= 50 ? const Color(0xFFF59E0B) : const Color(0xFFEF4444));

    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: borderColor.withAlpha(60))),
      ),
      alignment: Alignment.center,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: rateColor.withAlpha(isDark ? 40 : 25),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '${rate.toStringAsFixed(0)}%',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 11,
            color: rateColor,
          ),
        ),
      ),
    );
  }

  Widget _buildMatrixCellBadge(
    BuildContext context,
    MemberAttendanceRow row,
    DateTime date,
    MemberDayAttendance attendance,
    bool isDark,
  ) {
    Color bg;
    Color fg;
    String label;

    switch (attendance.status) {
      case MemberAttendanceStatus.present:
        bg = isDark
            ? const Color(0xFF065F46).withAlpha(120)
            : const Color(0xFFD1FAE5);
        fg = isDark ? const Color(0xFF34D399) : const Color(0xFF047857);
        label = 'M';
        break;

      case MemberAttendanceStatus.substitute:
        bg = isDark
            ? const Color(0xFF78350F).withAlpha(120)
            : const Color(0xFFFEF3C7);
        fg = isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309);
        label = 'S';
        break;

      case MemberAttendanceStatus.absent:
        bg = isDark
            ? const Color(0xFF7F1D1D).withAlpha(80)
            : const Color(0xFFFEE2E2);
        fg = isDark ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
        label = '-';
        break;

      case MemberAttendanceStatus.upcoming:
        bg = Colors.transparent;
        fg = isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1);
        label = '·';
        break;
    }

    // Touch Target Accessibility:
    // The InkWell wraps the full 72x54pt table cell area, providing a comfortable
    // tap target exceeding the minimum 44x44pt requirement for interactive matrix cells,
    // while centering the crisp 32x28 visual indicator badge.
    return Tooltip(
      message: attendance.status == MemberAttendanceStatus.substitute
          ? 'Substitute: ${attendance.substituteName ?? "Guest"}'
          : attendance.status.label,
      child: InkWell(
        onTap: () => _showCellDetailsDialog(context, row, date, attendance),
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 72.0,
          height: 54.0,
          child: Center(
            child: Container(
              width: 32,
              height: 28,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(6),
                border: attendance.status.isUpcoming
                    ? Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        style: BorderStyle.solid,
                      )
                    : null,
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
