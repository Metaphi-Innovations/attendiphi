import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../core/responsive/responsive_breakpoints.dart';
import '../../../domain/substitutes_analytics.dart';
import 'substitute_metric_card.dart';

/// Metrics-only strip for Substitute Details (identity lives in the header).
class SubstituteProfileSummary extends StatelessWidget {
  const SubstituteProfileSummary({super.key, required this.profile});

  final SubstituteProfile profile;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd MMM yyyy');
    final first = profile.firstAttendance;
    final latest = profile.lastAttendance;

    final metrics = [
      SubstituteMetricCard(
        label: 'Total Visits',
        value: '${profile.totalVisits}',
        icon: Icons.event_available_rounded,
        accent: AppColors.primary,
      ),
      SubstituteMetricCard(
        label: 'Members Covered',
        value: '${profile.uniqueMembersCovered}',
        icon: Icons.groups_rounded,
        accent: AppColors.info,
      ),
      SubstituteMetricCard(
        label: 'First Visit',
        value: first == null ? '—' : dateFmt.format(first),
        icon: Icons.flag_outlined,
        accent: AppColors.success,
      ),
      SubstituteMetricCard(
        label: 'Latest Visit',
        value: latest == null ? '—' : dateFmt.format(latest),
        icon: Icons.schedule_rounded,
        accent: AppColors.warning,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final tablet = constraints.maxWidth >= ResponsiveBreakpoints.mobile;

        if (wide) {
          return Row(
            children: [
              for (var i = 0; i < metrics.length; i++) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(child: metrics[i]),
              ],
            ],
          );
        }

        return GridView.count(
          crossAxisCount: tablet ? 2 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: tablet ? 3.1 : 2.4,
          children: metrics,
        );
      },
    );
  }
}
