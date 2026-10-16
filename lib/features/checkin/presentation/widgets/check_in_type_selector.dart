import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../domain/entities/check_in_type.dart';

/// UI tabs on the public check-in form (includes Face Verification).
///
/// Face Verification still submits as [CheckInType.member] after a match.
enum CheckInFormTab {
  member,
  substitute,
  visitor,
  faceVerification,
}

extension CheckInFormTabX on CheckInFormTab {
  /// Persisted check-in type used on submit.
  CheckInType get checkInType => switch (this) {
    CheckInFormTab.member || CheckInFormTab.faceVerification =>
      CheckInType.member,
    CheckInFormTab.substitute => CheckInType.substitute,
    CheckInFormTab.visitor => CheckInType.visitor,
  };

  static CheckInFormTab fromCheckInType(CheckInType? type) {
    return switch (type) {
      CheckInType.substitute => CheckInFormTab.substitute,
      CheckInType.visitor => CheckInFormTab.visitor,
      _ => CheckInFormTab.member,
    };
  }
}

class CheckInTypeSelector extends StatelessWidget {
  const CheckInTypeSelector({
    super.key,
    required this.selectedTab,
    required this.onChanged,
  });

  final CheckInFormTab? selectedTab;
  final ValueChanged<CheckInFormTab> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildTypeCard(
            tab: CheckInFormTab.member,
            title: 'Member',
            icon: Icons.person_rounded,
            isSelected: selectedTab == CheckInFormTab.member,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildTypeCard(
            tab: CheckInFormTab.substitute,
            title: 'Substitute',
            icon: Icons.swap_horiz_rounded,
            isSelected: selectedTab == CheckInFormTab.substitute,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildTypeCard(
            tab: CheckInFormTab.visitor,
            title: 'Visitor',
            icon: Icons.card_membership_rounded,
            isSelected: selectedTab == CheckInFormTab.visitor,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _buildTypeCard(
            tab: CheckInFormTab.faceVerification,
            title: 'Face',
            icon: Icons.face_retouching_natural_rounded,
            isSelected: selectedTab == CheckInFormTab.faceVerification,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required CheckInFormTab tab,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    const activeColor = AppColors.primary;
    const activeBgColor = Color(0xFFFEF2F2);

    return InkWell(
      onTap: () => onChanged(tab),
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
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
              size: 18,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF475569),
                fontSize: 11,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
