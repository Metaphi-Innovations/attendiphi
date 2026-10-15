import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../../app/theme/app_colors.dart';
import '../../../../../app/theme/app_radius.dart';
import '../../../../../app/theme/app_shadows.dart';
import '../../../../../core/widgets/app_card.dart';
import '../../../../../core/widgets/check_in_photo_image.dart';
import '../../../../checkin/domain/entities/check_in_submission.dart';
import '../../../../checkin/domain/entities/check_in_type.dart';
import '../../../domain/substitutes_analytics.dart';

/// Expandable card for one covered member's substitute visits.
class MemberAttendanceCard extends StatelessWidget {
  const MemberAttendanceCard({
    super.key,
    required this.group,
    required this.expanded,
    required this.onToggle,
    required this.newestFirst,
  });

  final SubstituteMemberGroup group;
  final bool expanded;
  final VoidCallback onToggle;
  final bool newestFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final last = group.visits.isEmpty
        ? null
        : group.visits
              .map((v) => v.attendedAt)
              .reduce((a, b) => a.isAfter(b) ? a : b);
    final visits = List<SubstituteVisitRecord>.from(group.visits)
      ..sort(
        newestFirst
            ? (a, b) => b.attendedAt.compareTo(a.attendedAt)
            : (a, b) => a.attendedAt.compareTo(b.attendedAt),
      );

    final initial = group.memberDisplayName.trim().isNotEmpty
        ? group.memberDisplayName.trim()[0].toUpperCase()
        : '?';

    return AppCard(
      padding: EdgeInsets.zero,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: AppColors.info.withAlpha(
                        isDark ? 45 : 28,
                      ),
                      child: Text(
                        initial,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? const Color(0xFF93C5FD)
                              : AppColors.infoDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.memberDisplayName,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${group.visitCount} '
                            '${group.visitCount == 1 ? 'visit' : 'visits'}'
                            '${last == null ? '' : ' · Last visit: ${DateFormat('dd MMM yyyy').format(last)}'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      expanded ? 'Hide' : 'View history',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary.withAlpha(220),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                children: [
                  Divider(height: 1, color: theme.dividerColor.withAlpha(40)),
                  const SizedBox(height: 10),
                  for (var i = 0; i < visits.length; i++)
                    AttendanceTimelineItem(
                      visit: visits[i],
                      isLast: i == visits.length - 1,
                    ),
                ],
              ),
            ),
            crossFadeState: expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 220),
          ),
        ],
      ),
    );
  }
}

/// Single visit row with a subtle timeline rail.
class AttendanceTimelineItem extends StatelessWidget {
  const AttendanceTimelineItem({
    super.key,
    required this.visit,
    required this.isLast,
  });

  final SubstituteVisitRecord visit;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateFmt = DateFormat('EEE, dd MMM yyyy');
    final timeFmt = DateFormat('hh:mm a');
    final hasPhoto =
        visit.hasPhoto ||
        (visit.photoPath?.trim().isNotEmpty ?? false) ||
        (visit.photoBase64?.trim().isNotEmpty ?? false);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: AppColors.primary.withAlpha(50),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Thumb(
                    visit: visit,
                    onTap: !hasPhoto
                        ? null
                        : () => _showPhoto(context, visit, dateFmt),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFmt.format(visit.attendedAt),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${timeFmt.format(visit.attendedAt)} · For ${visit.coveredMemberDisplayName}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (visit.isVerified)
                              const _StatusPill(
                                label: 'Verified',
                                color: AppColors.success,
                              ),
                            if (visit.isFlagged)
                              const _StatusPill(
                                label: 'Flagged',
                                color: AppColors.error,
                              ),
                            if (!visit.isVerified && !visit.isFlagged)
                              const _StatusPill(
                                label: 'Recorded',
                                color: AppColors.info,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          'ID: ${visit.checkInId}',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurfaceVariant.withAlpha(
                              150,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPhoto(
    BuildContext context,
    SubstituteVisitRecord visit,
    DateFormat dateFmt,
  ) {
    final theme = Theme.of(context);
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: AppRadius.lgAll,
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Attendance photo',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(dialogCtx),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              CheckInPhotoImage(
                submission: _visitAsSubmission(visit),
                width: double.infinity,
                height: 320,
                borderRadius: AppRadius.mdAll,
              ),
              const SizedBox(height: 8),
              Text(dateFmt.format(visit.attendedAt)),
            ],
          ),
        ),
      ),
    );
  }
}

CheckInSubmission _visitAsSubmission(SubstituteVisitRecord visit) {
  return CheckInSubmission(
    id: visit.checkInId,
    locationId: '',
    locationName: visit.locationName ?? '',
    userName: visit.substituteDisplayName,
    userPhone: visit.substitutePhoneDisplay,
    type: CheckInType.substitute,
    userLatitude: 0,
    userLongitude: 0,
    gpsAccuracy: 0,
    distanceMeters: 0,
    timestamp: visit.attendedAt,
    photoBase64: visit.photoBase64,
    photoPath: visit.photoPath,
    hasPhoto: visit.hasPhoto,
  );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.visit, this.onTap});

  final SubstituteVisitRecord visit;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final child = CheckInPhotoImage(
      key: ValueKey('visit-thumb-${visit.checkInId}'),
      submission: _visitAsSubmission(visit),
      width: 44,
      height: 44,
      borderRadius: AppRadius.smAll,
      placeholder: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.warning.withAlpha(30),
          borderRadius: AppRadius.smAll,
        ),
        child: const Icon(
          Icons.person_rounded,
          size: 20,
          color: AppColors.warningDark,
        ),
      ),
    );

    if (onTap == null) return child;
    return InkWell(onTap: onTap, borderRadius: AppRadius.smAll, child: child);
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(isDark ? 40 : 22),
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
