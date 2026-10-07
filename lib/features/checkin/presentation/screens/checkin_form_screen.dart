import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router/route_names.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/errors/error_handler.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/responsive/responsive_breakpoints.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/metaphi_loading_indicator.dart';
import '../../../app_config/presentation/providers/check_in_restrictions_provider.dart';
import '../../../employee/domain/employee_lookup.dart';
import '../../../employee/domain/entities/employee.dart';
import '../../../employee/presentation/providers/employee_providers.dart';
import '../../../location/domain/entities/location_config.dart';
import '../../../location/domain/usecases/validate_user_proximity.dart';
import '../../../location/presentation/providers/location_providers.dart';
import '../../data/datasources/device_checkin_service.dart';
import '../../domain/entities/check_in_submission.dart';
import '../../domain/entities/check_in_type.dart';
import '../providers/checkin_form_provider.dart';
import '../providers/checkin_form_state.dart';
import 'checkin_result_screen.dart';

/// Clean, light-themed attendance check-in form supporting Member, Substitute, and Visitor workflows.
/// Member identity is manual (dropdown + autofill). Substitute still captures a face photo.
class CheckInFormScreen extends ConsumerStatefulWidget {
  const CheckInFormScreen({
    super.key,
    required this.locationId,
    this.initialLocation,
    this.proximityResult,
    this.adminId,
    this.sessionDateStr,
    this.nowProvider,
  });

  final String locationId;
  final LocationConfig? initialLocation;
  final ProximityResult? proximityResult;
  final String? adminId;
  final String? sessionDateStr;
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<CheckInFormScreen> createState() => _CheckInFormScreenState();
}

class _CheckInFormScreenState extends ConsumerState<CheckInFormScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Robust extraction of session date query parameter across Native and Web.
  String? get _effectiveSessionDateStr {
    if (widget.sessionDateStr != null && widget.sessionDateStr!.trim().isNotEmpty) {
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

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _categoryController;

  // Search controllers for Substitute / Visitor dropdowns
  late final TextEditingController _substituteForSearchController;
  late final TextEditingController _invitedBySearchController;

  final FocusNode _memberNameFocusNode = FocusNode();
  final ScrollController _formScrollController = ScrollController();
  final GlobalKey _memberNameFieldKey = GlobalKey();

  bool _showMemberSuggestions = false;
  bool _isSubstituteForDropdownOpen = false;
  bool _isInvitedByDropdownOpen = false;

  String _substituteForSearchQuery = '';
  String _invitedBySearchQuery = '';

  String? _selectedSubstituteForMember;
  String? _selectedInvitedByMember;

  bool _isCheckingDevice = true;
  bool _hasCheckedIn = false;
  CheckInSubmission? _existingSubmission;

  /// Member selected from the typeahead list (manual check-in only).
  Employee? _manuallySelectedMember;

  void _clearLocalIdentity() {
    _manuallySelectedMember = null;
    _showMemberSuggestions = false;
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
  }

  void _onMemberNameFocusChanged() {
    if (_memberNameFocusNode.hasFocus) {
      setState(() => _showMemberSuggestions = true);
      _scrollMemberFieldIntoView();
    } else {
      // Delay close so a suggestion tap can register first.
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        if (!mounted || _memberNameFocusNode.hasFocus) return;
        setState(() => _showMemberSuggestions = false);
      });
    }
  }

  void _scrollMemberFieldIntoView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _memberNameFieldKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.05,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
        return;
      }
      if (_formScrollController.hasClients) {
        _formScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    // Warm up employee / member list in memory so dropdown opens instantly
    ref.read(employeesStreamProvider);

    // Always start this QR scan with empty identity fields so the previous
    // member on a shared device cannot leak into the next check-in.
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _companyController = TextEditingController();
    _categoryController = TextEditingController();

    _substituteForSearchController = TextEditingController();
    _invitedBySearchController = TextEditingController();
    _memberNameFocusNode.addListener(_onMemberNameFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(checkInFormProvider.notifier);
      notifier.reset();
      notifier.clearIdentity();
      // Member is the default check-in type on every fresh QR session.
      notifier.setType(CheckInType.member);
      if (widget.adminId != null && widget.adminId!.isNotEmpty) {
        notifier.setAdminId(widget.adminId);
      }
      setState(_clearLocalIdentity);
      // Device gate runs from build once restrictions config is ready.
    });
  }

  /// True when required fields for the active type are complete.
  bool _canSubmit(CheckInFormState formState) {
    if (formState.isSubmitting) return false;
    final type = formState.type;
    if (type == null) return false;

    switch (type) {
      case CheckInType.member:
        return _manuallySelectedMember != null &&
            Validators.validatePhone(_phoneController.text) == null;
      case CheckInType.substitute:
        return Validators.validateName(_nameController.text) == null &&
            Validators.validatePhone(_phoneController.text) == null &&
            (_selectedSubstituteForMember?.trim().isNotEmpty ?? false) &&
            formState.hasPhoto;
      case CheckInType.visitor:
        final category = _categoryController.text.trim();
        return Validators.validateName(_nameController.text) == null &&
            Validators.validatePhone(_phoneController.text) == null &&
            Validators.validateEmail(_emailController.text) == null &&
            _companyController.text.trim().isNotEmpty &&
            category.length >= 4 &&
            (_selectedInvitedByMember?.trim().isNotEmpty ?? false);
      case CheckInType.absent:
      case CheckInType.notCheckedIn:
        return false;
    }
  }

  Future<void> _applyDeviceGate({required bool restrictionsEnabled}) async {
    if (!restrictionsEnabled) {
      if (!mounted) return;
      setState(() {
        _hasCheckedIn = false;
        _existingSubmission = null;
        _isCheckingDevice = false;
      });
      return;
    }

    final deviceService = ref.read(deviceCheckInServiceProvider);
    final hasCheckedIn = await deviceService.hasCheckedInForSession(
      sessionDateStr: _effectiveSessionDateStr,
      locationId: widget.locationId,
    );

    if (!mounted) return;

    if (hasCheckedIn) {
      final existingSubmission = await deviceService.getSubmissionForSession(
        sessionDateStr: _effectiveSessionDateStr,
        locationId: widget.locationId,
      );
      if (!mounted) return;
      setState(() {
        _hasCheckedIn = true;
        _existingSubmission = existingSubmission;
        _isCheckingDevice = false;
      });
      _goToCheckInResult(existingSubmission);
      return;
    }

    setState(() {
      _isCheckingDevice = false;
    });
  }

  @override
  void dispose() {
    _memberNameFocusNode.removeListener(_onMemberNameFocusChanged);
    _memberNameFocusNode.dispose();
    _formScrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _categoryController.dispose();
    _substituteForSearchController.dispose();
    _invitedBySearchController.dispose();
    super.dispose();
  }

  void _onTypeChanged(CheckInType newType) {
    // 1. Clear all local text controllers
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _companyController.clear();
    _categoryController.clear();
    _substituteForSearchController.clear();
    _invitedBySearchController.clear();
    _memberNameFocusNode.unfocus();

    // 2. Clear state variables
    setState(() {
      _selectedSubstituteForMember = null;
      _selectedInvitedByMember = null;
      _substituteForSearchQuery = '';
      _invitedBySearchQuery = '';
      _showMemberSuggestions = false;
      _isSubstituteForDropdownOpen = false;
      _isInvitedByDropdownOpen = false;
      _manuallySelectedMember = null;
    });

    // 3. Reset form notifier state
    final notifier = ref.read(checkInFormProvider.notifier);
    notifier.setName('');
    notifier.setPhone('');
    notifier.setEmail('');
    notifier.setCompanyName('');
    notifier.setCategory('');
    notifier.setSubstituteForMember(null);
    notifier.setInvitedByMember(null);
    notifier.clearPhoto();
    notifier.clearIdentity();
    notifier.setType(newType);
    if (widget.adminId != null && widget.adminId!.isNotEmpty) {
      notifier.setAdminId(widget.adminId);
    }
  }

  void _goToCheckInResult(CheckInSubmission? submission) {
    if (!mounted) return;
    context.go(
      RouteNames.checkinResultPath(
        checkInId: submission?.id,
        memberId: submission?.memberId,
      ),
      extra: submission,
    );
  }

  Future<Employee> _authoritativeMember(Employee selected) async {
    final employees =
        ref.read(employeesStreamProvider).asData?.value ?? const <Employee>[];
    return EmployeeLookup.byId(employees, selected.id) ?? selected;
  }

  void _openCamera() {
    context.push(RouteNames.photoCapturePath(widget.locationId));
  }

  Future<void> _onSubmit(LocationConfig location, ProximityResult proximity) async {
    final restrictionsEnabled = ref.read(restrictionsEnabledProvider);
    if (restrictionsEnabled) {
      final deviceService = ref.read(deviceCheckInServiceProvider);
      final hasCheckedIn = await deviceService.hasCheckedInForSession(
        sessionDateStr: _effectiveSessionDateStr,
        locationId: widget.locationId,
        probeServer: true,
      );
      if (!mounted) return;
      if (hasCheckedIn) {
        final existingSubmission = await deviceService.getSubmissionForSession(
          sessionDateStr: _effectiveSessionDateStr,
          locationId: widget.locationId,
          probeServer: false,
        );
        if (!mounted) return;
        _goToCheckInResult(existingSubmission);
        return;
      }
    }

    final formState = ref.read(checkInFormProvider);
    final currentType = formState.type;
    if (currentType == null) {
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Type-specific validations
    if (currentType == CheckInType.member) {
      if (_manuallySelectedMember == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select your name from the member list before checking in.',
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    if (currentType == CheckInType.substitute) {
      if (_selectedSubstituteForMember == null || _selectedSubstituteForMember!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select which Member you are substituting for.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      if (!formState.hasPhoto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(AppStrings.validationPhotoRequired),
            backgroundColor: AppColors.error,
          ),
        );
        _openCamera();
        return;
      }
    }

    if (currentType == CheckInType.visitor) {
      if (_selectedInvitedByMember == null || _selectedInvitedByMember!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select which Member invited you.'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
    }

    // Sync controllers and type to provider state. Member identity is taken
    // from the selected member dropdown, not from typed or cached names.
    final notifier = ref.read(checkInFormProvider.notifier);
    notifier.setType(currentType);
    final selectedMember =
        currentType == CheckInType.member ? _manuallySelectedMember : null;
    if (selectedMember != null &&
        (formState.recognizedMemberId ?? '') != selectedMember.id) {
      final live = await _authoritativeMember(selectedMember);
      if (!mounted) return;
      notifier.setName(live.name.trim());
      notifier.setPhone(live.phone.trim());
      notifier.setEmail(live.email.trim());
      notifier.setRecognizedMember(live.id);
      if ((live.adminId ?? '').trim().isNotEmpty) {
        notifier.setAdminId(live.adminId);
      }
    } else if (selectedMember == null) {
      notifier.setName(_nameController.text.trim());
      notifier.setPhone(_phoneController.text.trim());
      notifier.setEmail(_emailController.text.trim());
    }
    notifier.setCompanyName(_companyController.text.trim());
    notifier.setCategory(_categoryController.text.trim());
    notifier.setSubstituteForMember(_selectedSubstituteForMember);
    notifier.setInvitedByMember(_selectedInvitedByMember);

    final success = await notifier.submit(
      location: location,
      proximityResult: proximity,
      sessionDateStr: _effectiveSessionDateStr,
    );

    if (success && mounted) {
      final submission = ref.read(checkInFormProvider).submissionResult;
      _nameController.clear();
      _phoneController.clear();
      _emailController.clear();
      _companyController.clear();
      _categoryController.clear();
      notifier.reset();
      _goToCheckInResult(submission);
    } else if (!success && mounted) {
      final formState = ref.read(checkInFormProvider);
      final error = formState.error;
      if (error != null) {
        if (error is DuplicateCheckInException) {
          final existing = formState.submissionResult;
          if (existing != null) {
            ref.read(deviceCheckInServiceProvider).recordSubmission(
              sessionDateStr: _effectiveSessionDateStr,
              submission: existing,
            );
          }
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 24),
                  SizedBox(width: 10),
                  Text(
                    'Already Responded',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: const Text(
                'You have already submitted your attendance for this date.\n\nOnly one submission is allowed per device and attendee.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              actions: [
                FilledButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _goToCheckInResult(existing);
                  },
                  child: const Text('View Response'),
                ),
              ],
            ),
          );
          return;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorHandler.getUserMessage(error)),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(checkInRestrictionsConfigProvider);

    ref.listen(checkInRestrictionsConfigProvider, (prev, next) {
      next.whenData((config) {
        if (!config.restrictionsEnabled) {
          _applyDeviceGate(restrictionsEnabled: false);
        } else if (_isCheckingDevice) {
          _applyDeviceGate(restrictionsEnabled: true);
        }
      });
    });

    if (configAsync.isLoading && !configAsync.hasValue) {
      return const Scaffold(
        body: Center(child: MetaPhiLoadingIndicator()),
      );
    }

    final restrictionsEnabled = configAsync.maybeWhen(
      data: (config) => config.restrictionsEnabled,
      orElse: () => true,
    );

    if (_isCheckingDevice && configAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isCheckingDevice) return;
        _applyDeviceGate(restrictionsEnabled: restrictionsEnabled);
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
      return const Scaffold(
        body: Center(
          child: MetaPhiLoadingIndicator(),
        ),
      );
    }

    if (restrictionsEnabled && !_isTodayThursday) {
      return AppScaffold(
        title: AppStrings.checkInFormTitle,
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ResponsiveBreakpoints.maxFormWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_busy_rounded,
                      color: Color(0xFFD97706),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Check-In Available on Thursday Only',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Member and substitute check-in is permitted only on Thursdays. Attendance submissions are closed today.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // When restrictions OFF: past / future QR dates are accepted.
    if (restrictionsEnabled && _isSessionExpired) {
      final formattedSessionDate =
          DateFormat('EEEE, dd MMMM yyyy').format(_parsedSessionDate!);
      return AppScaffold(
        title: AppStrings.checkInFormTitle,
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ResponsiveBreakpoints.maxFormWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: AppColors.error.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.timer_off_rounded,
                      color: AppColors.error,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Session Expired',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This QR standee was only valid for the Thursday meeting on $formattedSessionDate. Attendance submissions are now closed.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (restrictionsEnabled && _isSessionFuture) {
      final formattedSessionDate =
          DateFormat('EEEE, dd MMMM yyyy').format(_parsedSessionDate!);
      return AppScaffold(
        title: AppStrings.checkInFormTitle,
        backgroundColor: const Color(0xFFF8FAFC),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: ResponsiveBreakpoints.maxFormWidth,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: Color(0xFF6366F1),
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Session Not Active Yet',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This QR standee is scheduled for $formattedSessionDate. Check-in opens on the day of the session at 00:00.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF64748B),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Keep employee list stream hot and cached in memory
    ref.watch(employeesStreamProvider);
    final formState = ref.watch(checkInFormProvider);
    final locationAsync = ref.watch(locationConfigFamilyProvider(widget.locationId));
    final isCompact = context.isCompactMobile;
    final currentType = formState.type;

    final hPadding = context.responsiveValue<double>(
      compactMobile: 12.0,
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );

    const defaultLocation = LocationConfig(
      id: 'location_x',
      name: 'Jade Luxury Banquets, Mumbai',
      latitude: 18.9888622,
      longitude: 72.8152475,
      radiusMeters: 500.0,
      isActive: true,
      address: 'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
    );
    final location = widget.initialLocation ??
        locationAsync.asData?.value ??
        defaultLocation;

    final proximity = widget.proximityResult ??
        ProximityResult(
          distanceMeters: 10.0,
          isWithinRadius: true,
          allowedRadiusMeters: location.radiusMeters,
          userLatitude: location.latitude,
          userLongitude: location.longitude,
          gpsAccuracy: 5.0,
        );
    final canSubmit = _canSubmit(formState);

    return AppScaffold(
      title: AppStrings.checkInFormTitle,
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
              // Scrollable Form Content (Top-aligned, identical padding across all 3 states)
              Expanded(
                child: SingleChildScrollView(
                  controller: _formScrollController,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: EdgeInsets.fromLTRB(
                    hPadding,
                    isCompact ? 16 : 24,
                    hPadding,
                    // Extra space so suggestions can scroll above the keyboard.
                    (isCompact ? 16 : 24) +
                        MediaQuery.viewInsetsOf(context).bottom +
                        (_showMemberSuggestions ? 160 : 0),
                  ),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: ResponsiveBreakpoints.maxFormWidth,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // 1. Top Check-in Type Selector (Member, Substitute, Visitor)
                            const Text(
                              'Check-In Type',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 10),
                            _CheckInTypeSelector(
                              selectedType: currentType,
                              onChanged: _onTypeChanged,
                            ),
                            const SizedBox(height: 20),

                            // 3. Dynamic Form Fields based on Type
                            if (currentType == CheckInType.member) ...[
                              _buildMemberFormFields(),
                            ] else if (currentType == CheckInType.substitute) ...[
                              _buildSubstituteFormFields(formState),
                            ] else if (currentType == CheckInType.visitor) ...[
                              _buildVisitorFormFields(),
                            ],

                            // Error message if any
                            if (formState.error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: AppColors.errorLight.withAlpha(40),
                                  borderRadius: AppRadius.mdAll,
                                  border: Border.all(color: AppColors.error),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppColors.error,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        ErrorHandler.getUserMessage(formState.error!),
                                        style: const TextStyle(
                                          color: AppColors.error,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Sticky Submit Button — hide while Member suggestions are open
              // so the keyboard + list stay usable on mobile web.
              if (currentType != null && !_showMemberSuggestions) ...[
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: hPadding,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: const Border(
                    top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(8),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: ResponsiveBreakpoints.maxFormWidth,
                    ),
                    child: AppButton.primary(
                      label: formState.isSubmitting
                          ? AppStrings.checkInSubmitting
                          : 'Check-In',
                      icon: Icons.how_to_reg_rounded,
                      isLoading: formState.isSubmitting,
                      enabled: canSubmit,
                      onPressed: canSubmit
                          ? () => _onSubmit(location, proximity)
                          : null,
                    ),
                  ),
                ),
              ),
              ],
            ],
          ),
    );
  }


  // ==========================================
  // Persistent Field Label with Red Asterisk
  // ==========================================
  Widget _buildFieldLabel(String title, {bool isRequired = false, String? suffix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: title,
          style: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
          children: [
            if (isRequired)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            if (suffix != null)
              TextSpan(
                text: suffix,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Helper: Phone Input Prefix (+91 displayed continuously)
  // ==========================================
  Widget _buildPhonePrefix() {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_rounded, size: 20),
          const SizedBox(width: 8),
          const Text(
            '+91',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 16,
            width: 1,
            color: const Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }



  // ==========================================
  // 1. MEMBER FORM FIELDS (typeahead name + autofill phone)
  // ==========================================
  Widget _buildMemberFormFields() {
    final query = _nameController.text.trim();
    final hasQuery = query.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFieldLabel('Select Member Name', isRequired: true),
        KeyedSubtree(
          key: _memberNameFieldKey,
          child: AppTextField(
            hint: 'Type to search your name',
            showFloatingLabel: false,
            controller: _nameController,
            focusNode: _memberNameFocusNode,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            prefixIcon: const Icon(Icons.person_outline_rounded),
            suffixIcon: hasQuery
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 22),
                    tooltip: 'Clear',
                    onPressed: () {
                      _nameController.clear();
                      _phoneController.clear();
                      _emailController.clear();
                      final notifier = ref.read(checkInFormProvider.notifier);
                      notifier.clearIdentity();
                      if (widget.adminId != null && widget.adminId!.isNotEmpty) {
                        notifier.setAdminId(widget.adminId);
                      }
                      setState(() {
                        _manuallySelectedMember = null;
                        _showMemberSuggestions = true;
                      });
                      _memberNameFocusNode.requestFocus();
                      _scrollMemberFieldIntoView();
                    },
                  )
                : IconButton(
                    icon: Icon(
                      _showMemberSuggestions
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.arrow_drop_down_rounded,
                      size: 28,
                      color: _showMemberSuggestions
                          ? AppColors.primary
                          : const Color(0xFF64748B),
                    ),
                    tooltip: _showMemberSuggestions ? 'Hide list' : 'Show members',
                    onPressed: () {
                      if (_showMemberSuggestions) {
                        _memberNameFocusNode.unfocus();
                        setState(() => _showMemberSuggestions = false);
                      } else {
                        _memberNameFocusNode.requestFocus();
                        setState(() => _showMemberSuggestions = true);
                        _scrollMemberFieldIntoView();
                      }
                    },
                  ),
            onChanged: (val) {
              final selected = _manuallySelectedMember;
              final stillMatches = selected != null &&
                  selected.name.trim().toLowerCase() == val.trim().toLowerCase();
              setState(() {
                _showMemberSuggestions = true;
                if (!stillMatches) {
                  _manuallySelectedMember = null;
                  _phoneController.clear();
                  _emailController.clear();
                  final notifier = ref.read(checkInFormProvider.notifier);
                  notifier.setName(val);
                  notifier.setPhone('');
                  notifier.setEmail('');
                  notifier.setRecognizedMember(null);
                }
              });
              _scrollMemberFieldIntoView();
            },
            validator: (_) {
              if (_manuallySelectedMember == null) {
                return 'Please select your name from the member list';
              }
              return null;
            },
          ),
        ),
        if (_showMemberSuggestions) ...[
          const SizedBox(height: 8),
          _buildMemberSuggestionsPanel(query: query),
        ],
        const SizedBox(height: 18),
        _buildFieldLabel('Phone Number', isRequired: true, suffix: ' (Auto-filled)'),
        AppTextField(
          hint: '10-digit mobile number',
          showFloatingLabel: false,
          controller: _phoneController,
          enabled: false,
          keyboardType: TextInputType.phone,
          prefixIcon: _buildPhonePrefix(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: Validators.validatePhone,
        ),
      ],
    );
  }

  /// Inline member suggestions under the name field (no nested search bar).
  Widget _buildMemberSuggestionsPanel({required String query}) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Keep ~2–3 rows visible above the soft keyboard on mobile web.
    final availableAboveKeyboard = keyboardInset > 0
        ? (screenHeight - keyboardInset) * 0.42
        : 220.0;
    final maxHeight = availableAboveKeyboard.clamp(132.0, 220.0);

    return Material(
      color: Colors.white,
      borderRadius: AppRadius.mdAll,
      elevation: 4,
      shadowColor: Colors.black.withAlpha(30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: AppColors.primary.withAlpha(90),
            width: 1.5,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Consumer(
            builder: (context, ref, _) {
              final employeesAsync = ref.watch(employeesStreamProvider);

              return employeesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: Text(
                      'Error loading names: $e',
                      style: const TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
                ),
                data: (allEmployees) {
                  final scopedEmployees = EmployeeLookup.scoped(
                    employees: allEmployees,
                    adminId: widget.adminId,
                    activeOnly: true,
                  );

                  final q = query.toLowerCase();
                  final filtered = q.isEmpty
                      ? scopedEmployees
                      : scopedEmployees
                          .where((emp) {
                            final name = emp.name.toLowerCase();
                            final phone = emp.phone.toLowerCase();
                            return name.contains(q) || phone.contains(q);
                          })
                          .toList();

                  if (filtered.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'No matching members found',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final emp = filtered[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(25),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            size: 16,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          emp.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        subtitle: emp.phone.isNotEmpty
                            ? Text(
                                emp.phone,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF64748B),
                                ),
                              )
                            : null,
                        trailing: const Icon(
                          Icons.north_west_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        onTap: () => _selectMemberFromSuggestions(emp),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _selectMemberFromSuggestions(Employee emp) {
    _nameController.text = emp.name;
    _phoneController.text = emp.phone;
    _emailController.text = emp.email;

    final notifier = ref.read(checkInFormProvider.notifier);
    notifier.setName(emp.name);
    notifier.setPhone(emp.phone);
    notifier.setEmail(emp.email);
    notifier.setAdminId(emp.adminId ?? widget.adminId);
    notifier.setRecognizedMember(emp.id);
    notifier.clearPhoto();

    setState(() {
      _manuallySelectedMember = emp;
      _showMemberSuggestions = false;
    });
    _memberNameFocusNode.unfocus();
  }

  // ==========================================
  // 2. SUBSTITUTE FORM FIELDS (Name + Phone + Email optional + Substituting For Member + Photo)
  // ==========================================
  Widget _buildSubstituteFormFields(CheckInFormState formState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Substitute Full Name
        _buildFieldLabel('Substitute Full Name', isRequired: true),
        AppTextField(
          hint: 'Enter your full name',
          showFloatingLabel: false,
          controller: _nameController,
          prefixIcon: const Icon(Icons.person_rounded),
          textCapitalization: TextCapitalization.words,
          validator: Validators.validateName,
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setName(val);
          },
        ),

        const SizedBox(height: 18),

        // Substitute Phone Number (+91)
        _buildFieldLabel('Phone Number', isRequired: true),
        AppTextField(
          hint: 'Enter 10-digit mobile number',
          showFloatingLabel: false,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: _buildPhonePrefix(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: Validators.validatePhone,
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setPhone(val);
          },
        ),

        const SizedBox(height: 18),

        // Substitute Email (Optional)
        _buildFieldLabel('Email Address (Optional)'),
        AppTextField(
          hint: 'e.g. name@company.com',
          showFloatingLabel: false,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined),
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setEmail(val);
          },
        ),

        const SizedBox(height: 18),

        // Name of the Member they are substituting for
        _buildFieldLabel('Substituting For (Member Name)', isRequired: true),
        InkWell(
          onTap: () {
            setState(() {
              _isSubstituteForDropdownOpen = !_isSubstituteForDropdownOpen;
              if (!_isSubstituteForDropdownOpen) {
                _substituteForSearchController.clear();
                _substituteForSearchQuery = '';
              }
            });
          },
          borderRadius: AppRadius.mdAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: _isSubstituteForDropdownOpen
                    ? AppColors.primary
                    : (_selectedSubstituteForMember != null
                        ? const Color(0xFF64748B)
                        : const Color(0xFFCBD5E1)),
                width: _isSubstituteForDropdownOpen ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: _isSubstituteForDropdownOpen ? AppColors.primary : const Color(0xFF64748B),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedSubstituteForMember ?? 'Select member you are substituting for',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _selectedSubstituteForMember != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedSubstituteForMember != null
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Icon(
                  _isSubstituteForDropdownOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),

        // Dropdown Panel for Substitute Member selection
        if (_isSubstituteForDropdownOpen) ...[
          const SizedBox(height: 8),
          _buildSearchableDropdownPanel(
            searchController: _substituteForSearchController,
            searchQuery: _substituteForSearchQuery,
            hintText: 'Search member to substitute...',
            onSearchChanged: (val) => setState(() => _substituteForSearchQuery = val.trim()),
            onClearSearch: () {
              _substituteForSearchController.clear();
              setState(() => _substituteForSearchQuery = '');
            },
            onSelectEmployee: (emp) {
              setState(() {
                _selectedSubstituteForMember = emp.name;
                _isSubstituteForDropdownOpen = false;
                _substituteForSearchController.clear();
                _substituteForSearchQuery = '';
              });
              final notifier = ref.read(checkInFormProvider.notifier);
              notifier.setSubstituteForMember(emp.name);
              notifier.setAdminId(emp.adminId ?? widget.adminId);
            },
          ),
        ],

        const SizedBox(height: 20),

        // Face Verification Photo Card
        _SubstitutePhotoCard(
          photoBase64: formState.photoBase64,
          onTakePhoto: _openCamera,
        ),
      ],
    );
  }

  // ==========================================
  // 3. VISITOR FORM FIELDS (Name + Phone + Email + Company + Category + Invited By Member)
  // ==========================================
  Widget _buildVisitorFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Visitor Full Name
        _buildFieldLabel('Visitor Full Name', isRequired: true),
        AppTextField(
          hint: 'Enter your full name',
          showFloatingLabel: false,
          controller: _nameController,
          prefixIcon: const Icon(Icons.person_rounded),
          textCapitalization: TextCapitalization.words,
          validator: Validators.validateName,
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setName(val);
          },
        ),

        const SizedBox(height: 18),

        // Visitor Phone Number (+91)
        _buildFieldLabel('Phone Number', isRequired: true),
        AppTextField(
          hint: 'Enter 10-digit mobile number',
          showFloatingLabel: false,
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          prefixIcon: _buildPhonePrefix(),
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          validator: Validators.validatePhone,
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setPhone(val);
          },
        ),

        const SizedBox(height: 18),

        // Visitor Email
        _buildFieldLabel('Email Address', isRequired: true),
        AppTextField(
          hint: 'Enter your email address',
          showFloatingLabel: false,
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: const Icon(Icons.email_outlined),
          validator: Validators.validateEmail,
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setEmail(val);
          },
        ),

        const SizedBox(height: 18),

        // Company Name
        _buildFieldLabel('Company Name', isRequired: true),
        AppTextField(
          hint: 'Enter company or business name',
          showFloatingLabel: false,
          controller: _companyController,
          prefixIcon: const Icon(Icons.business_rounded),
          validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter company name' : null,
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setCompanyName(val);
          },
        ),

        const SizedBox(height: 18),

        // Business Category
        _buildFieldLabel('Business Category / Industry', isRequired: true),
        AppTextField(
          hint: 'e.g. Real Estate, IT Services, Legal, Finance',
          showFloatingLabel: false,
          controller: _categoryController,
          prefixIcon: const Icon(Icons.category_rounded),
          validator: (val) {
            if (val == null || val.trim().isEmpty) {
              return 'Please enter business category';
            }
            if (val.trim().length < 4) {
              return 'Category must be at least 4 letters';
            }
            return null;
          },
          onChanged: (val) {
            setState(() {});
            ref.read(checkInFormProvider.notifier).setCategory(val);
          },
        ),

        const SizedBox(height: 18),

        // Invited By (Select Member)
        _buildFieldLabel('Invited By (Select Member)', isRequired: true),
        InkWell(
          onTap: () {
            setState(() {
              _isInvitedByDropdownOpen = !_isInvitedByDropdownOpen;
              if (!_isInvitedByDropdownOpen) {
                _invitedBySearchController.clear();
                _invitedBySearchQuery = '';
              }
            });
          },
          borderRadius: AppRadius.mdAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: _isInvitedByDropdownOpen
                    ? AppColors.primary
                    : (_selectedInvitedByMember != null
                        ? const Color(0xFF64748B)
                        : const Color(0xFFCBD5E1)),
                width: _isInvitedByDropdownOpen ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.person_add_alt_1_rounded,
                  color: _isInvitedByDropdownOpen ? AppColors.primary : const Color(0xFF64748B),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedInvitedByMember ?? 'Select member who invited you',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _selectedInvitedByMember != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: _selectedInvitedByMember != null
                          ? const Color(0xFF0F172A)
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ),
                Icon(
                  _isInvitedByDropdownOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: const Color(0xFF64748B),
                ),
              ],
            ),
          ),
        ),

        // Dropdown Panel for Invited By Member selection
        if (_isInvitedByDropdownOpen) ...[
          const SizedBox(height: 8),
          _buildSearchableDropdownPanel(
            searchController: _invitedBySearchController,
            searchQuery: _invitedBySearchQuery,
            hintText: 'Search inviting member...',
            onSearchChanged: (val) => setState(() => _invitedBySearchQuery = val.trim()),
            onClearSearch: () {
              _invitedBySearchController.clear();
              setState(() => _invitedBySearchQuery = '');
            },
            onSelectEmployee: (emp) {
              setState(() {
                _selectedInvitedByMember = emp.name;
                _isInvitedByDropdownOpen = false;
                _invitedBySearchController.clear();
                _invitedBySearchQuery = '';
              });
              final notifier = ref.read(checkInFormProvider.notifier);
              notifier.setInvitedByMember(emp.name);
              notifier.setAdminId(emp.adminId ?? widget.adminId);
            },
          ),
        ],
      ],
    );
  }

  // ==========================================
  // Helper: Searchable Dropdown Panel
  // ==========================================
  Widget _buildSearchableDropdownPanel({
    required TextEditingController searchController,
    required String searchQuery,
    required String hintText,
    required ValueChanged<String> onSearchChanged,
    required VoidCallback onClearSearch,
    required ValueChanged<Employee> onSelectEmployee,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.mdAll,
      elevation: 4,
      shadowColor: Colors.black.withAlpha(30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: const Color(0xFFCBD5E1),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Search Input Field
            Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: hintText,
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 20,
                  ),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: onClearSearch,
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  filled: true,
                  fillColor: const Color(0xFFF1F5F9),
                  border: const OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  enabledBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: AppRadius.smAll,
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                onChanged: onSearchChanged,
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // List of filtered employees
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: Consumer(
                builder: (context, ref, _) {
                  final employeesAsync = ref.watch(employeesStreamProvider);

                  return employeesAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Error loading names: $e',
                          style: const TextStyle(color: AppColors.error, fontSize: 12),
                        ),
                      ),
                    ),
                    data: (allEmployees) {
                      final scopedEmployees = EmployeeLookup.scoped(
                        employees: allEmployees,
                        adminId: widget.adminId,
                        activeOnly: true,
                      );

                      final filtered = searchQuery.isEmpty
                          ? scopedEmployees
                          : scopedEmployees
                              .where((emp) => emp.name
                                  .toLowerCase()
                                  .contains(searchQuery.toLowerCase()))
                              .toList();

                      if (filtered.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No matching members found',
                              style: TextStyle(color: Colors.grey, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount: filtered.length,
                        separatorBuilder: (context, index) =>
                            const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        itemBuilder: (context, index) {
                          final emp = filtered[index];
                          return ListTile(
                            dense: true,
                            leading: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha(25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.person_rounded,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              emp.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            subtitle: emp.phone.isNotEmpty
                                ? Text(
                                    emp.phone,
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  )
                                : null,
                            trailing: const Icon(
                              Icons.north_west_rounded,
                              size: 14,
                              color: Color(0xFF94A3B8),
                            ),
                            onTap: () => onSelectEmployee(emp),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 3-Option Segmented Check-In Type Selector (Member, Substitute, Visitor).
/// Consistent selected accent color (AppColors.primary) across all three options.
class _CheckInTypeSelector extends StatelessWidget {
  const _CheckInTypeSelector({
    required this.selectedType,
    required this.onChanged,
  });

  final CheckInType? selectedType;
  final ValueChanged<CheckInType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 1. Member Option
        Expanded(
          child: _buildTypeCard(
            type: CheckInType.member,
            title: 'Member',
            icon: Icons.person_rounded,
            isSelected: selectedType == CheckInType.member,
          ),
        ),

        const SizedBox(width: 8),

        // 2. Substitute Option
        Expanded(
          child: _buildTypeCard(
            type: CheckInType.substitute,
            title: 'Substitute',
            icon: Icons.swap_horiz_rounded,
            isSelected: selectedType == CheckInType.substitute,
          ),
        ),

        const SizedBox(width: 8),

        // 3. Visitor Option
        Expanded(
          child: _buildTypeCard(
            type: CheckInType.visitor,
            title: 'Visitor',
            icon: Icons.card_membership_rounded,
            isSelected: selectedType == CheckInType.visitor,
          ),
        ),
      ],
    );
  }

  Widget _buildTypeCard({
    required CheckInType type,
    required String title,
    required IconData icon,
    required bool isSelected,
  }) {
    const activeColor = AppColors.primary;
    const activeBgColor = Color(0xFFFEF2F2);

    return InkWell(
      onTap: () => onChanged(type),
      borderRadius: AppRadius.mdAll,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBgColor : Colors.white,
          borderRadius: AppRadius.mdAll,
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withAlpha(25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.check_circle_rounded : icon,
              size: 20,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF475569),
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Substitute photo verification card.
class _SubstitutePhotoCard extends StatelessWidget {
  const _SubstitutePhotoCard({
    required this.photoBase64,
    required this.onTakePhoto,
  });

  final String? photoBase64;
  final VoidCallback onTakePhoto;

  @override
  Widget build(BuildContext context) {
    final imageBytes = ImageUtils.base64ToBytes(photoBase64);

    return AppCard(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text.rich(
                    TextSpan(
                      text: 'Face Verification Photo',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF0F172A),
                      ),
                      children: [
                        TextSpan(
                          text: ' *',
                          style: TextStyle(
                            color: AppColors.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (imageBytes != null)
                TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Change'),
                  onPressed: onTakePhoto,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (imageBytes != null)
            Center(
              child: ClipRRect(
                borderRadius: AppRadius.mdAll,
                child: Image.memory(
                  imageBytes,
                  width: 140,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Center(
              child: Column(
                children: [
                  const Text(
                    'Substitutes must provide a live face photo for attendance verification.',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  AppButton.primary(
                    label: 'Take Face Photo',
                    icon: Icons.camera_alt_rounded,
                    fullWidth: false,
                    onPressed: onTakePhoto,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
