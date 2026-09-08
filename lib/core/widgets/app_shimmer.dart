import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// Shimmer placeholder widget that provides an animated skeleton gradient.
class AppShimmer extends StatefulWidget {
  const AppShimmer({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<AppShimmer> createState() => _AppShimmerState();
}

class _AppShimmerState extends State<AppShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppColors.surfaceVariantDark
        : AppColors.shimmerBase;
    final highlightColor = isDark
        ? AppColors.surfaceDark
        : AppColors.shimmerHighlight;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? AppRadius.smAll,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                baseColor,
                highlightColor,
                baseColor,
              ],
              stops: [
                (_controller.value - 0.3).clamp(0.0, 1.0),
                _controller.value,
                (_controller.value + 0.3).clamp(0.0, 1.0),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Skeleton loading list for attendance check-in cards and user cards.
class CheckInCardSkeletonList extends StatelessWidget {
  const CheckInCardSkeletonList({
    super.key,
    this.count = 5,
  });

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
              ),
            ),
            child: const Row(
              children: [
                AppShimmer(
                  width: 44,
                  height: 44,
                  borderRadius: AppRadius.fullAll,
                ),
                SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppShimmer(width: 140, height: 14),
                      SizedBox(height: AppSpacing.xs),
                      AppShimmer(width: 90, height: 12),
                    ],
                  ),
                ),
                SizedBox(width: AppSpacing.sm),
                AppShimmer(width: 60, height: 24, borderRadius: AppRadius.smAll),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
