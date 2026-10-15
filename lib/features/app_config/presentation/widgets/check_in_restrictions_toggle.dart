import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../admin/presentation/providers/admin_auth_provider.dart';
import '../providers/check_in_restrictions_provider.dart';

/// Compact Super-Admin-only switch for production check-in restrictions.
/// Intended for the Daily Attendance header (top-right).
class CheckInRestrictionsToggle extends ConsumerWidget {
  const CheckInRestrictionsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    if (!isSuperAdmin) return const SizedBox.shrink();

    final configAsync = ref.watch(checkInRestrictionsConfigProvider);
    final writeAsync = ref.watch(checkInRestrictionsNotifierProvider);
    final enabled = ref.watch(restrictionsEnabledProvider);
    final isSaving = writeAsync.isLoading;

    final tooltip = enabled
        ? 'Restrictions ON — Thursday + QR date + one device + GPS'
        : 'Restrictions OFF — test mode (any day / multi check-in / no GPS)';

    return configAsync.when(
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, _) => Tooltip(
        message: 'Could not load restrictions (defaulting ON)',
        child: _switchRow(
          context,
          enabled: enabled,
          isSaving: isSaving,
          tooltip: tooltip,
          onChanged: null,
        ),
      ),
      data: (_) => _switchRow(
        context,
        enabled: enabled,
        isSaving: isSaving,
        tooltip: tooltip,
        onChanged: isSaving ? null : (next) => _onToggle(context, ref, next),
      ),
    );
  }

  Widget _switchRow(
    BuildContext context, {
    required bool enabled,
    required bool isSaving,
    required String tooltip,
    required ValueChanged<bool>? onChanged,
  }) {
    return Tooltip(
      message: tooltip,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          Text(
            'Restrictions',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 4),
          Switch.adaptive(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool nextEnabled,
  ) async {
    if (!nextEnabled) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Turn OFF check-in restrictions?'),
          content: const Text(
            'This weakens production controls:\n'
            '• Check-in works any day of the week\n'
            '• Any QR session date is accepted\n'
            '• Same device can check in multiple times\n'
            '• Location / GPS proximity is not required\n\n'
            'Phone uniqueness stays on.\n'
            'Use only for testing. Turn restrictions back ON afterward.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD97706),
              ),
              child: const Text('Turn OFF'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    await ref
        .read(checkInRestrictionsNotifierProvider.notifier)
        .setEnabled(nextEnabled);

    if (!context.mounted) return;
    final err = ref.read(checkInRestrictionsNotifierProvider).error;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update restrictions: $err'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          nextEnabled ? 'Check-in restrictions are ON' : 'Check-in restrictions are OFF (any day / multi check-in / no GPS)',
        ),
      ),
    );
  }
}
