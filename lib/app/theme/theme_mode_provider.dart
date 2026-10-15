import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier managing application ThemeMode (Dark vs Light).
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    return ThemeMode.light;
  }

  /// Light theme is the only active theme.
  void toggleTheme() {
    state = ThemeMode.light;
  }

  /// Sets a specific theme mode.
  void setThemeMode(ThemeMode mode) {
    state = ThemeMode.light;
  }
}

/// Global provider for application ThemeMode.
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(() {
  return ThemeModeNotifier();
});
