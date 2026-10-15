import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radius.dart';

enum AttendanceHistorySort {
  newestFirst('Newest first'),
  oldestFirst('Oldest first');

  const AttendanceHistorySort(this.label);
  final String label;
}

/// Compact toolbar for filtering a single substitute's attendance history.
class AttendanceHistoryFilters extends StatefulWidget {
  const AttendanceHistoryFilters({
    super.key,
    required this.searchQuery,
    required this.rangeStart,
    required this.rangeEnd,
    required this.sort,
    required this.resultCount,
    required this.onSearchChanged,
    required this.onRangeChanged,
    required this.onSortChanged,
    required this.onClear,
  });

  final String searchQuery;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final AttendanceHistorySort sort;
  final int resultCount;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTimeRange?> onRangeChanged;
  final ValueChanged<AttendanceHistorySort> onSortChanged;
  final VoidCallback onClear;

  @override
  State<AttendanceHistoryFilters> createState() =>
      _AttendanceHistoryFiltersState();
}

class _AttendanceHistoryFiltersState extends State<AttendanceHistoryFilters> {
  late final TextEditingController _searchController;
  Timer? _debounce;

  bool get _hasActiveFilters =>
      widget.searchQuery.trim().isNotEmpty ||
      widget.rangeStart != null ||
      widget.rangeEnd != null ||
      widget.sort != AttendanceHistorySort.newestFirst;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant AttendanceHistoryFilters oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != _searchController.text &&
        widget.searchQuery != oldWidget.searchQuery) {
      _searchController.text = widget.searchQuery;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchInput(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      widget.onSearchChanged(value);
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initial = widget.rangeStart != null && widget.rangeEnd != null
        ? DateTimeRange(start: widget.rangeStart!, end: widget.rangeEnd!)
        : DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
            end: now,
          );
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initial,
      helpText: 'Filter by attendance date',
    );
    if (picked != null) {
      widget.onRangeChanged(picked);
    }
  }

  InputDecoration _fieldDecoration(bool isDark) {
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFCBD5E1);
    final fill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
    return InputDecoration(
      hintText: 'Search member or ID',
      prefixIcon: const Icon(Icons.search_rounded, size: 18),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      filled: true,
      fillColor: fill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.primary.withAlpha(160)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final rangeLabel = widget.rangeStart != null && widget.rangeEnd != null
        ? '${DateFormat('dd MMM').format(widget.rangeStart!)} – '
              '${DateFormat('dd MMM yyyy').format(widget.rangeEnd!)}'
        : 'Date range';

    final controls = <Widget>[
      ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 180, maxWidth: 280),
        child: SizedBox(
          height: 40,
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchInput,
            decoration: _fieldDecoration(isDark),
            style: const TextStyle(fontSize: 13.5),
          ),
        ),
      ),
      InkWell(
        onTap: _pickRange,
        borderRadius: AppRadius.mdAll,
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: widget.rangeStart != null
                ? AppColors.primary.withAlpha(isDark ? 40 : 20)
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.rangeStart != null
                  ? AppColors.primary.withAlpha(120)
                  : (isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFCBD5E1)),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.date_range_rounded,
                size: 16,
                color: widget.rangeStart != null
                    ? AppColors.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Text(
                rangeLabel,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: widget.rangeStart != null
                      ? AppColors.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
      SizedBox(
        height: 40,
        child: DropdownButtonHideUnderline(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFCBD5E1),
              ),
            ),
            child: DropdownButton<AttendanceHistorySort>(
              value: widget.sort,
              isDense: true,
              borderRadius: AppRadius.mdAll,
              items: AttendanceHistorySort.values
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) widget.onSortChanged(value);
              },
            ),
          ),
        ),
      ),
      if (_hasActiveFilters)
        TextButton.icon(
          onPressed: () {
            _debounce?.cancel();
            _searchController.clear();
            widget.onClear();
          },
          icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
          label: const Text('Clear filters'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            visualDensity: VisualDensity.compact,
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.spaceBetween,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: controls,
            ),
            Text(
              '${widget.resultCount} '
              '${widget.resultCount == 1 ? 'member' : 'members'}',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
