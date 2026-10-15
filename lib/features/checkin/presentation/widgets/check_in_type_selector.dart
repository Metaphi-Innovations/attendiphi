import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../domain/entities/check_in_type.dart';

class CheckInTypeSelector extends StatelessWidget {
  const CheckInTypeSelector({
    super.key,
    required this.selectedType,
    required this.onChanged,
  });

  final CheckInType? selectedType;
  final ValueChanged<CheckInType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Member Option
        Expanded(
          child: _buildTypeCard(
            type: CheckInType.member,
            title: 'Member',
            icon: Icons.person_rounded,
            isSelected: selectedType == CheckInType.member,
          ),
        ),

        const SizedBox(width: 8),

        // 2. Substitute Option
        Expanded(
          child: _buildTypeCard(
            type: CheckInType.substitute,
            title: 'Substitute',
            icon: Icons.swap_horiz_rounded,
            isSelected: selectedType == CheckInType.substitute,
          ),
        ),

        const SizedBox(width: 8),

        // 3. Visitor Option
        Expanded(
          child: _buildTypeCard(
            type: CheckInType.visitor,
            title: 'Visitor',
            icon: Icons.card_membership_rounded,
            isSelected: selectedType == CheckInType.visitor,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required CheckInType type,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    const activeColor = AppColors.primary;
    const activeBgColor = Color(0xFFFEF2F2);

    return InkWell(
      onTap: () => onChanged(type),
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : icon,
              size: 20,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF475569),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Substitute photo verification card.
