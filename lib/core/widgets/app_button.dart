import 'package:flutter/material.dart';

/// A configurable button widget supporting multiple variants.
///
/// Variants:
/// - **primary**: Filled button for primary actions
/// - **secondary**: Outlined button for secondary actions
/// - **text**: Text-only button for tertiary actions
///
/// Supports a loading state that shows a spinner and disables interaction.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.fullWidth = true,
    this.enabled = true,
  });

  /// Primary filled button.
  const AppButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.enabled = true,
  }) : variant = AppButtonVariant.primary;

  /// Outlined secondary button.
  const AppButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = true,
    this.enabled = true,
  }) : variant = AppButtonVariant.secondary;

  /// Text-only button.
  const AppButton.text({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
    this.fullWidth = false,
    this.enabled = true,
  }) : variant = AppButtonVariant.text;

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool fullWidth;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = (enabled && !isLoading) ? onPressed : null;

    final child = isLoading
        ? const SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
        : icon != null
        ? Row(
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            ],
          )
        : Text(label, overflow: TextOverflow.ellipsis);

    Widget button;

    switch (variant) {
      case AppButtonVariant.primary:
        button = ElevatedButton(onPressed: effectiveOnPressed, child: child);
      case AppButtonVariant.secondary:
        button = OutlinedButton(onPressed: effectiveOnPressed, child: child);
      case AppButtonVariant.text:
        button = TextButton(onPressed: effectiveOnPressed, child: child);
    }

    if (!fullWidth) {
      return button;
    }

    return SizedBox(width: double.infinity, child: button);
  }
}

/// Button style variants.
enum AppButtonVariant { primary, secondary, text }
