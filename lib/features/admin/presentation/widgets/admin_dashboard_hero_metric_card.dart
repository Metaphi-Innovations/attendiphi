import 'package:flutter/material.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/widgets/app_card.dart';

/// KPI metric card for the admin daily attendance dashboard.
class AdminDashboardHeroMetricCard extends StatelessWidget {
  const AdminDashboardHeroMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accentColor,
    this.isMobile = false,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accentColor;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AppCard(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 14,
        vertical: isMobile ? 8 : 10,
      ),
      borderRadius: AppRadius.mdAll,
      shadows: AppShadows.sm,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? const Color(0xFF94A3B8)
                        : const Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            width: isMobile ? 34 : 36,
            height: isMobile ? 34 : 36,
            decoration: BoxDecoration(
              color: accentColor.withAlpha(isDark ? 35 : 20),
              borderRadius: AppRadius.mdAll,
            ),
            child: Center(
              child: Icon(icon, color: accentColor, size: isMobile ? 16 : 18),
            ),
          ),
        ],
      ),
    );
  }
}
