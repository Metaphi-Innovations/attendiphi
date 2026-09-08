import 'package:flutter/material.dart';

/// Convenience extensions on [BuildContext].
extension ContextExtensions on BuildContext {
  /// Access the current [ThemeData].
  ThemeData get theme => Theme.of(this);

  /// Access the current [ColorScheme].
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Access the current [TextTheme].
  TextTheme get textTheme => Theme.of(this).textTheme;

  /// Access the current [MediaQueryData].
  MediaQueryData get mediaQuery => MediaQuery.of(this);

  /// Screen width.
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// Screen height.
  double get screenHeight => MediaQuery.sizeOf(this).height;

  /// Whether the current brightness is dark.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// Bottom padding (safe area, keyboard).
  double get bottomPadding => MediaQuery.paddingOf(this).bottom;

  /// Top padding (safe area, status bar).
  double get topPadding => MediaQuery.paddingOf(this).top;

  /// Show a snackbar with the given message.
  void showSnackBar(
    String message, {
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: duration,
          action: action,
        ),
      );
  }

  /// Show an error snackbar.
  void showErrorSnackBar(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 4),
        ),
      );
  }

  /// Show a success snackbar.
  void showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF059669),
          duration: const Duration(seconds: 3),
        ),
      );
  }
}
