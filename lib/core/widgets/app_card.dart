import 'package:flutter/material.dart';

import '../../app/theme/app_radius.dart';
import '../../app/theme/app_spacing.dart';

/// A styled card with consistent elevation, shape, and padding.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.elevation,
    this.shadows,
    this.color,
    this.borderColor,
    this.borderRadius,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? elevation;
  final List<BoxShadow>? shadows;
  final Color? color;
  final Color? borderColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final r = borderRadius ?? AppRadius.mdAll;

    List<BoxShadow>? effectiveShadows = shadows;
    if (effectiveShadows == null && elevation != null && elevation! > 0) {
      effectiveShadows = [
        BoxShadow(
          color: theme.colorScheme.shadow.withAlpha(isDark ? 30 : 10),
          blurRadius: elevation! * 2,
          offset: Offset(0, elevation!),
        ),
      ];
    }

    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: color ?? theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: r,
        border: Border.all(
          color: borderColor ??
              (isDark
                  ? theme.colorScheme.outline.withAlpha(50)
                  : theme.colorScheme.outline.withAlpha(70)),
        ),
        boxShadow: effectiveShadows,
      ),
      child: child,
    );

    if (onTap == null) {
      return Padding(
        padding: margin ?? EdgeInsets.zero,
        child: cardContent,
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: r,
        child: InkWell(
          onTap: onTap,
          borderRadius: r,
          hoverColor: isDark
              ? Colors.white.withAlpha(8)
              : Colors.black.withAlpha(6),
          splashColor: isDark
              ? Colors.white.withAlpha(12)
              : Colors.black.withAlpha(10),
          child: cardContent,
        ),
      ),
    );
  }
}

