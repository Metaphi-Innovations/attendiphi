import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/check_in_photo_image.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/domain/entities/check_in_type.dart';
import '../../domain/substitutes_analytics.dart';
import '../providers/attendance_overview_provider.dart';
import '../providers/substitutes_analytics_provider.dart';
import '../widgets/searchable_thursday_date_dialog.dart';

/// Read-only Substitutes attendance analytics overview.
class SubstitutesOverviewScreen extends ConsumerStatefulWidget {
  const SubstitutesOverviewScreen({super.key});

  @override
  ConsumerState<SubstitutesOverviewScreen> createState() =>
      _SubstitutesOverviewScreenState();
}

class _SubstitutesOverviewScreenState
    extends ConsumerState<SubstitutesOverviewScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildSessionDateDropdown(
    ThemeData theme,
    bool isDark,
    SubstitutesFilterState filters,
  ) {
    final allThursdays = ref.watch(allThursdayDatesProvider);
    final selected = filters.rangeStart;
    final isCustom = selected != null;
    final displayText = isCustom
        ? DateFormat('EEE, dd MMM yyyy').format(selected)
        : 'All sessions';

    return Builder(
      builder: (btnContext) {
        return InkWell(
          onTap: () {
            showSearchableThursdayDateDropdown(
              context: btnContext,
              isDark: isDark,
              selectedDate: selected,
              allThursdays: allThursdays,
              onDateSelected: (date) {
                ref
                    .read(substitutesFilterProvider.notifier)
                    .setSessionDate(
                      date == null
                          ? null
                          : DateTime(date.year, date.month, date.day),
                    );
              },
            );
          },
          borderRadius: AppRadius.mdAll,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isCustom
                  ? AppColors.primary.withAlpha(isDark ? 40 : 20)
                  : (isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9)),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCustom
                    ? AppColors.primary.withAlpha(120)
                    : (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFCBD5E1)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.calendar_month_rounded,
                  size: 16,
                  color: isCustom
                      ? AppColors.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  displayText,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isCustom
                        ? AppColors.primary
                        : theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_drop_down_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = context.isMobile;
    final analyticsAsync = ref.watch(substitutesAnalyticsProvider);
    final profilesAsync = ref.watch(filteredSubstituteProfilesProvider);
    final filters = ref.watch(substitutesFilterProvider);

    final hPadding = context.responsiveValue<double>(
      compactMobile: 12,
      mobile: 16,
      tablet: 24,
      desktop: 28,
    );

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        child: analyticsAsync.when(
          loading: () => const Center(child: MetaPhiLoadingIndicator()),
          error: (e, _) => AppEmptyView(
            message: 'Could not load substitute attendance.\n$e',
            icon: Icons.error_outline_rounded,
          ),
          data: (analytics) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    hPadding,
                    isMobile ? 12 : 20,
                    hPadding,
                    0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isMobile) ...[
                        const AppPageHeader(
                          title: 'Substitutes',
                          subtitle: 'Track how often each substitute attended on behalf of members.',
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildToolbar(theme, isDark, isMobile, filters),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
                Expanded(
                  child: profilesAsync.when(
                    loading: () =>
                        const Center(child: MetaPhiLoadingIndicator()),
                    error: (e, _) => AppEmptyView(
                      message: 'Could not filter substitutes.\n$e',
                      icon: Icons.error_outline_rounded,
                    ),
                    data: (profiles) {
                      if (analytics.profiles.isEmpty) {
                        return const AppEmptyView(
                          message: 'No substitute check-ins yet.\nRecords appear here when someone checks in as a Substitute.',
                          icon: Icons.people_outline_rounded,
                        );
                      }
                      if (profiles.isEmpty) {
                        return AppEmptyView(
                          message:
                              'No substitutes match your search or filters.',
                          icon: Icons.search_off_rounded,
                          actionLabel: 'Clear filters',
                          action: () {
                            _searchController.clear();
                            ref
                                .read(substitutesFilterProvider.notifier)
                                .reset();
                          },
                        );
                      }
                      return isMobile
                          ? _buildMobileList(profiles, hPadding)
                          : _buildDesktopTable(
                              profiles,
                              hPadding,
                              theme,
                              isDark,
                            );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildToolbar(
    ThemeData theme,
    bool isDark,
    bool isMobile,
    SubstitutesFilterState filters,
  ) {
    final search = TextField(
      controller: _searchController,
      onChanged: (q) =>
          ref.read(substitutesFilterProvider.notifier).setSearchQuery(q),
      decoration: InputDecoration(
        hintText: 'Search name, phone, or member…',
        isDense: true,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded, size: 18),
                onPressed: () {
                  _searchController.clear();
                  ref
                      .read(substitutesFilterProvider.notifier)
                      .setSearchQuery('');
                },
              )
            : null,
        filled: true,
        fillColor: isDark ? AppColors.surfaceDark : const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          ),
        ),
      ),
    );

    final sessionDateDropdown = _buildSessionDateDropdown(
      theme,
      isDark,
      filters,
    );

    final sortBtn = PopupMenuButton<SubstituteSortOption>(
      tooltip: 'Sort',
      initialValue: filters.sort,
      onSelected: (v) =>
          ref.read(substitutesFilterProvider.notifier).setSort(v),
      itemBuilder: (context) => [
        for (final opt in SubstituteSortOption.values)
          PopupMenuItem(value: opt, child: Text(opt.label)),
      ],
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isDark ? AppColors.outlineDark : AppColors.outlineLight,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 16),
            const SizedBox(width: 6),
            Text(filters.sort.label, style: const TextStyle(fontSize: 13)),
            const Icon(Icons.arrow_drop_down_rounded, size: 18),
          ],
        ),
      ),
    );

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              sessionDateDropdown,
              sortBtn,
              if (filters.rangeStart != null)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    ref.read(substitutesFilterProvider.notifier).reset();
                  },
                  child: const Text('Reset'),
                ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(flex: 3, child: search),
        const SizedBox(width: 10),
        sessionDateDropdown,
        const SizedBox(width: 8),
        sortBtn,
      ],
    );
  }

  Widget _buildDesktopTable(
    List<SubstituteProfile> profiles,
    double hPadding,
    ThemeData theme,
    bool isDark,
  ) {
    final borderColor = isDark
        ? AppColors.outlineDark
        : const Color(0xFFE2E8F0);
    const double headerHeight = 52;
    const double rowHeight = 56;

    final headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      letterSpacing: 0.5,
      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: borderColor),
          boxShadow: AppShadows.sm,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              height: headerHeight,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF1F5F9),
                border: Border(
                  bottom: BorderSide(color: borderColor, width: 1.5),
                ),
              ),
              child: _SubstitutesTableColumns(
                substitute: Text('SUBSTITUTE', style: headerStyle),
                phone: Text('PHONE', style: headerStyle),
                visits: Text('VISITS', style: headerStyle),
                members: Text('MEMBERS', style: headerStyle),
                lastAttended: Text('LAST ATTENDED', style: headerStyle),
                action: Text('ACTION', style: headerStyle),
              ),
            ),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: profiles.length,
                itemBuilder: (context, index) {
                  final profile = profiles[index];
                  return _SubstituteRow(
                    key: ValueKey(profile.identityKey),
                    profile: profile,
                    zebra: index.isOdd,
                    borderColor: borderColor,
                    rowHeight: rowHeight,
                    onOpen: () => _openDetail(profile),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileList(List<SubstituteProfile> profiles, double hPadding) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(hPadding, 0, hPadding, 24),
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return AppCard(
          onTap: () => _openDetail(profile),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              _SubstituteAvatar(profile: profile, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.phoneDisplay.isEmpty
                          ? 'No phone'
                          : formatSubstitutePhoneDisplay(profile.phoneDisplay),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${profile.totalVisits} visits · ${profile.uniqueMembersCovered} members',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warningDark,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        );
      },
    );
  }

  void _openDetail(SubstituteProfile profile) {
    context.go(RouteNames.substituteDetailPath(profile.identityKey));
  }
}

/// Shared column skeleton — proportional flex across full width.
///
/// Uniform gutters between columns; only SUBSTITUTE→PHONE gets an extra gap.
/// No mid-row [Spacer] (that created the empty dead zone).
class _SubstitutesTableColumns extends StatelessWidget {
  const _SubstitutesTableColumns({
    required this.substitute,
    required this.phone,
    required this.visits,
    required this.members,
    required this.lastAttended,
    required this.action,
  });

  final Widget substitute;
  final Widget phone;
  final Widget visits;
  final Widget members;
  final Widget lastAttended;
  final Widget action;

  static const int flexSubstitute = 3;
  static const int flexPhone = 2;
  static const int flexVisits = 1;
  static const int flexMembers = 1;
  static const int flexLast = 2;
  static const int flexAction = 1;

  /// Standard gap between columns (PHONE→VISITS→…→ACTION).
  static const double gutter = 16;

  /// Extra name→phone breathing room on top of [gutter] (~40px total).
  static const double namePhoneBonus = 24;

  Widget _cell({
    required int flex,
    required Widget child,
    required EdgeInsets padding,
    Alignment alignment = Alignment.centerLeft,
  }) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: padding,
        child: Align(alignment: alignment, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Half-gutters on each side of a column; name|phone uses larger split.
    const half = gutter / 2;
    const namePhoneHalf = (gutter + namePhoneBonus) / 2; // 20 + 20 = 40

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _cell(
          flex: flexSubstitute,
          padding: const EdgeInsets.only(right: namePhoneHalf),
          child: substitute,
        ),
        _cell(
          flex: flexPhone,
          padding: const EdgeInsets.only(left: namePhoneHalf, right: half),
          child: phone,
        ),
        _cell(
          flex: flexVisits,
          padding: const EdgeInsets.symmetric(horizontal: half),
          child: visits,
        ),
        _cell(
          flex: flexMembers,
          padding: const EdgeInsets.symmetric(horizontal: half),
          child: members,
        ),
        _cell(
          flex: flexLast,
          padding: const EdgeInsets.symmetric(horizontal: half),
          child: lastAttended,
        ),
        _cell(
          flex: flexAction,
          padding: const EdgeInsets.only(left: half),
          alignment: Alignment.centerRight,
          child: action,
        ),
      ],
    );
  }
}

class _SubstituteRow extends StatelessWidget {
  const _SubstituteRow({
    super.key,
    required this.profile,
    required this.zebra,
    required this.borderColor,
    required this.rowHeight,
    required this.onOpen,
  });

  final SubstituteProfile profile;
  final bool zebra;
  final Color borderColor;
  final double rowHeight;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final last = profile.lastAttendance;
    final rowBg = zebra
        ? (isDark
              ? const Color(0xFF1E293B).withAlpha(50)
              : const Color(0xFFF8FAFC))
        : Colors.transparent;

    return Material(
      color: rowBg,
      child: InkWell(
        onTap: onOpen,
        child: Container(
          height: rowHeight,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: borderColor.withAlpha(160)),
            ),
          ),
          child: _SubstitutesTableColumns(
            substitute: Row(
              children: [
                _SubstituteAvatar(profile: profile, size: 34),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    profile.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
            phone: Text(
              profile.phoneDisplay.isEmpty
                  ? '—'
                  : formatSubstitutePhoneDisplay(profile.phoneDisplay),
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            visits: Text(
              '${profile.totalVisits}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            members: Text(
              '${profile.uniqueMembersCovered}',
              style: const TextStyle(fontSize: 13.5),
            ),
            lastAttended: Text(
              last == null ? '—' : DateFormat('dd MMM yyyy').format(last),
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            action: IconButton(
              tooltip: 'View',
              onPressed: onOpen,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              icon: const Icon(
                Icons.visibility_outlined,
                size: 20,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SubstituteAvatar extends StatelessWidget {
  const _SubstituteAvatar({required this.profile, required this.size});

  final SubstituteProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()[0].toUpperCase()
        : '?';
    final placeholder = CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.warning.withAlpha(40),
      child: Text(
        initial,
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: AppColors.warningDark,
          fontSize: size * 0.38,
        ),
      ),
    );
    final visit = profile.latestVisitWithPhoto;
    if (visit == null) return placeholder;
    return ClipOval(
      child: CheckInPhotoImage(
        key: ValueKey('sub-avatar-${profile.identityKey}'),
        submission: CheckInSubmission(
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
        ),
        width: size,
        height: size,
        placeholder: placeholder,
      ),
    );
  }
}
