import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../../checkin/data/datasources/device_checkin_service.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/presentation/screens/checkin_result_screen.dart';
import '../../domain/entities/location_config.dart';
import '../providers/location_validation_provider.dart';
import '../providers/location_validation_state.dart';

/// Screen managing GPS verification for a specific check-in location.
class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({
    super.key,
    required this.location,
    this.adminId,
    this.sessionDateStr,
    this.nowProvider,
  });

  final LocationConfig location;
  final String? adminId;
  final String? sessionDateStr;
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  bool _isCheckingDevice = true;
  bool _hasCheckedIn = false;
  CheckInSubmission? _existingSubmission;

  DateTime? get _parsedSessionDate {
    if (widget.sessionDateStr == null || widget.sessionDateStr!.trim().isEmpty) {
      return null;
    }
    return DateTime.tryParse(widget.sessionDateStr!.trim());
  }

  DateTime get _now =>
      widget.nowProvider != null ? widget.nowProvider!() : DateTime.now();

  bool get _isTodayThursday => _now.weekday == DateTime.thursday;

  bool get _isSessionExpired {
    final sessionDate = _parsedSessionDate;
    if (sessionDate == null) return false;
    final today = DateTime(_now.year, _now.month, _now.day);
    final sessionDay =
        DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
    return sessionDay.isBefore(today);
  }

  bool get _isSessionFuture {
    final sessionDate = _parsedSessionDate;
    if (sessionDate == null) return false;
    final today = DateTime(_now.year, _now.month, _now.day);
    final sessionDay =
        DateTime(sessionDate.year, sessionDate.month, sessionDate.day);
    return sessionDay.isAfter(today);
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _checkDeviceSubmission();
  }

  Future<void> _checkDeviceSubmission() async {
    final deviceService = ref.read(deviceCheckInServiceProvider);
    final hasCheckedIn = await deviceService.hasCheckedInForSession(
      sessionDateStr: widget.sessionDateStr,
      locationId: widget.location.id,
    );

    if (!mounted) return;

    if (hasCheckedIn) {
      final existingSubmission = await deviceService.getSubmissionForSession(
        sessionDateStr: widget.sessionDateStr,
        locationId: widget.location.id,
      );
      if (!mounted) return;
      setState(() {
        _hasCheckedIn = true;
        _existingSubmission = existingSubmission;
        _isCheckingDevice = false;
      });
      context.go(RouteNames.checkinResult, extra: existingSubmission);
      return;
    }

    setState(() {
      _isCheckingDevice = false;
    });

    // Automatically initiate location check on screen entrance only if session is active on Thursday
    if (_isTodayThursday && !_isSessionExpired && !_isSessionFuture) {
      _pulseController.repeat();
      ref
          .read(locationValidationFamilyProvider(widget.location).notifier)
          .validateLocation();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasCheckedIn || _existingSubmission != null) {
      return CheckInResultScreen(submission: _existingSubmission);
    }

    if (_isCheckingDevice) {
      return const Scaffold(
        body: Center(
          child: MetaPhiLoadingIndicator(),
        ),
      );
    }

    final validationState =
        ref.watch(locationValidationFamilyProvider(widget.location));
    final isCompact = context.isCompactMobile;

    final hPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    // Listen for successful validation to navigate to check-in form
    ref.listen<LocationValidationState>(
      locationValidationFamilyProvider(widget.location),
      (prev, next) {
        if (_hasCheckedIn || _existingSubmission != null) return;
        if (next is LocationValidationSuccess) {
          Future.delayed(const Duration(milliseconds: 700), () {
            if (!context.mounted) return;
            final queryParams = [
              if (widget.adminId != null && widget.adminId!.isNotEmpty)
                'adminId=${widget.adminId}',
              if (widget.sessionDateStr != null &&
                  widget.sessionDateStr!.isNotEmpty)
                'date=${widget.sessionDateStr}',
            ].join('&');
            final fullQuery = queryParams.isNotEmpty ? '?$queryParams' : '';
            context.go(
              '${RouteNames.checkinFormPath(widget.location.id)}$fullQuery',
              extra: next.result,
            );
          });
        }
      },
    );

    final isBusy = validationState is LocationValidationRequestingPermission ||
        validationState is LocationValidationFetchingPosition;

    return AppScaffold(
      title: AppStrings.locationPermissionTitle,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: hPadding,
            vertical: isCompact ? 16 : 24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveBreakpoints.maxFormWidth,
            ),
            child: !_isTodayThursday
                ? _buildNotThursdayView(context)
                : _isSessionExpired
                    ? _buildExpiredSessionView(context, _parsedSessionDate!)
                    : _isSessionFuture
                        ? _buildFutureSessionView(context, _parsedSessionDate!)
                        : Column(
                        children: [
                          SizedBox(height: isCompact ? 10 : 20),

                // 1. Animated Radar / Status Icon
                _LocationRadarIndicator(
                  pulseController: _pulseController,
                  state: validationState,
                ),

                SizedBox(height: isCompact ? 20 : 32),

                // 2. Venue Target Card
                AppCard(
                  color: Theme.of(context)
                      .colorScheme
                      .surfaceContainerHighest
                      .withAlpha(50),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.location.name,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                                if (widget.location.address != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    widget.location.address!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(),
                      const SizedBox(height: 8),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            'Allowed Perimeter:',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Text(
                              'Within ${widget.location.radiusMeters.round()} meters',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: isCompact ? 20 : 28),

                // 3. Dynamic State Message
                _buildStateMessage(context, validationState),

                SizedBox(height: isCompact ? 20 : 32),

                // 4. Action Buttons
                _buildActionButtons(context, validationState, isBusy),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExpiredSessionView(BuildContext context, DateTime sessionDate) {
    final theme = Theme.of(context);
    final isCompact = context.isCompactMobile;
    final isDark = theme.brightness == Brightness.dark;
    final formattedSessionDate =
        DateFormat('EEEE, dd MMMM yyyy').format(sessionDate);
    final formattedToday =
        DateFormat('EEEE, dd MMMM yyyy').format(DateTime.now());

    return Column(
      children: [
        SizedBox(height: isCompact ? 12 : 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(isDark ? 40 : 20),
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.error.withAlpha(isDark ? 90 : 60),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.timer_off_rounded,
              color: AppColors.error,
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.error.withAlpha(25),
            borderRadius: AppRadius.fullAll,
            border: Border.all(color: AppColors.error.withAlpha(60)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cancel_rounded, size: 12, color: AppColors.error),
              SizedBox(width: 5),
              Text(
                'SESSION EXPIRED',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'QR Standee Expired',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'This QR standee was only valid for the Thursday meeting on $formattedSessionDate. Attendance submissions for this session are now closed.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
          child: Column(
            children: [
              _buildDetailRow(
                context,
                'Session Date',
                formattedSessionDate,
                Icons.event_rounded,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                context,
                'Session Validity',
                'Valid until 11:59 PM (Expired)',
                Icons.schedule_rounded,
                isError: true,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                context,
                'Today\'s Date',
                formattedToday,
                Icons.today_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFutureSessionView(BuildContext context, DateTime sessionDate) {
    final theme = Theme.of(context);
    final isCompact = context.isCompactMobile;
    final isDark = theme.brightness == Brightness.dark;
    final formattedSessionDate =
        DateFormat('EEEE, dd MMMM yyyy').format(sessionDate);

    return Column(
      children: [
        SizedBox(height: isCompact ? 12 : 24),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withAlpha(isDark ? 40 : 20),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFF6366F1).withAlpha(isDark ? 90 : 60),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.event_available_rounded,
              color: Color(0xFF6366F1),
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withAlpha(25),
            borderRadius: AppRadius.fullAll,
            border: Border.all(color: const Color(0xFF6366F1).withAlpha(60)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF6366F1)),
              SizedBox(width: 5),
              Text(
                'UPCOMING SESSION',
                style: TextStyle(
                  color: Color(0xFF6366F1),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Session Not Active Yet',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'This QR standee is scheduled for $formattedSessionDate. Attendance check-in will open on the day of the session at 00:00.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
          child: Column(
            children: [
              _buildDetailRow(
                context,
                'Scheduled Session',
                formattedSessionDate,
                Icons.event_rounded,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                context,
                'Opening Time',
                'Thursday at 00:00',
                Icons.schedule_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotThursdayView(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    int daysUntilThursday = (DateTime.thursday - _now.weekday) % 7;
    if (daysUntilThursday <= 0) daysUntilThursday += 7;
    final nextThursday = _now.add(Duration(days: daysUntilThursday));
    final nextDateStr = DateFormat('EEEE, dd MMMM yyyy').format(nextThursday);

    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withAlpha(isDark ? 50 : 25),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFF59E0B).withAlpha(isDark ? 90 : 60),
              width: 2,
            ),
          ),
          child: const Center(
            child: Icon(
              Icons.event_busy_rounded,
              color: Color(0xFFD97706),
              size: 42,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withAlpha(25),
            borderRadius: AppRadius.fullAll,
            border: Border.all(color: const Color(0xFFF59E0B).withAlpha(60)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_clock_rounded, size: 12, color: Color(0xFFD97706)),
              SizedBox(width: 5),
              Text(
                'THURSDAY ONLY',
                style: TextStyle(
                  color: Color(0xFFD97706),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Check-In Closed Today',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Member check-in is allowed ONLY on Thursdays. The attendance period does not extend to non-Thursday days.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        AppCard(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(50),
          child: Column(
            children: [
              _buildDetailRow(
                context,
                'Next Session',
                nextDateStr,
                Icons.event_rounded,
              ),
              const Divider(height: 16),
              _buildDetailRow(
                context,
                'Session Schedule',
                'Every Thursday',
                Icons.schedule_rounded,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon, {
    bool isError = false,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: isError ? AppColors.error : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: isError ? AppColors.error : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStateMessage(
    BuildContext context,
    LocationValidationState state,
  ) {
    final theme = Theme.of(context);

    if (state is LocationValidationSuccess) {
      final distance = state.result.distanceMeters.round();
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.successLight.withAlpha(40),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.success),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Location Verified! You are ~$distance meters away.',
                style: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (state is LocationValidationOutsideRadius) {
      final distance = state.distanceMeters.round();
      final allowed = state.allowedRadiusMeters.round();
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorLight.withAlpha(50),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.error),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.location_off_rounded, color: AppColors.error),
                SizedBox(width: 8),
                Text(
                  'Outside Allowed Radius',
                  style: TextStyle(
                    color: AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'You are currently ~$distance meters away from this venue. Check-in is only permitted within $allowed meters.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    if (state is LocationValidationError) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorLight.withAlpha(40),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.error),
        ),
        child: Text(
          ErrorHandler.getUserMessage(state.exception),
          style: const TextStyle(color: AppColors.error),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Text(
      state is LocationValidationFetchingPosition
          ? 'Locking GPS coordinates...'
          : 'Requesting permission to verify your physical presence...',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    LocationValidationState state,
    bool isBusy,
  ) {
    if (state is LocationValidationError && state.requiresSettings) {
      return Column(
        children: [
          AppButton.primary(
            label: AppStrings.locationPermissionOpenSettings,
            icon: Icons.settings_rounded,
            onPressed: () {
              ref
                  .read(locationValidationFamilyProvider(widget.location).notifier)
                  .openSettings();
            },
          ),
          const SizedBox(height: 12),
          AppButton.secondary(
            label: 'Retry Check',
            onPressed: () {
              ref
                  .read(locationValidationFamilyProvider(widget.location).notifier)
                  .validateLocation();
            },
          ),
        ],
      );
    }

    if (state is LocationValidationOutsideRadius ||
        state is LocationValidationError) {
      return AppButton.primary(
        label: AppStrings.locationRetry,
        icon: Icons.refresh_rounded,
        onPressed: () {
          ref
              .read(locationValidationFamilyProvider(widget.location).notifier)
              .validateLocation();
        },
      );
    }

    if (state is LocationValidationSuccess) {
      return AppButton.primary(
        label: 'Continue to Check-In',
        icon: Icons.arrow_forward_rounded,
        onPressed: () {
          final queryParams = [
            if (widget.adminId != null && widget.adminId!.isNotEmpty)
              'adminId=${widget.adminId}',
            if (widget.sessionDateStr != null && widget.sessionDateStr!.isNotEmpty)
              'date=${widget.sessionDateStr}',
          ].join('&');
          final queryStr = queryParams.isNotEmpty ? '?$queryParams' : '';
          context.go(
            '${RouteNames.checkinFormPath(widget.location.id)}$queryStr',
            extra: state.result,
          );
        },
      );
    }

    return AppButton.primary(
      label: 'Verifying GPS Location...',
      isLoading: isBusy,
      onPressed: null,
    );
  }
}

class _LocationRadarIndicator extends StatelessWidget {
  const _LocationRadarIndicator({
    required this.pulseController,
    required this.state,
  });

  final AnimationController pulseController;
  final LocationValidationState state;

  @override
  Widget build(BuildContext context) {
    final isSuccess = state is LocationValidationSuccess;
    final isError = state is LocationValidationOutsideRadius ||
        state is LocationValidationError;

    final primaryColor = isSuccess
        ? AppColors.success
        : isError
            ? AppColors.error
            : AppColors.primary;

    return Center(
      child: SizedBox(
        width: 140,
        height: 140,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer pulse circle
            if (!isSuccess && !isError)
              AnimatedBuilder(
                animation: pulseController,
                builder: (context, child) {
                  return Container(
                    width: 60 + (pulseController.value * 70),
                    height: 60 + (pulseController.value * 70),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryColor
                          .withAlpha((120 * (1 - pulseController.value)).toInt()),
                    ),
                  );
                },
              ),

            // Inner solid circle
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withAlpha(80),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: Icon(
                isSuccess
                    ? Icons.check_rounded
                    : isError
                        ? Icons.location_off_rounded
                        : Icons.my_location_rounded,
                color: Colors.white,
                size: 38,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
