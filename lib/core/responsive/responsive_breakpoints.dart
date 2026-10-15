import 'package:flutter/material.dart';

/// Screen breakpoint definitions and device classification.
enum ScreenDeviceType { compactMobile, mobile, tablet, desktop }

/// Centralized responsive breakpoint constants and layout helpers.
class ResponsiveBreakpoints {
  ResponsiveBreakpoints._();

  /// Maximum width for ultra-compact devices (e.g. iPhone SE, small phones: < 360px).
  static const double compactMobile = 360;

  /// Maximum width for mobile devices (< 600px).
  static const double mobile = 600;

  /// Maximum width for tablet / iPad devices (600px - 1024px).
  static const double tablet = 1024;

  /// Maximum content constraint widths for clean presentation on wide screens.
  static const double maxFormWidth = 520;
  static const double maxCardWidth = 460;
  static const double maxDialogWidth = 440;
  static const double maxStandeeWidth = 480;
  static const double maxDashboardWidth = 1100;
  static const double maxReaderWidth = 720;
}

/// Extension on [BuildContext] providing clean, reactive responsive helpers.
extension ResponsiveContextExtension on BuildContext {
  /// Current screen width from [MediaQuery].
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Current screen height from [MediaQuery].
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Current screen orientation.
  Orientation get orientation => MediaQuery.orientationOf(this);

  /// True if device is in portrait orientation.
  bool get isPortrait => orientation == Orientation.portrait;

  /// True if device is in landscape orientation.
  bool get isLandscape => orientation == Orientation.landscape;

  /// True if screen width is < 360px (ultra-compact mobile).
  bool get isCompactMobile => screenWidth < ResponsiveBreakpoints.compactMobile;

  /// True if screen width is < 600px (mobile).
  bool get isMobile => screenWidth < ResponsiveBreakpoints.mobile;

  /// True if screen width is between 600px and 1024px (tablet).
  bool get isTablet =>
      screenWidth >= ResponsiveBreakpoints.mobile &&
      screenWidth < ResponsiveBreakpoints.tablet;

  /// True if screen width is >= 1024px (desktop / wide display).
  bool get isDesktop => screenWidth >= ResponsiveBreakpoints.tablet;

  /// Categorized device type based on width.
  ScreenDeviceType get deviceType {
    if (isCompactMobile) return ScreenDeviceType.compactMobile;
    if (isMobile) return ScreenDeviceType.mobile;
    if (isTablet) return ScreenDeviceType.tablet;
    return ScreenDeviceType.desktop;
  }

  /// Returns a responsive value depending on the current device screen size.
  T responsiveValue<T>({
    required T mobile,
    T? compactMobile,
    T? tablet,
    T? desktop,
  }) {
    if (isCompactMobile && compactMobile != null) {
      return compactMobile;
    }
    if (isDesktop && desktop != null) {
      return desktop;
    }
    if (isTablet && tablet != null) {
      return tablet;
    }
    return mobile;
  }
}
