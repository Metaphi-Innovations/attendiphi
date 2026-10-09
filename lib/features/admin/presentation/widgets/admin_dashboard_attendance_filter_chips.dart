import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../providers/admin_dashboard_provider.dart';
import 'admin_dashboard_filter_chip.dart';

/// Attendance roster filter chips (All / Members / Substitutes / Absent).
class AdminDashboardAttendanceFilterChips extends StatelessWidget {
  const AdminDashboardAttendanceFilterChips({
    super.key,
    required this.filterType,
    required this.totalCount,
    required this.memberCount,
    required this.substituteCount,
    required this.absentCount,
    required this.onFilterTypeChanged,
  });

  final AdminFilterType filterType;
  final int totalCount;
  final int memberCount;
  final int substituteCount;
  final int absentCount;
  final ValueChanged<AdminFilterType> onFilterTypeChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminDashboardFilterChip(
          label: 'All ($totalCount)',
          isSelected: filterType == AdminFilterType.all,
          onTap: () => onFilterTypeChanged(AdminFilterType.all),
        ),
        const SizedBox(width: 8),
        AdminDashboardFilterChip(
          label: 'Members ($memberCount)',
          isSelected: filterType == AdminFilterType.member,
          accentColor: AppColors.success,
          onTap: () => onFilterTypeChanged(AdminFilterType.member),
        ),
        const SizedBox(width: 8),
        AdminDashboardFilterChip(
          label: 'Substitutes ($substituteCount)',
          isSelected: filterType == AdminFilterType.substitute,
          accentColor: AppColors.warning,
          onTap: () => onFilterTypeChanged(AdminFilterType.substitute),
        ),
        const SizedBox(width: 8),
        AdminDashboardFilterChip(
          label: 'Absent ($absentCount)',
          isSelected: filterType == AdminFilterType.absent,
          accentColor: AppColors.error,
          onTap: () => onFilterTypeChanged(AdminFilterType.absent),
        ),
      ],
    );
  }
}
