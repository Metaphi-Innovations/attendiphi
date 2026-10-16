import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../admin/presentation/providers/admin_auth_provider.dart';
import '../providers/check_in_restrictions_provider.dart';

/// Super-Admin check-in restriction control.
///
/// Staging / dev: hamburger menu with independent Location + Date toggles.
/// Production: single master ON/OFF switch (unchanged until promoted).
class CheckInRestrictionsToggle extends ConsumerWidget {
  const CheckInRestrictionsToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSuperAdmin = ref.watch(isSuperAdminProvider);
    if (!isSuperAdmin) return const SizedBox.shrink();

    final configAsync = ref.watch(checkInRestrictionsConfigProvider);
    final writeAsync = ref.watch(checkInRestrictionsNotifierProvider);
    final enabled = ref.watch(restrictionsEnabledProvider);
    final granularUi = ref.watch(granularRestrictionsUiEnabledProvider);
    final locationOn = ref.watch(locationRestrictionEnabledProvider);
    final dateOn = ref.watch(dateRestrictionEnabledProvider);
    final isSaving = writeAsync.isLoading;

    if (granularUi) {
      final tooltip =
          'Location ${locationOn ? 'ON' : 'OFF'} · Date ${dateOn ? 'ON' : 'OFF'}';
      return configAsync.when(
        loading: () => const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (_, _) => Tooltip(
          message: 'Could not load restrictions (defaulting ON)',
          child: IconButton(
            tooltip: tooltip,
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.menu, size: 20),
            onPressed: null,
          ),
        ),
        data: (_) => Tooltip(
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
              IconButton(
                tooltip: 'Restriction options',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.menu, size: 20),
                onPressed: isSaving ? null : () => _openGranularMenu(context),
              ),
            ],
          ),
        ),
      );
    }

    // Production: keep legacy master switch.
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Restrictions',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 4),
            Switch.adaptive(value: enabled, onChanged: null),
          ],
        ),
      ),
      data: (_) => Tooltip(
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
            Switch.adaptive(
              value: enabled,
              onChanged: isSaving
                  ? null
                  : (next) => _onMasterToggle(context, ref, next),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openGranularMenu(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _GranularRestrictionsDialog(),
    );
  }

  Future<void> _onMasterToggle(
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
    _showWriteResult(
      context,
      ref,
      successMessage: nextEnabled
          ? 'Check-in restrictions are ON'
          : 'Check-in restrictions are OFF (any day / multi check-in / no GPS enforce)',
    );
  }

  static void _showWriteResult(
    BuildContext context,
    WidgetRef ref, {
    String? successMessage,
  }) {
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

    final locationOn = ref.read(locationRestrictionEnabledProvider);
    final dateOn = ref.read(dateRestrictionEnabledProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successMessage ??
              'Updated — Location ${locationOn ? 'ON' : 'OFF'}, '
                  'Date ${dateOn ? 'ON' : 'OFF'}',
        ),
      ),
    );
  }
}

/// Centered pop-up so Location / Date switches rebuild after each write.
class _GranularRestrictionsDialog extends ConsumerStatefulWidget {
  const _GranularRestrictionsDialog();

  @override
  ConsumerState<_GranularRestrictionsDialog> createState() =>
      _GranularRestrictionsDialogState();
}

class _GranularRestrictionsDialogState
    extends ConsumerState<_GranularRestrictionsDialog> {
  bool _savingLocation = false;
  bool _savingDate = false;

  Future<void> _onLocationChanged(bool next) async {
    if (_savingLocation || _savingDate) return;
    if (!next) {
      final confirmed = await _confirmTurnOff(
        title: 'Turn off location restriction?',
        body:
            'Location will still be fetched when the browser allows, but '
            'check-in will not be blocked if GPS is denied or outside the '
            'venue radius.',
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _savingLocation = true);
    try {
      await ref
          .read(checkInRestrictionsNotifierProvider.notifier)
          .setGranular(locationRestrictionEnabled: next);
      if (!mounted) return;
      CheckInRestrictionsToggle._showWriteResult(context, ref);
    } finally {
      if (mounted) setState(() => _savingLocation = false);
    }
  }

  Future<void> _onDateChanged(bool next) async {
    if (_savingLocation || _savingDate) return;
    if (!next) {
      final confirmed = await _confirmTurnOff(
        title: 'Turn off date restriction?',
        body:
            'Date gates will turn off: everyday QR standees and check-in on '
            'any day. Daily Attendance / Overview will show every day’s '
            'sessions.',
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _savingDate = true);
    try {
      await ref
          .read(checkInRestrictionsNotifierProvider.notifier)
          .setGranular(dateRestrictionEnabled: next);
      if (!mounted) return;
      CheckInRestrictionsToggle._showWriteResult(context, ref);
    } finally {
      if (mounted) setState(() => _savingDate = false);
    }
  }

  Future<bool?> _confirmTurnOff({
    required String title,
    required String body,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
  }

  @override
  Widget build(BuildContext context) {
    final locationOn = ref.watch(locationRestrictionEnabledProvider);
    final dateOn = ref.watch(dateRestrictionEnabledProvider);
    final busy = _savingLocation || _savingDate;

    return AlertDialog(
      title: const Text('Check-in restrictions'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Staging only — toggle Location and Date independently.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Location restriction'),
                subtitle: const Text(
                  'ON: GPS + radius required. OFF: still fetch GPS when '
                  'possible, but never block check-in.',
                ),
                value: locationOn,
                onChanged: busy ? null : _onLocationChanged,
                secondary: _savingLocation
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date restriction'),
                subtitle: const Text(
                  'ON: Thursday QR + session-day only. OFF: everyday QR '
                  'and daily attendance for any day.',
                ),
                value: dateOn,
                onChanged: busy ? null : _onDateChanged,
                secondary: _savingDate
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
