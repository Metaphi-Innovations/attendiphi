import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../domain/substitutes_analytics.dart';

/// Visit history table: Date | Time | Member covered.
class SubstituteVisitTable extends StatelessWidget {
  const SubstituteVisitTable({super.key, required this.visits});

  final List<SubstituteVisitRecord> visits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);
    final headerBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    final sorted = List<SubstituteVisitRecord>.from(visits)
      ..sort((a, b) => b.attendedAt.compareTo(a.attendedAt));

    Widget headerCell(String label, {int flex = 1}) {
      return Expanded(
        flex: flex,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    Widget bodyCell(String text, {int flex = 1, FontWeight? weight}) {
      return Expanded(
        flex: flex,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: weight ?? FontWeight.w500,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: headerBg,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                headerCell('Date', flex: 2),
                headerCell('Time', flex: 2),
                headerCell('Member covered', flex: 4),
              ],
            ),
          ),
          for (var i = 0; i < sorted.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: borderColor.withAlpha(160),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  bodyCell(dateFmt.format(sorted[i].attendedAt), flex: 2),
                  bodyCell(timeFmt.format(sorted[i].attendedAt), flex: 2),
                  bodyCell(
                    sorted[i].coveredMemberDisplayName,
                    flex: 4,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact stacked visit list for narrow widths.
class SubstituteVisitListMobile extends StatelessWidget {
  const SubstituteVisitListMobile({super.key, required this.visits});

  final List<SubstituteVisitRecord> visits;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFmt = DateFormat('dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE2E8F0);

    final sorted = List<SubstituteVisitRecord>.from(visits)
      ..sort((a, b) => b.attendedAt.compareTo(a.attendedAt));

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++) ...[
          if (i > 0) Divider(height: 1, color: borderColor.withAlpha(120)),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sorted[i].coveredMemberDisplayName,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${dateFmt.format(sorted[i].attendedAt)} · '
                  '${timeFmt.format(sorted[i].attendedAt)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
