import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import '../../features/checkin/domain/entities/check_in_type.dart';

/// Semantic badge variants for status and role indicators.
enum AppBadgeVariant {
  primary,
  success,
  warning,
  error,
  info,
  neutral,
}

/// Universal, clean status badge component.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.neutral,
    this.icon,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color bg;
    Color fg;
    BorderSide? border;

    switch (variant) {
      case AppBadgeVariant.primary:
        bg = isDark
            ? AppColors.primary.withAlpha(40)
            : AppColors.primaryContainer;
        fg = isDark ? AppColors.primaryLight : AppColors.onPrimaryContainer;
        border = BorderSide(color: fg.withAlpha(50));
      case AppBadgeVariant.success:
        bg = isDark
            ? AppColors.success.withAlpha(40)
            : AppColors.successLight;
        fg = isDark ? const Color(0xFF34D399) : AppColors.onSuccessContainer;
        border = BorderSide(color: fg.withAlpha(50));
      case AppBadgeVariant.warning:
        bg = isDark
            ? AppColors.warning.withAlpha(40)
            : AppColors.warningLight;
        fg = isDark ? const Color(0xFFFBBF24) : AppColors.onWarningContainer;
        border = BorderSide(color: fg.withAlpha(50));
      case AppBadgeVariant.error:
        bg = isDark
            ? AppColors.error.withAlpha(40)
            : AppColors.errorLight;
        fg = isDark ? const Color(0xFFF87171) : AppColors.onErrorContainer;
        border = BorderSide(color: fg.withAlpha(50));
      case AppBadgeVariant.info:
        bg = isDark
            ? AppColors.info.withAlpha(40)
            : AppColors.infoLight;
        fg = isDark ? const Color(0xFF60A5FA) : AppColors.onInfoContainer;
        border = BorderSide(color: fg.withAlpha(50));
      case AppBadgeVariant.neutral:
        bg = isDark
            ? AppColors.surfaceVariantDark
            : AppColors.surfaceVariantLight;
        fg = isDark
            ? AppColors.onSurfaceVariantDark
            : AppColors.onSurfaceVariantLight;
        border = BorderSide(color: fg.withAlpha(40));
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.fullAll,
        border: Border.fromBorderSide(border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 1, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.2,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Specialized Attendance Type Badge for Member / Substitute / Visitor check-ins.
class AppAttendanceTypeBadge extends StatelessWidget {
  const AppAttendanceTypeBadge({
    super.key,
    this.type,
    this.isSubstitute = false,
    this.fontSize = 11,
  });

  final CheckInType? type;
  final bool isSubstitute;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (type != null) {
      switch (type!) {
        case CheckInType.member:
          return AppBadge(
            label: 'Member',
            variant: AppBadgeVariant.success,
            icon: Icons.verified_user_outlined,
            fontSize: fontSize,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          );
        case CheckInType.substitute:
          return AppBadge(
            label: 'Substitute',
            variant: AppBadgeVariant.warning,
            icon: Icons.swap_horiz_rounded,
            fontSize: fontSize,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          );
        case CheckInType.visitor:
          return AppBadge(
            label: 'Visitor',
            variant: AppBadgeVariant.primary,
            icon: Icons.card_membership_rounded,
            fontSize: fontSize,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          );
        case CheckInType.absent:
          return AppBadge(
            label: 'Absent',
            variant: AppBadgeVariant.error,
            icon: Icons.person_off_rounded,
            fontSize: fontSize,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          );
      }
    }

    return AppBadge(
      label: isSubstitute ? 'Substitute' : 'Member',
      variant: isSubstitute ? AppBadgeVariant.warning : AppBadgeVariant.success,
      icon: isSubstitute ? Icons.swap_horiz_rounded : Icons.verified_user_outlined,
      fontSize: fontSize,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    );
  }
}

typedef AppRoleBadge = AppAttendanceTypeBadge;

/// Specialized Live Sync Badge with pulsing indicator.
class AppLiveSyncBadge extends StatelessWidget {
  const AppLiveSyncBadge({
    super.key,
    this.fontSize = 11,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
  });

  final double fontSize;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withAlpha(25),
        borderRadius: AppRadius.fullAll,
        border: Border.all(
          color: const Color(0xFF10B981).withAlpha(60),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'LIVE SYNC',
              style: TextStyle(
                color: const Color(0xFF10B981),
                fontWeight: FontWeight.w700,
                fontSize: fontSize,
                letterSpacing: 0.5,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
