import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_radius.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../../employee/domain/employee_lookup.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../../data/datasources/device_checkin_service.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/check_in_type.dart';
import '../providers/checkin_providers.dart';
import '../widgets/gpay_success_animation.dart';

/// Simplified check-in completion screen.
///
/// Hydrates name / phone / type from (1) [submission] extra, (2) public
/// `checkInId` RPC, (3) local device session, (4) public member roster.
class CheckInResultScreen extends ConsumerStatefulWidget {
  const CheckInResultScreen({
    super.key,
    this.submission,
    this.memberId,
    this.checkInId,
  });

  final CheckInSubmission? submission;

  /// Authoritative member document id for this check-in. Preferred over names.
  final String? memberId;

  /// Check-in document id for this submission (URL query after refresh/paste).
  final String? checkInId;

  @override
  ConsumerState<CheckInResultScreen> createState() =>
      _CheckInResultScreenState();
}

class _CheckInResultScreenState extends ConsumerState<CheckInResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cardFadeController;
  late final Animation<double> _cardFadeAnimation;
  late final Animation<Offset> _cardSlideAnimation;
  CheckInSubmission? _resolvedSubmission;
  bool _hydrating = false;

  @override
  void initState() {
    super.initState();
    _resolvedSubmission = widget.submission;

    _cardFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _cardFadeAnimation = CurvedAnimation(
      parent: _cardFadeController,
      curve: Curves.easeOut,
    );

    _cardSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.15), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _cardFadeController,
            curve: Curves.easeOutCubic,
          ),
        );

    _cardFadeController.forward();

    if (widget.submission == null) {
      _hydrating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hydrateSubmission();
      });
    }
  }

  @override
  void dispose() {
    _cardFadeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CheckInResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.submission != null &&
        (widget.submission?.id != oldWidget.submission?.id ||
            widget.submission?.memberId != oldWidget.submission?.memberId ||
            widget.memberId != oldWidget.memberId)) {
      _resolvedSubmission = widget.submission;
      _hydrating = false;
    } else if (widget.submission == null &&
        (widget.checkInId != oldWidget.checkInId ||
            widget.memberId != oldWidget.memberId) &&
        _resolvedSubmission == null &&
        !_hydrating) {
      _hydrating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _hydrateSubmission();
      });
    }
  }

  Future<void> _hydrateSubmission() async {
    if (!mounted) return;

    // 1. Already have payload from GoRouter extra / parent.
    if (widget.submission != null) {
      setState(() {
        _resolvedSubmission = widget.submission;
        _hydrating = false;
      });
      return;
    }

    final checkInId = widget.checkInId?.trim() ?? '';
    final memberId = widget.memberId?.trim() ?? '';

    // 2. Public SECURITY DEFINER summary by check-in id (refresh / paste URL).
    if (checkInId.isNotEmpty) {
      try {
        final remote = ref.read(checkInRemoteDataSourceProvider);
        final fromRpc = await remote.getPublicCheckInSummary(checkInId);
        if (!mounted) return;
        if (fromRpc != null) {
          await ref
              .read(deviceCheckInServiceProvider)
              .recordSubmission(submission: fromRpc);
          if (!mounted) return;
          setState(() {
            _resolvedSubmission = fromRpc;
            _hydrating = false;
          });
          return;
        }
      } catch (e) {
        AppLogger.warning(
          'Result hydrate via checkInId failed: $e',
          tag: 'CheckInResultScreen',
        );
      }
    }

    // 3. Local device session / last submission (same browser, empty extra).
    try {
      final device = ref.read(deviceCheckInServiceProvider);
      CheckInSubmission? local = await device.getLastSubmission();
      if (local != null && checkInId.isNotEmpty && local.id != checkInId) {
        // Prefer matching id when URL specifies one.
        local = null;
      }
      local ??= await device.getSubmissionForSession(probeServer: true);
      if (!mounted) return;
      if (local != null) {
        final matchesMember =
            memberId.isEmpty ||
            (local.memberId?.trim().isNotEmpty == true &&
                local.memberId!.trim() == memberId);
        final matchesId = checkInId.isEmpty || local.id == checkInId;
        if (matchesMember || matchesId) {
          setState(() {
            _resolvedSubmission = local;
            _hydrating = false;
          });
          return;
        }
      }
    } catch (e) {
      AppLogger.warning(
        'Result hydrate via device storage failed: $e',
        tag: 'CheckInResultScreen',
      );
    }

    if (!mounted) return;
    setState(() => _hydrating = false);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactMobile;
    final submission = _resolvedSubmission ?? widget.submission;
    final memberId = (widget.memberId ?? submission?.memberId)?.trim() ?? '';
    Employee? authoritativeMember;
    if (memberId.isNotEmpty) {
      authoritativeMember = ref
          .watch(employeeByIdProvider(memberId))
          .asData
          ?.value;
    }
    final employees =
        ref.watch(publicMembersStreamProvider).asData?.value ??
        const <Employee>[];
    final displayName =
        EmployeeLookup.successDisplayName(
          submission: submission,
          employees: employees,
          memberId: memberId,
          authoritativeMember: authoritativeMember,
        ) ??
        '';
    final displayPhone =
        EmployeeLookup.successDisplayPhone(
          submission: submission,
          employees: employees,
          memberId: memberId,
          authoritativeMember: authoritativeMember,
        ) ??
        '';
    final typeLabel =
        submission?.type.displayName ??
        (memberId.isNotEmpty ? CheckInType.member.displayName : '');

    final showIdentity =
        displayName.isNotEmpty ||
        displayPhone.isNotEmpty ||
        (submission != null && typeLabel.isNotEmpty);

    // While hydrating with known IDs, avoid a permanent blank identity card.
    final awaitingIdentity =
        _hydrating &&
        submission == null &&
        displayName.isEmpty &&
        ((widget.checkInId?.trim().isNotEmpty ?? false) ||
            memberId.isNotEmpty);

    final hPadding = context.responsiveValue<double>(
      compactMobile: 16.0,
      mobile: 20.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    return AppScaffold(
      showBackButton: false,
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: hPadding,
            vertical: isCompact ? 24 : 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ResponsiveBreakpoints.maxCardWidth,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GPaySuccessAnimation(size: isCompact ? 72 : 90),

                SizedBox(height: isCompact ? 20 : 28),

                FadeTransition(
                  opacity: _cardFadeAnimation,
                  child: SlideTransition(
                    position: _cardSlideAnimation,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 22,
                        vertical: isCompact ? 18 : 24,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F9D58).withAlpha(18),
                        borderRadius: AppRadius.lgAll,
                        border: Border.all(
                          color: const Color(0xFF0F9D58).withAlpha(70),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F9D58).withAlpha(15),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF0F9D58),
                                size: 24,
                              ),
                              SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Attendance Recorded',
                                  style: TextStyle(
                                    color: Color(0xFF0F9D58),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16.5,
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (awaitingIdentity) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: MetaPhiLoadingIndicator(),
                            ),
                            const SizedBox(height: 8),
                          ] else if (showIdentity) ...[
                            if (displayName.isNotEmpty) ...[
                              Text(
                                displayName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF0F172A),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 4),
                            ],
                            Text(
                              [
                                if (displayPhone.isNotEmpty) displayPhone,
                                if (typeLabel.isNotEmpty) typeLabel,
                              ].join(' • '),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 14),
                          ],
                          Text(
                            'Your attendance has been recorded in the system.\nYou may now safely close this browser window.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant
                                  .withAlpha(220),
                              height: 1.4,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
