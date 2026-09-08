import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Displays an empty state with icon and message.
///
/// Use when a list/collection has no items to show.
class AppEmptyView extends StatelessWidget {
  const AppEmptyView({
    super.key,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
    this.actionLabel,
  });

  final String message;
  final IconData icon;
  final VoidCallback? action;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color:
                    theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 48,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              message,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null && actionLabel != null) ...[
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: action,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
