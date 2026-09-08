import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';

/// Standardized SaaS Filter Dropdown component for toolbar controls.
class AppFilterDropdown<T> extends StatelessWidget {
  const AppFilterDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.labelPrefix,
    this.hintText,
    this.isExpanded = false,
    this.isCompact = false,
  });

  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final String? labelPrefix;
  final String? hintText;
  final bool isExpanded;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: isCompact ? 36 : 40,
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 10 : 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        borderRadius: AppRadius.mdAll,
        border: Border.all(
          color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          width: 1,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: isExpanded,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: isCompact ? 18 : 20,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: AppRadius.mdAll,
          elevation: 3,
          style: TextStyle(
            fontSize: isCompact ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          hint: hintText != null
              ? Text(
                  hintText!,
                  style: TextStyle(
                    fontSize: isCompact ? 12 : 13,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                )
              : null,
          items: items.map((item) {
            final childWidget = item.child;
            if (labelPrefix != null && childWidget is Text) {
              return DropdownMenuItem<T>(
                value: item.value,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$labelPrefix: ',
                      style: TextStyle(
                        fontSize: isCompact ? 11.5 : 12.5,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        childWidget.data ?? '',
                        style: TextStyle(
                          fontSize: isCompact ? 12 : 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF0F172A),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            }
            return item;
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
