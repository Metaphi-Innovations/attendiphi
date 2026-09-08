import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_radius.dart';
import 'app_button.dart';

/// Standardized Modal Confirmation Dialog.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.isDestructive = false,
    this.icon = Icons.warning_amber_rounded,
    this.iconColor,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool isDestructive;
  final IconData icon;
  final Color? iconColor;

  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool isDestructive = false,
    IconData icon = Icons.warning_amber_rounded,
    Color? iconColor,
  }) {
    return showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (ctx) => AppConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
        icon: icon,
        iconColor: iconColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = iconColor ?? (isDestructive ? AppColors.error : AppColors.primary);

    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
      backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withAlpha(isDark ? 40 : 25),
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isDark
                ? AppColors.onSurfaceVariantDark
                : AppColors.onSurfaceVariantLight,
            height: 1.4,
          ),
        ),
      ),
      actions: [
        AppButton(
          label: cancelLabel,
          variant: AppButtonVariant.text,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: 8),
        AppButton(
          label: confirmLabel,
          variant: AppButtonVariant.primary,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
  }
}
