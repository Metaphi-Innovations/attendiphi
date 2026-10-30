import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/config/environment.dart';
import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/config/supabase_app_config.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../../checkin/data/datasources/device_checkin_service.dart';
import '../../../checkin/domain/entities/check_in_submission.dart';
import '../../../checkin/presentation/screens/checkin_result_screen.dart';
import '../../../qr_checkin/domain/check_in_session_token.dart';
import '../../domain/entities/location_config.dart';
import '../../domain/usecases/validate_user_proximity.dart';
import '../providers/location_providers.dart';
import '../providers/location_validation_provider.dart';
import '../providers/location_validation_state.dart';

/// Screen managing GPS verification for a specific check-in location.
class LocationPermissionScreen extends ConsumerStatefulWidget {
  const LocationPermissionScreen({
    super.key,
    required this.location,
    this.adminId,
    this.sessionDateStr,
    this.sessionToken,
    this.nowProvider,
  });

  final LocationConfig location;
  final String? adminId;
  final String? sessionDateStr;

  /// Opaque `/checkin/<token>` segment when opened via the secure URL.
  final String? sessionToken;
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<LocationPermissionScreen> createState() =>
      _LocationPermissionScreenState();
}

class _LocationPermissionScreenState
    extends ConsumerState<LocationPermissionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _pulseController;
  bool _isCheckingDevice = true;
  bool _hasCheckedIn = false;
  CheckInSubmission? _existingSubmission;

  /// Robust extraction of session date query parameter across Native and Web.
  String? get _effectiveSessionDateStr {
    if (widget.sessionDateStr != null &&
        widget.sessionDateStr!.trim().isNotEmpty) {
      return widget.sessionDateStr!.trim();
    }
    if (kIsWeb) {
      if (Uri.base.queryParameters.containsKey('date')) {
        final val = Uri.base.queryParameters['date'];
        if (val != null && val.trim().isNotEmpty) return val.trim();
      }
      if (Uri.base.hasFragment && Uri.base.fragment.contains('date=')) {
        final fragIndex = Uri.base.fragment.indexOf('?');
        if (fragIndex != -1) {
          final queryStr = Uri.base.fragment.substring(fragIndex + 1);
          final parsed = Uri.splitQueryString(queryStr);
          if (parsed.containsKey('date') && parsed['date']!.trim().isNotEmpty) {
            return parsed['date']!.trim();
          }
        }
      }
    }
    return null;
  }

  DateTime? get _parsedSessionDate {
    final dateStr = _effectiveSessionDateStr;
    if (dateStr == null || dateStr.isEmpty) {
      return null;
    }
    return DateTime.tryParse(dateStr);
  }

  DateTime get _now =>
      widget.nowProvider != null ? widget.nowProvider!() : DateTime.now();

  bool get _isTodayThursday => _now.weekday == DateTime.thursday;

  bool get _isSessionExpired {
    final sessionDate = _parsedSessionDate;
    if (sessionDate == null) return false;
    final today = DateTime(_now.year, _now.month, _now.day);
    final sessionDay = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );
    return sessionDay.isBefore(today);
  }

  bool get _isSessionFuture {
    final sessionDate = _parsedSessionDate;
    if (sessionDate == null) return false;
    final today = DateTime(_now.year, _now.month, _now.day);
    final sessionDay = DateTime(
      sessionDate.year,
      sessionDate.month,
      sessionDate.day,
    );
    return sessionDay.isAfter(today);
  }

  bool _locationStarted = false;
  bool _gateApplied = false;
  bool _gateInFlight = false;

  /// Live Supabase venue when fetch succeeds; otherwise router / DefaultLocationX.
  LocationConfig get _displayLocation => _resolvedLocation ?? widget.location;
  LocationConfig? _resolvedLocation;

  bool get _showStagingGpsDebug =>
      kIsWeb && SupabaseAppConfig.environment == Environment.staging;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // After Deny → browser/app settings → Allow, retry automatically on return.
    if (state == AppLifecycleState.resumed && mounted) {
      final current = ref.read(
        locationValidationFamilyProvider(widget.location),
      );
      if (current is LocationValidationError) {
        _retryLocationPermission();
      }
    }
  }

  void _syncLiveVenue(LocationConfig live) {
    _resolvedLocation = live;
    ref
        .read(locationValidationFamilyProvider(widget.location).notifier)
        .applyLocation(live);
  }

  void _startLocationIfNeeded({bool force = false}) {
    if (!force && (_locationStarted || !mounted)) return;
    _locationStarted = true;
    if (!_pulseController.isAnimating) {
      _pulseController.repeat();
    }
    ref
        .read(locationValidationFamilyProvider(widget.location).notifier)
        .resetAndValidate();
  }

  void _retryLocationPermission() {
    if (!mounted) return;
    if (!_pulseController.isAnimating) {
      _pulseController.repeat();
    }
    // Retry must force a fresh live fix — do not reuse a failed/short cache.
    ref
        .read(locationValidationFamilyProvider(widget.location).notifier)
        .resetAndValidate(forceRefresh: true);
  }

  void _goToCheckInForm(ProximityResult proximity) {
    if (!mounted) return;
    // Device already checked in — never open the Member form.
    if (_hasCheckedIn) return;
    // Widget tests may mount without GoRouter; skip navigation then.
    if (GoRouter.maybeOf(context) == null) return;

    final venue = _displayLocation;
    final date = _effectiveSessionDateStr;
    var token = widget.sessionToken?.trim() ?? '';
    if (token.isEmpty && date != null && date.isNotEmpty) {
      try {
        token = CheckInSessionToken.create(
          locationId: venue.id,
          sessionDate: date,
          adminId: widget.adminId,
        );
      } catch (_) {
        token = '';
      }
    }

    if (token.isNotEmpty) {
      // Preferred: opaque path, no cleartext date/location in the URL.
      context.go(
        RouteNames.checkinFormPath(token),
        extra: {'proximity': proximity, 'location': venue},
      );
      return;
    }

    // Legacy fallback (no session date / token): keep locationId path.
    final queryParams = [
      if (widget.adminId != null && widget.adminId!.isNotEmpty)
        'adminId=${widget.adminId}',
      if (date != null && date.isNotEmpty) 'date=$date',
    ].join('&');
    final fullQuery = queryParams.isNotEmpty ? '?$queryParams' : '';
    context.go(
      '${RouteNames.checkinFormPath(venue.id)}$fullQuery',
      extra: {'proximity': proximity, 'location': venue},
    );
  }

  Future<void> _applyRestrictionsGate({
    required bool dateRestrictionEnabled,
    required bool deviceRestrictionEnabled,
  }) async {
    // Prevent overlapping applies (date-OFF listen re-fires while awaiting).
    if (_gateInFlight) return;
    _gateInFlight = true;
    try {
      // One device = one check-in: skip GPS + form; show first success screen.
      if (deviceRestrictionEnabled) {
        if (_hasCheckedIn) {
          _gateApplied = true;
          _isCheckingDevice = false;
          return;
        }
        final attendance = await ref
            .read(deviceCheckInServiceProvider)
            .resolveSessionAttendance(
              sessionDateStr: _effectiveSessionDateStr,
              locationId: widget.location.id,
            );
        if (!mounted) return;
        if (attendance.alreadyCheckedIn) {
          setState(() {
            _hasCheckedIn = true;
            _existingSubmission = attendance.submission;
            _isCheckingDevice = false;
            _gateApplied = true;
          });
          return;
        }
      }

      if (!dateRestrictionEnabled) {
        // Date gates off: any QR date / any weekday. Still fetch GPS (enforce
        // is controlled separately by locationRestrictionEnabledProvider).
        // Never wipe a device-restriction success hit on re-entry.
        if (!deviceRestrictionEnabled &&
            (_hasCheckedIn || _existingSubmission != null)) {
          setState(() {
            _hasCheckedIn = false;
            _existingSubmission = null;
            _isCheckingDevice = false;
            _gateApplied = true;
          });
        } else if (_isCheckingDevice || !_gateApplied) {
          setState(() {
            _isCheckingDevice = false;
            _gateApplied = true;
          });
        } else {
          _gateApplied = true;
        }
        _startLocationIfNeeded();
        return;
      }

      if (_gateApplied && !_isCheckingDevice) {
        // Already applied date gates for this visit.
        return;
      }

      // Date restriction ON: Thursday + session-day gates.
      // When device restriction is OFF, shared venue phones may check in many
      // members — do not redirect based on a prior device submission.
      if (!mounted) return;

      setState(() {
        if (!deviceRestrictionEnabled) {
          _hasCheckedIn = false;
          _existingSubmission = null;
        }
        _isCheckingDevice = false;
        _gateApplied = true;
      });

      final canStartLocation =
          _isTodayThursday && !_isSessionExpired && !_isSessionFuture;
      if (canStartLocation) {
        _startLocationIfNeeded();
      }
    } finally {
      _gateInFlight = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(checkInRestrictionsConfigProvider);
    final liveVenueAsync = ref.watch(
      locationConfigFamilyProvider(widget.location.id),
    );

    // Prefer live Supabase row for name/address/coords; keep router fallback.
    ref.listen(locationConfigFamilyProvider(widget.location.id), (prev, next) {
      next.whenData((live) {
        if (!mounted) return;
        final changed =
            _resolvedLocation == null ||
            _resolvedLocation!.name != live.name ||
            _resolvedLocation!.address != live.address ||
            _resolvedLocation!.latitude != live.latitude ||
            _resolvedLocation!.longitude != live.longitude;
        if (changed) {
          setState(() => _syncLiveVenue(live));
        } else {
          _syncLiveVenue(live);
        }
      });
    });
    liveVenueAsync.whenData((live) {
      if (_resolvedLocation == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _resolvedLocation != null) return;
          setState(() => _syncLiveVenue(live));
        });
      }
    });

    // Wait for live Super Admin toggle before enforcing date/device gates.
    ref.listen(checkInRestrictionsConfigProvider, (prev, next) {
      next.whenData((config) {
        final deviceChanged =
            prev?.asData?.value.deviceRestrictionEnabled !=
            config.deviceRestrictionEnabled;
        // Stay on Attendance Recorded once device restriction claimed a hit.
        if (_hasCheckedIn &&
            config.deviceRestrictionEnabled &&
            !deviceChanged) {
          return;
        }
        // Re-apply when date gates OFF (any-date unlock), first load, or
        // device policy flips.
        if (!config.dateRestrictionEnabled || !_gateApplied || deviceChanged) {
          _applyRestrictionsGate(
            dateRestrictionEnabled: config.dateRestrictionEnabled,
            deviceRestrictionEnabled: config.deviceRestrictionEnabled,
          );
        }
      });
    });

    if (configAsync.isLoading && !configAsync.hasValue) {
      return const Scaffold(body: Center(child: MetaPhiLoadingIndicator()));
    }

    final dateRestrictionEnabled = configAsync.maybeWhen(
      data: (config) => config.dateRestrictionEnabled,
      orElse: () => true,
    );
    final deviceRestrictionEnabled = configAsync.maybeWhen(
      data: (config) => config.deviceRestrictionEnabled,
      orElse: () => true,
    );

    // First emission after build: apply gates once config is known.
    if (!_gateApplied && configAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _gateApplied) return;
        _applyRestrictionsGate(
          dateRestrictionEnabled: dateRestrictionEnabled,
          deviceRestrictionEnabled: deviceRestrictionEnabled,
        );
      });
    }

    if (_hasCheckedIn || _existingSubmission != null) {
      return CheckInResultScreen(
        submission: _existingSubmission,
        memberId: _existingSubmission?.memberId,
        checkInId: _existingSubmission?.id,
      );
    }

    if (_isCheckingDevice) {
      return const Scaffold(body: Center(child: MetaPhiLoadingIndicator()));
    }

    final venue = _displayLocation;
    final validationState = ref.watch(
      locationValidationFamilyProvider(widget.location),
    );
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
          Future.delayed(const Duration(milliseconds: 300), () {
            if (!context.mounted) return;
            _goToCheckInForm(next.result);
          });
        }
      },
    );

    final isBusy =
        validationState is LocationValidationRequestingPermission ||
        validationState is LocationValidationFetchingPosition;

    // When date restriction OFF: PAST / UPCOMING / any weekday QR is allowed.
    final showNotThursday = dateRestrictionEnabled && !_isTodayThursday;
    final showExpired = dateRestrictionEnabled && _isSessionExpired;
    final showFuture = dateRestrictionEnabled && _isSessionFuture;

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
            child: showNotThursday
                ? _buildNotThursdayView(context)
                : showExpired
                ? _buildExpiredSessionView(
                    context,
                    _parsedSessionDate ?? DateTime.now(),
                  )
                : showFuture
                ? _buildFutureSessionView(
                    context,
                    _parsedSessionDate ?? DateTime.now(),
                  )
                : Column(
                    children: [
                      SizedBox(height: isCompact ? 10 : 20),

                      // 1. Animated Radar / Status Icon
                      _LocationRadarIndicator(
                        pulseController: _pulseController,
                        state: validationState,
                      ),

                      SizedBox(height: isCompact ? 20 : 32),

                      // 2. Venue Target Card (live Supabase when available)
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        venue.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      if (venue.address != null &&
                                          venue.address!.trim().isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          venue.address!,
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
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
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
                                    'Within ${venue.radiusMeters.round()} meters',
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

                      if (_showStagingGpsDebug) ...[
                        const SizedBox(height: 12),
                        _buildStagingGpsDebug(context, validationState),
                      ],

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

  Widget _buildStagingGpsDebug(
    BuildContext context,
    LocationValidationState state,
  ) {
    final theme = Theme.of(context);
    String detail = state.runtimeType.toString();
    if (state is LocationValidationError) {
      final ex = state.exception;
      final original = ex.originalError;
      final cause = original == null
          ? ''
          : ' · ${original.runtimeType}: $original';
      final tech = ex.technicalMessage.trim().isEmpty
          ? ''
          : ' · ${ex.technicalMessage}';
      detail =
          '${ex.runtimeType}: ${ErrorHandler.getUserMessage(ex)}$tech$cause';
    }
    return Text(
      'staging · web · venue=${_displayLocation.name} · $detail',
      style: theme.textTheme.labelSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontFamily: 'monospace',
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildExpiredSessionView(BuildContext context, DateTime sessionDate) {
    final theme = Theme.of(context);
    final isCompact = context.isCompactMobile;
    final isDark = theme.brightness == Brightness.dark;
    final formattedSessionDate = DateFormat('EEEE, dd MMMM yyyy')
        .format(sessionDate);
    final formattedToday = DateFormat('EEEE, dd MMMM yyyy')
        .format(DateTime.now());

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
    final formattedSessionDate = DateFormat('EEEE, dd MMMM yyyy')
        .format(sessionDate);

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
              Icon(
                Icons.lock_clock_rounded,
                size: 12,
                color: Color(0xFFD97706),
              ),
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
      final isPermissionDeny =
          state.exception is LocationPermissionDeniedException ||
          state.exception is LocationPermissionPermanentlyDeniedException;
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorLight.withAlpha(40),
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: AppColors.error),
        ),
        child: Column(
          children: [
            Text(
              ErrorHandler.getUserMessage(state.exception),
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
            if (isPermissionDeny && kIsWeb) ...[
              const SizedBox(height: 10),
              Text(
                AppStrings.locationPermissionWebHelp,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      );
    }

    return Text(
      state is LocationValidationFetchingPosition
          ? AppStrings.locationFetchingPosition
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
    // Web cannot re-open the browser location prompt or site settings after
    // Deny — hide dead Allow Location / Open Settings actions.
    if (state is LocationValidationError &&
        (state.exception is LocationPermissionDeniedException ||
            state.exception is LocationPermissionPermanentlyDeniedException)) {
      return const SizedBox.shrink();
    }

    if (state is LocationValidationOutsideRadius ||
        state is LocationValidationError) {
      return AppButton.primary(
        label: AppStrings.locationRetry,
        icon: Icons.refresh_rounded,
        onPressed: _retryLocationPermission,
      );
    }

    if (state is LocationValidationSuccess) {
      return AppButton.primary(
        label: 'Continue to Check-In',
        icon: Icons.arrow_forward_rounded,
        onPressed: () => _goToCheckInForm(state.result),
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
    final isError =
        state is LocationValidationOutsideRadius ||
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
                      color: primaryColor.withAlpha(
                        (120 * (1 - pulseController.value)).toInt(),
                      ),
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
