import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


import '../../../../app/theme/app_radius.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../data/datasources/device_checkin_service.dart';
import '../../domain/entities/check_in_submission.dart';
import '../widgets/gpay_success_animation.dart';

/// Simplified check-in completion screen.
class CheckInResultScreen extends ConsumerStatefulWidget {
  const CheckInResultScreen({
    super.key,
    this.submission,
  });

  final CheckInSubmission? submission;

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

    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardFadeController,
      curve: Curves.easeOutCubic,
    ));

    // If submission is null, load the last recorded submission from device storage
    if (_resolvedSubmission == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final deviceService = ref.read(deviceCheckInServiceProvider);
        final last = await deviceService.getLastSubmission();
        if (mounted && last != null) {
          setState(() => _resolvedSubmission = last);
        }
      });
    }

    // Stagger the card slide-in after the celebration burst
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _cardFadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _cardFadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = context.isCompactMobile;
    final submission = _resolvedSubmission ?? widget.submission;

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
                // 1. Google Pay Celebration Animation
                GPaySuccessAnimation(size: isCompact ? 72 : 90),

                SizedBox(height: isCompact ? 20 : 28),

                // 2. Attendance Recorded Card
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
                          if (submission != null) ...[
                            Text(
                              submission.userName,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0F172A),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${submission.userPhone} • ${submission.type.displayName}',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
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

