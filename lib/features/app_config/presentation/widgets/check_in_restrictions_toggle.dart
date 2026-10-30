import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../admin/presentation/providers/admin_auth_provider.dart';
import '../providers/check_in_restrictions_provider.dart';

/// Super-Admin check-in restriction control.
///
/// Hamburger menu with independent Location, Date, and Device toggles
/// (all environments, including production).
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
    final deviceOn = ref.watch(deviceRestrictionEnabledProvider);
    final isSaving = writeAsync.isLoading;

    if (granularUi) {
      final tooltip =
          'Location ${locationOn ? 'ON' : 'OFF'} · '
          'Date ${dateOn ? 'ON' : 'OFF'} · '
          'Device ${deviceOn ? 'ON' : 'OFF'}';
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

    // Legacy master switch (unused while granular UI is enabled).
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
    // No confirmation — Super Admin toggles apply immediately.
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
    final deviceOn = ref.read(deviceRestrictionEnabledProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successMessage ??
              'Updated — Location ${locationOn ? 'ON' : 'OFF'}, '
                  'Date ${dateOn ? 'ON' : 'OFF'}, '
                  'Device ${deviceOn ? 'ON' : 'OFF'}',
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
  bool _savingDevice = false;

  /// Optimistic switch values so taps flip immediately (controlled Switch
  /// otherwise stays on the old provider value until the write finishes).
  bool? _optimisticLocation;
  bool? _optimisticDate;
  bool? _optimisticDevice;

  bool get _busy => _savingLocation || _savingDate || _savingDevice;

  Future<void> _onLocationChanged(bool next) async {
    if (_busy) return;
    setState(() {
      _savingLocation = true;
      _optimisticLocation = next;
    });
    try {
      await ref
          .read(checkInRestrictionsNotifierProvider.notifier)
          .setGranular(locationRestrictionEnabled: next);
      if (!mounted) return;
      CheckInRestrictionsToggle._showWriteResult(context, ref);
    } finally {
      if (mounted) {
        setState(() {
          _savingLocation = false;
          _optimisticLocation = null;
        });
      }
    }
  }

  Future<void> _onDateChanged(bool next) async {
    if (_busy) return;
    setState(() {
      _savingDate = true;
      _optimisticDate = next;
    });
    try {
      await ref
          .read(checkInRestrictionsNotifierProvider.notifier)
          .setGranular(dateRestrictionEnabled: next);
      if (!mounted) return;
      CheckInRestrictionsToggle._showWriteResult(context, ref);
    } finally {
      if (mounted) {
        setState(() {
          _savingDate = false;
          _optimisticDate = null;
        });
      }
    }
  }

  Future<void> _onDeviceChanged(bool next) async {
    if (_busy) return;
    setState(() {
      _savingDevice = true;
      _optimisticDevice = next;
    });
    try {
      await ref
          .read(checkInRestrictionsNotifierProvider.notifier)
          .setGranular(deviceRestrictionEnabled: next);
      if (!mounted) return;
      CheckInRestrictionsToggle._showWriteResult(context, ref);
    } finally {
      if (mounted) {
        setState(() {
          _savingDevice = false;
          _optimisticDevice = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Local optimistic values flip the switch immediately on tap.
    final locationOn = _optimisticLocation != null
        ? _optimisticLocation!
        : ref.watch(locationRestrictionEnabledProvider);
    final dateOn = _optimisticDate != null
        ? _optimisticDate!
        : ref.watch(dateRestrictionEnabledProvider);
    final deviceOn = _optimisticDevice != null
        ? _optimisticDevice!
        : ref.watch(deviceRestrictionEnabledProvider);
    final busy = _busy;

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
                'Toggle Location, Date, and Device independently.',
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
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('One device = one check-in'),
                subtitle: const Text(
                  'ON: each device may submit only one check-in per session '
                  'day. OFF: shared phones/tablets can check in multiple '
                  'members (venue standee mode).',
                ),
                value: deviceOn,
                onChanged: busy ? null : _onDeviceChanged,
                secondary: _savingDevice
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
