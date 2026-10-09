import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';

/// Selectable filter chip used on the admin daily attendance toolbar.
class AdminDashboardFilterChip extends StatelessWidget {
  const AdminDashboardFilterChip({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveAccent = accentColor ?? AppColors.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.fullAll,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? effectiveAccent.withAlpha(45)
                    : (accentColor != null
                        ? effectiveAccent.withAlpha(25)
                        : const Color(0xFFEEF2FF)))
                : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
            borderRadius: AppRadius.fullAll,
            border: Border.all(
              color: isSelected
                  ? effectiveAccent
                  : (isDark ? AppColors.outlineDark : AppColors.outlineLight),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSelected) ...[
                Icon(
                  Icons.check_rounded,
                  size: 13,
                  color: effectiveAccent,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark
                          ? (accentColor ?? const Color(0xFF818CF8))
                          : effectiveAccent)
                      : (isDark
                          ? AppColors.onSurfaceVariantDark
                          : AppColors.onSurfaceVariantLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
