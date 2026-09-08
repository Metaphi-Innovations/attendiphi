import 'package:flutter/material.dart';

/// Design system border radius constants.
class AppRadius {
  AppRadius._();

  /// 4dp — extra small radius for mini badges, indicators
  static const double xs = 4;

  /// 8dp — small radius for chips, tags
  static const double sm = 8;

  /// 12dp — standard radius for cards, inputs
  static const double md = 12;

  /// 16dp — large radius for dialogs, sheets
  static const double lg = 16;

  /// 24dp — extra-large radius
  static const double xl = 24;

  /// 999dp — fully rounded (pill shape)
  static const double full = 999;

  // ── Pre-built BorderRadius ────────────────────────────────────────────
  static const xsAll = BorderRadius.all(Radius.circular(xs));
  static const smAll = BorderRadius.all(Radius.circular(sm));
  static const mdAll = BorderRadius.all(Radius.circular(md));
  static const lgAll = BorderRadius.all(Radius.circular(lg));
  static const xlAll = BorderRadius.all(Radius.circular(xl));
  static const fullAll = BorderRadius.all(Radius.circular(full));

  /// Top-only radius for bottom sheets / modals
  static const lgTop = BorderRadius.only(
    topLeft: Radius.circular(lg),
    topRight: Radius.circular(lg),
  );
}
