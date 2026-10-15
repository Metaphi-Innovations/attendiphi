import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_colors.dart';

/// Shows the searchable Thursday session date dropdown anchored right beneath the target button.
Future<void> showSearchableThursdayDateDropdown({
  required BuildContext context,
  required bool isDark,
  required DateTime? selectedDate,
  required List<DateTime> allThursdays,
  required ValueChanged<DateTime?> onDateSelected,
}) async {
  final renderBox = context.findRenderObject() as RenderBox?;
  final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;
  final size = renderBox?.size ?? Size.zero;
  final mediaQuery = MediaQuery.of(context);
  final screenSize = mediaQuery.size;

  final dropdownWidth = screenSize.width < 372
      ? (screenSize.width - 32)
      : 340.0;
  const dropdownHeight = 380.0;

  // Horizontal alignment: Align with left of button, but if it overflows screen right edge, align with right of button
  double left = offset.dx;
  if (left + dropdownWidth > screenSize.width - 16) {
    left = (offset.dx + size.width) - dropdownWidth;
  }
  if (left < 16) {
    left = 16;
  }

  // Vertical alignment: Dropdown appears right below the button; if not enough space below, show above
  double top = offset.dy + size.height + 6;
  if (top + dropdownHeight > screenSize.height - 16 &&
      offset.dy > dropdownHeight + 16) {
    top = offset.dy - dropdownHeight - 6;
  }

  await showDialog<void>(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (dialogCtx) {
      return Stack(
        children: [
          // Tap anywhere outside to dismiss
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => Navigator.of(dialogCtx).pop(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              type: MaterialType.transparency,
              child: SizedBox(
                width: dropdownWidth,
                height: dropdownHeight,
                child: SearchableThursdayDateDialog(
                  isDark: isDark,
                  selectedDate: selectedDate,
                  allThursdays: allThursdays,
                  onDateSelected: onDateSelected,
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Compact, searchable dropdown container for Thursday session dates.
class SearchableThursdayDateDialog extends StatefulWidget {
  const SearchableThursdayDateDialog({
    super.key,
    required this.isDark,
    required this.selectedDate,
    required this.allThursdays,
    required this.onDateSelected,
  });

  final bool isDark;
  final DateTime? selectedDate;
  final List<DateTime> allThursdays;
  final ValueChanged<DateTime?> onDateSelected;

  @override
  State<SearchableThursdayDateDialog> createState() =>
      _SearchableThursdayDateDialogState();
}

class _SearchableThursdayDateDialogState
    extends State<SearchableThursdayDateDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final query = _searchQuery.trim().toLowerCase();

    final filteredList = widget.allThursdays.where((date) {
      if (query.isEmpty) return true;
      final fullText = DateFormat('EEEE, dd MMM yyyy')
          .format(date)
          .toLowerCase();
      final shortText = DateFormat('dd MMM yyyy').format(date).toLowerCase();
      final numeric = DateFormat('dd/MM/yyyy').format(date).toLowerCase();
      return fullText.contains(query) ||
          shortText.contains(query) ||
          numeric.contains(query);
    }).toList();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 90 : 35),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Select Thursday Session',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      splashRadius: 16,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      color: isDark ? Colors.white60 : Colors.black45,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search Box
                TextField(
                  controller: _searchController,
                  autofocus: false,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search date, month, or year...',
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF64748B)
                          : const Color(0xFF94A3B8),
                    ),
                    prefixIcon: const Icon(Icons.search_rounded, size: 17),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 15),
                            splashRadius: 14,
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    isDense: true,
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                      borderSide: BorderSide(
                        color: AppColors.primary,
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Scrollable List of Dates
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                if (filteredList.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No matching dates found',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? const Color(0xFF64748B)
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  )
                else
                  ...filteredList.map((d) {
                    final isSel =
                        widget.selectedDate != null &&
                        widget.selectedDate!.year == d.year &&
                        widget.selectedDate!.month == d.month &&
                        widget.selectedDate!.day == d.day;
                    final label = DateFormat('EEEE, dd MMM yyyy').format(d);
                    return _buildOption(
                      context,
                      isDark: isDark,
                      label: label,
                      isSelected: isSel,
                      icon: Icons.calendar_today_outlined,
                      onTap: () {
                        widget.onDateSelected(d);
                        Navigator.of(context).pop();
                      },
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required bool isDark,
    required String label,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        color: isSelected
            ? AppColors.primary.withAlpha(isDark ? 45 : 20)
            : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? AppColors.primary
                  : (isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                            ? const Color(0xFFE2E8F0)
                            : const Color(0xFF1E293B)),
                ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}
