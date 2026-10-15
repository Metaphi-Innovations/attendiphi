import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_empty_view.dart';
import '../../../../core/widgets/app_page_header.dart';
import '../../../../core/widgets/app_shimmer.dart';
import '../providers/substitutes_analytics_provider.dart';
import '../widgets/substitutes/substitute_profile_header.dart';
import '../widgets/substitutes/substitute_visit_table.dart';

/// Substitute detail: check-in profile + visit table.
class SubstituteDetailScreen extends ConsumerWidget {
  const SubstituteDetailScreen({super.key, required this.identityKey});

  final String identityKey;

  static const double _contentMaxWidth = 920;

  void _goToSubstitutes(BuildContext context) {
    context.go(RouteNames.adminSubstitutes);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMobile = context.isMobile;
    final profileAsync = ref.watch(substituteProfileByKeyProvider(identityKey));

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
      appBar: isMobile
          ? AppBar(
              title: const Text('Substitute Details'),
              leading: IconButton(
                tooltip: 'Back to Substitutes',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => _goToSubstitutes(context),
              ),
            )
          : null,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => _DetailSkeleton(hPadding: hPadding),
          error: (e, stack) {
            debugPrint('Substitute detail load error: $e\n$stack');
            return AppEmptyView(
              message: 'Could not load substitute details.\nPlease try again.',
              icon: Icons.error_outline_rounded,
              actionLabel: 'Retry',
              action: () => ref.invalidate(substitutesAnalyticsProvider),
            );
          },
          data: (profile) {
            if (profile == null) {
              return AppEmptyView(
                message: 'Substitute not found.',
                icon: Icons.person_off_rounded,
                actionLabel: 'Back to Substitutes',
                action: () => _goToSubstitutes(context),
              );
            }

            return Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    hPadding,
                    isMobile ? 16 : 24,
                    hPadding,
                    28,
                  ),
                  children: [
                    if (!isMobile) ...[
                      AppPageHeader(
                        title: 'Substitute details',
                        leading: IconButton(
                          tooltip: 'Back to Substitutes',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () => _goToSubstitutes(context),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    SubstituteProfileHeader(
                      profile: profile,
                      compact: isMobile,
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Visit history',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${profile.totalVisits} '
                      '${profile.totalVisits == 1 ? 'visit' : 'visits'} · '
                      '${profile.uniqueMembersCovered} '
                      '${profile.uniqueMembersCovered == 1 ? 'member' : 'members'} covered',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (profile.visits.isEmpty)
                      const _EmptyVisitsState()
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          if (constraints.maxWidth < 640) {
                            return SubstituteVisitListMobile(
                              visits: profile.visits,
                            );
                          }
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: constraints.maxWidth < 800
                                  ? 800
                                  : constraints.maxWidth,
                              child: SubstituteVisitTable(
                                visits: profile.visits,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyVisitsState extends StatelessWidget {
  const _EmptyVisitsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(isDark ? 40 : 22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No substitute attendance recorded yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Records will appear here after a verified substitute check-in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton({required this.hPadding});

  final double hPadding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 920),
        child: ListView(
          padding: EdgeInsets.fromLTRB(hPadding, 24, hPadding, 28),
          children: [
            const AppShimmer(width: 220, height: 28),
            const SizedBox(height: 20),
            Row(
              children: [
                AppShimmer(
                  width: 72,
                  height: 72,
                  borderRadius: BorderRadius.circular(16),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(width: 200, height: 22),
                      SizedBox(height: 8),
                      AppShimmer(width: 160, height: 14),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            const AppShimmer(width: 120, height: 16),
            const SizedBox(height: 8),
            const AppShimmer(width: 160, height: 12),
            const SizedBox(height: 14),
            const AppShimmer(height: 160, borderRadius: AppRadius.mdAll),
          ],
        ),
      ),
    );
  }
}
