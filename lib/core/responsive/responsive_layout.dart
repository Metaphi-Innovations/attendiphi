import 'package:flutter/material.dart';

import 'responsive_breakpoints.dart';

/// Builder signature for responsive builders.
typedef ResponsiveWidgetBuilder = Widget Function(
  BuildContext context,
  BoxConstraints constraints,
  ScreenDeviceType deviceType,
);

/// A widget that switches between mobile, tablet, and desktop layouts
/// based on the available constraints or screen dimensions.
class ResponsiveLayout extends StatelessWidget {
  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  final WidgetBuilder mobile;
  final WidgetBuilder? tablet;
  final WidgetBuilder? desktop;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width >= ResponsiveBreakpoints.tablet && desktop != null) {
          return desktop!(context);
        }
        if (width >= ResponsiveBreakpoints.mobile && tablet != null) {
          return tablet!(context);
        }
        return mobile(context);
      },
    );
  }
}

/// An adaptive container that centers its child and applies a sensible maximum width,
/// preventing content from excessively stretching on tablets and wide desktop screens.
class AdaptiveContainer extends StatelessWidget {
  const AdaptiveContainer({
    super.key,
    required this.child,
    this.maxWidth = ResponsiveBreakpoints.maxFormWidth,
    this.padding,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry? padding;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    final horizontalPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    final effectivePadding =
        padding ??
        EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: context.isCompactMobile ? 12.0 : 20.0,
        );

    return SizedBox(
      width: double.infinity,
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: effectivePadding, child: child),
        ),
      ),
    );
  }
}
