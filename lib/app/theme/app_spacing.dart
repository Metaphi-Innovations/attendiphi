/// Design system spacing constants.
///
/// Use these instead of arbitrary pixel values for consistent spacing.
class AppSpacing {
  AppSpacing._();

  /// 4dp — tight spacing for compact elements
  static const double xs = 4;

  /// 8dp — small gap between related elements
  static const double sm = 8;

  /// 12dp — medium-small gap
  static const double md = 12;

  /// 16dp — standard section gap
  static const double lg = 16;

  /// 24dp — large gap between sections
  static const double xl = 24;

  /// 32dp — extra-large gap
  static const double xxl = 32;

  /// 48dp — page-level gap
  static const double xxxl = 48;

  /// Standard horizontal page padding
  static const double pagePadding = 24;

  /// Standard card inner padding
  static const double cardPadding = 16;

  /// Standard form field vertical spacing
  static const double formFieldGap = 16;

  /// Responsive page padding based on screen width.
  static double responsivePagePadding(double width) {
    if (width < 360) return 12;
    if (width < 600) return 16;
    if (width < 1024) return 24;
    return 32;
  }

  /// Responsive card padding based on screen width.
  static double responsiveCardPadding(double width) {
    if (width < 360) return 12;
    if (width < 600) return 16;
    return 20;
  }
}
