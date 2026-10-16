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
import '../providers/checkin_providers.dart';
import '../widgets/check_in_type_selector.dart';
import '../widgets/face_scanner_view.dart';
import '../widgets/recognized_member_card.dart';
import '../widgets/substitute_photo_card.dart';
import '../widgets/unrecognized_member_card.dart';
import 'checkin_result_screen.dart';

/// Check-in form: Member (manual), Substitute, Visitor, and Face Verification.
/// Face Verification submits as a Member after a successful match.
class CheckInFormScreen extends ConsumerStatefulWidget {
  const CheckInFormScreen({
    super.key,
    required this.locationId,
    this.initialLocation,
    this.proximityResult,
    this.adminId,
    this.sessionDateStr,
    this.sessionToken,
    this.nowProvider,
  });

  final String locationId;
  final LocationConfig? initialLocation;
  final ProximityResult? proximityResult;
  final String? adminId;
  final String? sessionDateStr;
  final String? sessionToken;
  final DateTime Function()? nowProvider;

  @override
  ConsumerState<CheckInFormScreen> createState() => _CheckInFormScreenState();
}

class _CheckInFormScreenState extends ConsumerState<CheckInFormScreen> {
  final _formKey = GlobalKey<FormState>();

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

  /// Calendar day used to attribute check-ins (QR session date, else today).
  /// Next Thursday's QR uses a new date, so the dropdown resets automatically.
  DateTime get _sessionDayForDropdown {
    final parsed = _parsedSessionDate;
    if (parsed != null) {
      return DateTime(parsed.year, parsed.month, parsed.day);
    }
    final n = _now;
    return DateTime(n.year, n.month, n.day);
  }

  /// yyyy-MM-dd for the public sessionAttendance projection (QR typeahead).
  String get _sessionDateYmdForAttendance {
    final raw = _effectiveSessionDateStr?.trim() ?? '';
    if (raw.length >= 10) return raw.substring(0, 10);
    final d = _sessionDayForDropdown;
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

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

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _companyController;
  late final TextEditingController _categoryController;

  /// Typeahead controllers for Substitute-for / Invited-by member pickers.
  late final TextEditingController _substituteForController;
  late final TextEditingController _invitedByController;

  final FocusNode _memberNameFocusNode = FocusNode();
  final FocusNode _substituteForFocusNode = FocusNode();
  final FocusNode _invitedByFocusNode = FocusNode();
  final ScrollController _formScrollController = ScrollController();
  final GlobalKey _memberNameFieldKey = GlobalKey();
  final GlobalKey _substituteForFieldKey = GlobalKey();
  final GlobalKey _invitedByFieldKey = GlobalKey();

  bool _showMemberSuggestions = false;
  bool _showSubstituteForSuggestions = false;
  bool _showInvitedBySuggestions = false;

  /// True while the user is interacting with a suggestions list so focus
  /// loss (common on mobile web scroll) does not dismiss the dropdown.
  bool _memberSuggestionsPointerActive = false;
  bool _substituteForPointerActive = false;
  bool _invitedByPointerActive = false;

  /// Last keyboard inset used to re-scroll when the soft keyboard animates.
  double _lastKeyboardInset = 0;

  String? _selectedSubstituteForMember;
  String? _selectedSubstituteForMemberId;
  String? _selectedInvitedByMember;

  bool _isCheckingDevice = true;
  bool _hasCheckedIn = false;
  CheckInSubmission? _existingSubmission;

  /// Member selected from the typeahead list (manual check-in only).
  Employee? _manuallySelectedMember;

  /// Active UI tab (Face Verification is separate from manual Member).
  CheckInFormTab _activeTab = CheckInFormTab.member;

  // Face Verification tab state
  Employee? _recognizedMember;
  double? _faceConfidence;
  bool _isUnrecognized = false;
  Uint8List? _unrecognizedPhotoBytes;
  Uint8List? _liveSelfieBytes;
  String? _unrecognizedMessage;
  int _faceScanGeneration = 0;
  int _punchGeneration = 0;
  bool _memberAutoSubmitFailed = false;
  bool _isMemberSubmitting = false;
  bool _showManualMemberPicker = false;

  bool get _anyMemberTypeaheadOpen =>
      _showMemberSuggestions ||
      _showSubstituteForSuggestions ||
      _showInvitedBySuggestions;

  void _clearLocalIdentity() {
    _manuallySelectedMember = null;
    _showMemberSuggestions = false;
    _recognizedMember = null;
    _faceConfidence = null;
    _isUnrecognized = false;
    _unrecognizedPhotoBytes = null;
    _unrecognizedMessage = null;
    _liveSelfieBytes = null;
    _showManualMemberPicker = false;
    _memberAutoSubmitFailed = false;
    _isMemberSubmitting = false;
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
  }

  void _onMemberNameFocusChanged() => _onTypeaheadFocusChanged(
    focusNode: _memberNameFocusNode,
    fieldKey: _memberNameFieldKey,
    isPointerActive: () => _memberSuggestionsPointerActive,
    setShowSuggestions: (v) => _showMemberSuggestions = v,
  );

  void _onSubstituteForFocusChanged() => _onTypeaheadFocusChanged(
    focusNode: _substituteForFocusNode,
    fieldKey: _substituteForFieldKey,
    isPointerActive: () => _substituteForPointerActive,
    setShowSuggestions: (v) => _showSubstituteForSuggestions = v,
  );

  void _onInvitedByFocusChanged() => _onTypeaheadFocusChanged(
    focusNode: _invitedByFocusNode,
    fieldKey: _invitedByFieldKey,
    isPointerActive: () => _invitedByPointerActive,
    setShowSuggestions: (v) => _showInvitedBySuggestions = v,
  );

  void _onTypeaheadFocusChanged({
    required FocusNode focusNode,
    required GlobalKey fieldKey,
    required bool Function() isPointerActive,
    required void Function(bool) setShowSuggestions,
  }) {
    if (focusNode.hasFocus) {
      setState(() => setShowSuggestions(true));
      _scrollTypeaheadIntoView(fieldKey);
      return;
    }
    // Soft keyboard "Done" unfocuses the field on mobile web. Keep the
    // suggestions list open so the user can still tap a name. Close only via
    // TapRegion outside, chevron, clear, or selection.
    Future<void>.delayed(const Duration(milliseconds: 220), () {
      if (!mounted || focusNode.hasFocus) return;
      if (isPointerActive()) return;
      // Do not call setShowSuggestions(false) here.
    });
  }

  GlobalKey? get _activeTypeaheadFieldKey {
    if (_showMemberSuggestions) return _memberNameFieldKey;
    if (_showSubstituteForSuggestions) return _substituteForFieldKey;
    if (_showInvitedBySuggestions) return _invitedByFieldKey;
    return null;
  }

  /// True when the field sits low in the viewport above the keyboard — show
  /// the suggestions panel above the input so it is not covered.
  bool _shouldShowSuggestionsAbove(GlobalKey fieldKey) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboardInset <= 0) return false;
    final ctx = fieldKey.currentContext;
    if (ctx == null) return false;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return false;
    final fieldTop = box.localToGlobal(Offset.zero).dy;
    final visibleHeight = MediaQuery.sizeOf(context).height - keyboardInset;
    return fieldTop > visibleHeight * 0.38;
  }

  /// Runs form validation after the current frame (typeahead select/clear).
  void _validateFormNextFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _formKey.currentState?.validate();
    });
  }

  void _closeTypeahead({
    required FocusNode focusNode,
    required void Function(bool) setShowSuggestions,
    required void Function(bool) setPointerActive,
    required bool showSuggestions,
  }) {
    setPointerActive(false);
    if (!showSuggestions && !focusNode.hasFocus) return;
    setState(() => setShowSuggestions(false));
    focusNode.unfocus();
  }

  void _closeMemberSuggestions() => _closeTypeahead(
    focusNode: _memberNameFocusNode,
    setShowSuggestions: (v) => _showMemberSuggestions = v,
    setPointerActive: (v) => _memberSuggestionsPointerActive = v,
    showSuggestions: _showMemberSuggestions,
  );

  void _closeSubstituteForSuggestions() => _closeTypeahead(
    focusNode: _substituteForFocusNode,
    setShowSuggestions: (v) => _showSubstituteForSuggestions = v,
    setPointerActive: (v) => _substituteForPointerActive = v,
    showSuggestions: _showSubstituteForSuggestions,
  );

  void _closeInvitedBySuggestions() => _closeTypeahead(
    focusNode: _invitedByFocusNode,
    setShowSuggestions: (v) => _showInvitedBySuggestions = v,
    setPointerActive: (v) => _invitedByPointerActive = v,
    showSuggestions: _showInvitedBySuggestions,
  );

  void _scrollTypeaheadIntoView(GlobalKey fieldKey) {
    void ensure({required double alignment}) {
      if (!mounted) return;
      final ctx = fieldKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          alignment: alignment,
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
    }

    // First pass after focus; second pass after suggestions panel lays out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final showAbove = _shouldShowSuggestionsAbove(fieldKey);
      ensure(alignment: showAbove ? 0.72 : 0.08);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ensure(alignment: _shouldShowSuggestionsAbove(fieldKey) ? 0.72 : 0.08);
      });
    });
  }

  @override
  void initState() {
    super.initState();
    // Warm up employee / member list in memory so dropdown opens instantly
    ref.read(publicMembersStreamProvider);

    // Always start this QR scan with empty identity fields so the previous
    // member on a shared device cannot leak into the next check-in.
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _companyController = TextEditingController();
    _categoryController = TextEditingController();

    _substituteForController = TextEditingController();
    _invitedByController = TextEditingController();
    _memberNameFocusNode.addListener(_onMemberNameFocusChanged);
    _substituteForFocusNode.addListener(_onSubstituteForFocusChanged);
    _invitedByFocusNode.addListener(_onInvitedByFocusChanged);

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
    if (formState.isSubmitting || _isMemberSubmitting) return false;
    final type = formState.type;
    if (type == null) return false;

    switch (type) {
      case CheckInType.member:
        if (_activeTab == CheckInFormTab.faceVerification) {
          return _recognizedMember != null || _manuallySelectedMember != null;
        }
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
    // Venue phones/tablets are shared: do not block the form because another
    // member already checked in on this browser. Per-member / per-phone
    // uniqueness is enforced on submit.
    if (!mounted) return;
    setState(() {
      _hasCheckedIn = false;
      _existingSubmission = null;
      _isCheckingDevice = false;
    });
  }

  @override
  void dispose() {
    _memberNameFocusNode.removeListener(_onMemberNameFocusChanged);
    _substituteForFocusNode.removeListener(_onSubstituteForFocusChanged);
    _invitedByFocusNode.removeListener(_onInvitedByFocusChanged);
    _memberNameFocusNode.dispose();
    _substituteForFocusNode.dispose();
    _invitedByFocusNode.dispose();
    _formScrollController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    _categoryController.dispose();
    _substituteForController.dispose();
    _invitedByController.dispose();
    super.dispose();
  }

  void _onTabChanged(CheckInFormTab newTab) {
    // 1. Clear all local text controllers
    _nameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _companyController.clear();
    _categoryController.clear();
    _substituteForController.clear();
    _invitedByController.clear();
    _memberNameFocusNode.unfocus();
    _substituteForFocusNode.unfocus();
    _invitedByFocusNode.unfocus();

    // 2. Clear state variables
    setState(() {
      _activeTab = newTab;
      _selectedSubstituteForMember = null;
      _selectedSubstituteForMemberId = null;
      _selectedInvitedByMember = null;
      _showMemberSuggestions = false;
      _showSubstituteForSuggestions = false;
      _showInvitedBySuggestions = false;
      _clearLocalIdentity();
      _punchGeneration++;
      _faceScanGeneration++;
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
    notifier.setType(newTab.checkInType);
    if (widget.adminId != null && widget.adminId!.isNotEmpty) {
      notifier.setAdminId(widget.adminId);
    }
  }

  LocationConfig get _effectiveLocation {
    const defaultLocation = LocationConfig(
      id: 'location_x',
      name: 'Jade Luxury Banquets, Mumbai',
      latitude: 18.9888622,
      longitude: 72.8152475,
      radiusMeters: 500.0,
      isActive: true,
      address:
          'Jade Luxury Banquets, Nehru Centre, Dr Annie Besant Rd, Worli, Mumbai, Maharashtra 400018',
    );
    if (widget.initialLocation != null) return widget.initialLocation!;
    final loaded = ref
        .read(locationConfigFamilyProvider(widget.locationId))
        .asData
        ?.value;
    return loaded ?? defaultLocation;
  }

  ProximityResult get _effectiveProximity {
    if (widget.proximityResult != null) return widget.proximityResult!;
    final location = _effectiveLocation;
    return ProximityResult(
      distanceMeters: 10.0,
      isWithinRadius: true,
      allowedRadiusMeters: location.radiusMeters,
      userLatitude: location.latitude,
      userLongitude: location.longitude,
      gpsAccuracy: 5.0,
    );
  }

  void _markMemberAutoSubmitFailed() {
    if (_memberAutoSubmitFailed && !_isMemberSubmitting) return;
    setState(() {
      _memberAutoSubmitFailed = true;
      _isMemberSubmitting = false;
    });
  }

  Future<void> _applyRecognizedMember(
    Employee member,
    double confidence,
    Uint8List selfieBytes,
  ) async {
    final live = await _authoritativeMember(member);
    if (!mounted) return;
    setState(() {
      _isUnrecognized = false;
      _unrecognizedPhotoBytes = null;
      _liveSelfieBytes = selfieBytes;
      _recognizedMember = live;
      _faceConfidence = confidence;
      _nameController.text = live.name;
      _phoneController.text = live.phone;
      _emailController.text = live.email;
    });
    final notifier = ref.read(checkInFormProvider.notifier);
    notifier.clearIdentity();
    notifier.setType(CheckInType.member);
    notifier.setName(live.name);
    notifier.setPhone(live.phone);
    notifier.setEmail(live.email);
    notifier.setRecognizedMember(live.id);
    notifier.setAdminId(live.adminId ?? widget.adminId);
    notifier.setPhotoBase64(ImageUtils.bytesToBase64(selfieBytes));
  }

  Future<void> _onMemberFaceVerified(
    Employee member,
    double confidence,
    Uint8List selfieBytes,
  ) async {
    await _applyRecognizedMember(member, confidence, selfieBytes);
    final generation = ++_punchGeneration;
    setState(() {
      _memberAutoSubmitFailed = false;
      _isMemberSubmitting = true;
    });
    await _onSubmit(_effectiveLocation, _effectiveProximity);
    if (!mounted || generation != _punchGeneration) return;
    final submitted = ref.read(checkInFormProvider).submissionResult != null;
    if (!submitted) {
      _markMemberAutoSubmitFailed();
    }
  }

  void _goToCheckInResult(CheckInSubmission? submission) {
    if (!mounted) return;
    // Never open Approved without a real submission (avoids empty Present gap).
    if (submission == null) return;
    context.go(
      RouteNames.checkinResultPath(
        checkInId: submission.id,
        memberId: submission.memberId,
      ),
      extra: submission,
    );
  }

  Future<Employee> _authoritativeMember(Employee selected) async {
    final employees =
        ref.read(publicMembersStreamProvider).asData?.value ??
        const <Employee>[];
    return EmployeeLookup.byId(employees, selected.id) ?? selected;
  }

  void _openCamera() {
    context.push(RouteNames.photoCapturePath());
  }

  Future<void> _onSubmit(
    LocationConfig location,
    ProximityResult proximity,
  ) async {
    final formState = ref.read(checkInFormProvider);
    // Ignore second taps while submitting / before async device probes (H4).
    if (formState.isSubmitting) return;

    // Do not short-circuit on device-local / shared-tablet history. Venue
    // devices are shared; phone + member locks on the server decide duplicates.

    var currentType = formState.type;
    if (currentType == null && _recognizedMember != null) {
      currentType = CheckInType.member;
      ref.read(checkInFormProvider.notifier).setType(CheckInType.member);
    }
    if (currentType == null) {
      return;
    }

    final skipFormValidate =
        _activeTab == CheckInFormTab.faceVerification &&
        _recognizedMember != null;
    if (!skipFormValidate && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    // Type-specific validations
    if (currentType == CheckInType.member) {
      final hasManualMember = _manuallySelectedMember != null;
      if (_activeTab == CheckInFormTab.faceVerification) {
        if (_isUnrecognized && !hasManualMember) {
          _markMemberAutoSubmitFailed();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _unrecognizedMessage ??
                    'Face not recognized. Please try again.',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
        if (_recognizedMember == null && !hasManualMember) {
          _markMemberAutoSubmitFailed();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please look into the camera to verify your face before checking in.',
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }
      } else if (!hasManualMember) {
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
      if (_selectedSubstituteForMember == null ||
          _selectedSubstituteForMember!.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please select which Member you are substituting for.',
            ),
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
      if (_selectedInvitedByMember == null ||
          _selectedInvitedByMember!.trim().isEmpty) {
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
    // from face match or the selected member dropdown.
    // Substitute / visitor: name + phone MUST come from the text fields the
    // user typed (never from the covered member roster).
    final notifier = ref.read(checkInFormProvider.notifier);
    notifier.setType(currentType);
    final selectedMember = currentType == CheckInType.member
        ? (_manuallySelectedMember ?? _recognizedMember)
        : null;
    if (currentType == CheckInType.substitute ||
        currentType == CheckInType.visitor) {
      notifier.setName(_nameController.text.trim());
      notifier.setPhone(_phoneController.text.trim());
      notifier.setEmail(_emailController.text.trim());
      notifier.setRecognizedMember(null);
    } else if (selectedMember != null &&
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
    notifier.setSubstituteForMember(
      _selectedSubstituteForMember,
      memberId: _selectedSubstituteForMemberId,
    );
    notifier.setInvitedByMember(_selectedInvitedByMember);

    final success = await notifier.submit(
      location: location,
      proximityResult: proximity,
      sessionDateStr: _effectiveSessionDateStr,
      sessionToken: widget.sessionToken,
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
            ref
                .read(deviceCheckInServiceProvider)
                .recordSubmission(
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
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  SizedBox(width: 10),
                  Text(
                    'Already Responded',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: const Text(
                'You have already submitted your attendance for this date.\n\nOnly one check-in is allowed per member (or phone) each Thursday.',
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
        if (!config.dateRestrictionEnabled) {
          _applyDeviceGate(restrictionsEnabled: false);
        } else if (_isCheckingDevice) {
          _applyDeviceGate(restrictionsEnabled: true);
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

    if (_isCheckingDevice && configAsync.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_isCheckingDevice) return;
        _applyDeviceGate(restrictionsEnabled: dateRestrictionEnabled);
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

    if (dateRestrictionEnabled && !_isTodayThursday) {
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
                    style: TextStyle(color: Color(0xFF64748B), height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // When date restriction OFF: past / future QR dates are accepted.
    if (dateRestrictionEnabled && _isSessionExpired) {
      final formattedSessionDate = DateFormat('EEEE, dd MMMM yyyy')
          .format(_parsedSessionDate!);
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

    if (dateRestrictionEnabled && _isSessionFuture) {
      final formattedSessionDate = DateFormat('EEEE, dd MMMM yyyy')
          .format(_parsedSessionDate!);
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
    final formState = ref.watch(checkInFormProvider);
    final locationAsync = ref.watch(
      locationConfigFamilyProvider(widget.locationId),
    );
    final employeesAsync = ref.watch(employeesStreamProvider);
    final faceCandidatesAsync = ref.watch(faceVerificationCandidatesProvider);
    final isCompact = context.isCompactMobile;
    final currentType = formState.type;
    final scopedEmployees = EmployeeLookup.scoped(
      employees: employeesAsync.asData?.value ?? const <Employee>[],
      adminId: widget.adminId,
      activeOnly: true,
    );
    final faceCandidates = EmployeeLookup.scoped(
      employees: faceCandidatesAsync.asData?.value ?? const <Employee>[],
      adminId: widget.adminId,
      activeOnly: true,
    );
    final liveRecognized = _recognizedMember == null
        ? null
        : EmployeeLookup.byId(faceCandidates, _recognizedMember!.id) ??
              EmployeeLookup.byId(scopedEmployees, _recognizedMember!.id) ??
              _recognizedMember;

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
    final location =
        widget.initialLocation ??
        locationAsync.asData?.value ??
        defaultLocation;

    final proximity =
        widget.proximityResult ??
        ProximityResult(
          distanceMeters: 10.0,
          isWithinRadius: true,
          allowedRadiusMeters: location.radiusMeters,
          userLatitude: location.latitude,
          userLongitude: location.longitude,
          gpsAccuracy: 5.0,
        );
    final canSubmit = _canSubmit(formState);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    if (_anyMemberTypeaheadOpen && keyboardInset != _lastKeyboardInset) {
      _lastKeyboardInset = keyboardInset;
      final activeKey = _activeTypeaheadFieldKey;
      if (activeKey != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _anyMemberTypeaheadOpen) {
            _scrollTypeaheadIntoView(activeKey);
          }
        });
      }
    } else if (!_anyMemberTypeaheadOpen) {
      _lastKeyboardInset = keyboardInset;
    }

    return AppScaffold(
      title: AppStrings.checkInFormTitle,
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Scrollable Form Content (Top-aligned, identical padding across all 3 states)
          Expanded(
            child: SingleChildScrollView(
              controller: _formScrollController,
              // Keep the keyboard (and suggestions) open while scrolling
              // the member list on mobile web.
              keyboardDismissBehavior: _anyMemberTypeaheadOpen
                  ? ScrollViewKeyboardDismissBehavior.manual
                  : ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                hPadding,
                isCompact ? 16 : 24,
                hPadding,
                // Extra space so lower typeaheads (Substitute / Visitor)
                // can scroll the field + suggestions above the keyboard.
                (isCompact ? 16 : 24) +
                    keyboardInset +
                    (_anyMemberTypeaheadOpen ? 320 : 0),
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: ResponsiveBreakpoints.maxFormWidth,
                  ),
                  child: Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Top Check-in Type Selector
                        const Text(
                          'Check-In Type',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 10),
                        CheckInTypeSelector(
                          selectedTab: _activeTab,
                          onChanged: _onTabChanged,
                        ),
                        const SizedBox(height: 20),

                        // 3. Dynamic Form Fields based on Tab
                        if (_activeTab == CheckInFormTab.member) ...[
                          _buildMemberFormFields(),
                        ] else if (_activeTab ==
                            CheckInFormTab.faceVerification) ...[
                          _buildFaceVerificationSection(
                            scopedEmployees: faceCandidates,
                            liveRecognized: liveRecognized,
                          ),
                        ] else if (_activeTab == CheckInFormTab.substitute) ...[
                          _buildSubstituteFormFields(formState),
                        ] else if (_activeTab == CheckInFormTab.visitor) ...[
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
                                    ErrorHandler.getUserMessage(
                                      formState.error!,
                                    ),
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

          // 4. Sticky Submit — hide on live face scan (auto-submits) and while
          // typeahead suggestions are open on mobile web.
          if (currentType != null &&
              !_anyMemberTypeaheadOpen &&
              (_activeTab != CheckInFormTab.faceVerification ||
                  _memberAutoSubmitFailed ||
                  _manuallySelectedMember != null ||
                  _isUnrecognized)) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: hPadding, vertical: 14),
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
  Widget _buildFieldLabel(
    String title, {
    bool isRequired = false,
    String? suffix,
  }) {
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
          Container(height: 16, width: 1, color: const Color(0xFFCBD5E1)),
        ],
      ),
    );
  }

  // ==========================================
  // Shared member typeahead (Member / Substitute-for / Invited-by)
  // ==========================================
  Widget _buildMemberTypeaheadField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required FocusNode focusNode,
    required GlobalKey fieldKey,
    required bool showSuggestions,
    required VoidCallback onCloseSuggestions,
    required void Function(bool show) setShowSuggestions,
    required void Function(bool active) setPointerActive,
    required bool hasValidSelection,
    required bool excludeSessionCheckedIn,
    required ValueChanged<Employee> onSelectEmployee,
    required VoidCallback onClearSelection,
    required ValueChanged<String> onQueryChanged,
    IconData prefixIcon = Icons.person_outline_rounded,
  }) {
    final query = controller.text.trim();
    final hasQuery = query.isNotEmpty;
    final showAbove = showSuggestions && _shouldShowSuggestionsAbove(fieldKey);

    final suggestionsPanel = _buildMemberSuggestionsPanel(
      query: query,
      excludeSessionCheckedIn: excludeSessionCheckedIn,
      setPointerActive: setPointerActive,
      onSelectEmployee: onSelectEmployee,
    );

    return TapRegion(
      onTapOutside: (_) {
        if (showSuggestions) onCloseSuggestions();
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildFieldLabel(label, isRequired: true),
          if (showSuggestions && showAbove) ...[
            suggestionsPanel,
            const SizedBox(height: 8),
          ],
          KeyedSubtree(
            key: fieldKey,
            child: AppTextField(
              hint: hint,
              showFloatingLabel: false,
              controller: controller,
              focusNode: focusNode,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.search,
              prefixIcon: Icon(prefixIcon),
              suffixIcon: hasQuery
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 22),
                      tooltip: 'Clear',
                      onPressed: () {
                        controller.clear();
                        onClearSelection();
                        setState(() => setShowSuggestions(true));
                        focusNode.requestFocus();
                        _scrollTypeaheadIntoView(fieldKey);
                      },
                    )
                  : IconButton(
                      icon: Icon(
                        showSuggestions
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.arrow_drop_down_rounded,
                        size: 28,
                        color: showSuggestions
                            ? AppColors.primary
                            : const Color(0xFF64748B),
                      ),
                      tooltip: showSuggestions ? 'Hide list' : 'Show members',
                      onPressed: () {
                        if (showSuggestions) {
                          onCloseSuggestions();
                        } else {
                          focusNode.requestFocus();
                          setState(() => setShowSuggestions(true));
                          _scrollTypeaheadIntoView(fieldKey);
                        }
                      },
                    ),
              onChanged: (val) {
                setState(() => setShowSuggestions(true));
                onQueryChanged(val);
                _scrollTypeaheadIntoView(fieldKey);
              },
              autovalidateMode: AutovalidateMode.onUserInteraction,
              validator: (val) {
                if (hasValidSelection) return null;
                if (showSuggestions) return null;
                final typed = (val ?? '').trim();
                if (typed.isEmpty) {
                  return 'Please select a name from the member list';
                }
                return 'Please select a valid name from the list';
              },
            ),
          ),
          if (showSuggestions && !showAbove) ...[
            const SizedBox(height: 8),
            suggestionsPanel,
          ],
        ],
      ),
    );
  }

  Widget _buildMemberSuggestionsPanel({
    required String query,
    required bool excludeSessionCheckedIn,
    required void Function(bool active) setPointerActive,
    required ValueChanged<Employee> onSelectEmployee,
  }) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableAboveKeyboard = keyboardInset > 0
        ? (screenHeight - keyboardInset) * 0.42
        : 280.0;
    // Cap lower when keyboard is open so the panel fits on short phones.
    final maxHeight = keyboardInset > 0
        ? availableAboveKeyboard.clamp(120.0, 220.0)
        : availableAboveKeyboard.clamp(160.0, 280.0);

    return Listener(
      onPointerDown: (_) => setPointerActive(true),
      onPointerUp: (_) {
        Future<void>.delayed(const Duration(milliseconds: 250), () {
          if (mounted) setPointerActive(false);
        });
      },
      onPointerCancel: (_) => setPointerActive(false),
      child: Material(
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
                final employeesAsync = ref.watch(publicMembersStreamProvider);
                final checkedInAsync = excludeSessionCheckedIn
                    ? ref.watch(
                        sessionCheckedInMemberIdsProvider(
                          _sessionDateYmdForAttendance,
                        ),
                      )
                    : null;

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
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  data: (allEmployees) {
                    final scopedEmployees = EmployeeLookup.scoped(
                      employees: allEmployees,
                      adminId: widget.adminId,
                      activeOnly: true,
                    );
                    final checkedInIds = excludeSessionCheckedIn
                        ? (checkedInAsync?.value ?? const <String>{})
                        : const <String>{};
                    final availableEmployees = scopedEmployees
                        .where((emp) => !checkedInIds.contains(emp.id))
                        .toList();

                    final q = query.toLowerCase();
                    final filtered = q.isEmpty
                        ? availableEmployees
                        : availableEmployees.where((emp) {
                            final name = emp.name.toLowerCase();
                            final phone = emp.phone.toLowerCase();
                            return name.contains(q) || phone.contains(q);
                          }).toList();

                    if (filtered.isEmpty) {
                      final emptyMessage =
                          excludeSessionCheckedIn && availableEmployees.isEmpty
                          ? 'All members have already checked in for this session'
                          : 'No matching members found';
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            emptyMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    }

                    return NotificationListener<ScrollNotification>(
                      onNotification: (_) => true,
                      child: ListView.separated(
                        primary: false,
                        shrinkWrap: true,
                        physics: const AlwaysScrollableScrollPhysics(),
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
                            onTap: () => onSelectEmployee(emp),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // FACE VERIFICATION TAB
  // ==========================================
  Widget _buildFaceVerificationSection({
    required List<Employee> scopedEmployees,
    required Employee? liveRecognized,
  }) {
    if (liveRecognized != null && _memberAutoSubmitFailed) {
      return RecognizedMemberCard(
        member: liveRecognized,
        confidence: _faceConfidence ?? 98.0,
        capturedPhotoBytes: _liveSelfieBytes,
        onRescan: () {
          setState(() {
            _clearLocalIdentity();
            _faceScanGeneration++;
          });
          final notifier = ref.read(checkInFormProvider.notifier);
          notifier.clearIdentity();
          notifier.setType(CheckInType.member);
          if (widget.adminId != null && widget.adminId!.isNotEmpty) {
            notifier.setAdminId(widget.adminId);
          }
        },
      );
    }

    if (_isUnrecognized) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          UnrecognizedMemberCard(
            capturedPhotoBytes: _unrecognizedPhotoBytes,
            message: _unrecognizedMessage,
            onRetake: () {
              setState(() {
                _isUnrecognized = false;
                _unrecognizedPhotoBytes = null;
                _unrecognizedMessage = null;
                _showManualMemberPicker = false;
                _manuallySelectedMember = null;
                _faceScanGeneration++;
              });
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showManualMemberPicker = true;
                });
              },
              icon: const Icon(Icons.search_rounded, size: 18),
              label: const Text(
                'Choose Member Manually',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                elevation: 0,
                shape: const RoundedRectangleBorder(
                  borderRadius: AppRadius.smAll,
                ),
              ),
            ),
          ),
          if (_showManualMemberPicker) ...[
            const SizedBox(height: 16),
            _buildMemberFormFields(),
          ],
        ],
      );
    }

    return FaceScannerView(
      key: ValueKey('face-scan-$_faceScanGeneration'),
      candidates: scopedEmployees,
      adminId: widget.adminId,
      locationId: widget.locationId,
      onFaceRecognized: _onMemberFaceVerified,
      onFaceNotRecognized: (bytes, error) {
        setState(() {
          _recognizedMember = null;
          _faceConfidence = null;
          _isUnrecognized = true;
          _unrecognizedPhotoBytes = bytes;
          _unrecognizedMessage =
              error ?? 'Face not recognized. Please try again.';
          _liveSelfieBytes = bytes;
          _nameController.clear();
          _phoneController.clear();
          _emailController.clear();
        });
        ref.read(checkInFormProvider.notifier).clearIdentity();
        ref.read(checkInFormProvider.notifier).setType(CheckInType.member);
        if (widget.adminId != null && widget.adminId!.isNotEmpty) {
          ref.read(checkInFormProvider.notifier).setAdminId(widget.adminId);
        }
      },
      onSwitchToManual: () {
        setState(() => _activeTab = CheckInFormTab.member);
        ref.read(checkInFormProvider.notifier).setType(CheckInType.member);
      },
    );
  }

  // ==========================================
  // 1. MEMBER FORM FIELDS (typeahead name + autofill phone)
  // ==========================================
  Widget _buildMemberFormFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildMemberTypeaheadField(
          label: 'Select Member Name',
          hint: 'Type to search your name',
          controller: _nameController,
          focusNode: _memberNameFocusNode,
          fieldKey: _memberNameFieldKey,
          showSuggestions: _showMemberSuggestions,
          onCloseSuggestions: _closeMemberSuggestions,
          setShowSuggestions: (v) => _showMemberSuggestions = v,
          setPointerActive: (v) => _memberSuggestionsPointerActive = v,
          hasValidSelection: _manuallySelectedMember != null,
          excludeSessionCheckedIn: true,
          onClearSelection: () {
            _phoneController.clear();
            _emailController.clear();
            final notifier = ref.read(checkInFormProvider.notifier);
            notifier.clearIdentity();
            if (widget.adminId != null && widget.adminId!.isNotEmpty) {
              notifier.setAdminId(widget.adminId);
            }
            setState(() => _manuallySelectedMember = null);
            _validateFormNextFrame();
          },
          onQueryChanged: (val) {
            final selected = _manuallySelectedMember;
            final stillMatches =
                selected != null &&
                selected.name.trim().toLowerCase() == val.trim().toLowerCase();
            if (!stillMatches) {
              _phoneController.clear();
              _emailController.clear();
              final notifier = ref.read(checkInFormProvider.notifier);
              notifier.setName(val);
              notifier.setPhone('');
              notifier.setEmail('');
              notifier.setRecognizedMember(null);
              setState(() => _manuallySelectedMember = null);
              _validateFormNextFrame();
            }
          },
          onSelectEmployee: (emp) {
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
            _validateFormNextFrame();
          },
        ),
        const SizedBox(height: 18),
        _buildFieldLabel(
          'Phone Number',
          isRequired: true,
          suffix: ' (Auto-filled)',
        ),
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
          validator: (val) {
            // For Member check-in, phone number is auto-filled upon member selection.
            // When no member is selected yet, the member selection field prompts the user.
            if (_manuallySelectedMember == null) {
              return null;
            }
            return Validators.validatePhone(val);
          },
        ),
      ],
    );
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

        _buildMemberTypeaheadField(
          label: 'Substituting For (Member Name)',
          hint: 'Type to search member name',
          controller: _substituteForController,
          focusNode: _substituteForFocusNode,
          fieldKey: _substituteForFieldKey,
          showSuggestions: _showSubstituteForSuggestions,
          onCloseSuggestions: _closeSubstituteForSuggestions,
          setShowSuggestions: (v) => _showSubstituteForSuggestions = v,
          setPointerActive: (v) => _substituteForPointerActive = v,
          hasValidSelection:
              _selectedSubstituteForMember?.trim().isNotEmpty ?? false,
          excludeSessionCheckedIn: true,
          prefixIcon: Icons.swap_horiz_rounded,
          onClearSelection: () {
            setState(() {
              _selectedSubstituteForMember = null;
              _selectedSubstituteForMemberId = null;
            });
            ref.read(checkInFormProvider.notifier).setSubstituteForMember(null);
            _validateFormNextFrame();
          },
          onQueryChanged: (val) {
            final selected = _selectedSubstituteForMember;
            final stillMatches =
                selected != null &&
                selected.trim().toLowerCase() == val.trim().toLowerCase();
            if (!stillMatches) {
              setState(() {
                _selectedSubstituteForMember = null;
                _selectedSubstituteForMemberId = null;
              });
              ref
                  .read(checkInFormProvider.notifier)
                  .setSubstituteForMember(null);
              _validateFormNextFrame();
            }
          },
          onSelectEmployee: (emp) {
            _substituteForController.text = emp.name;
            setState(() {
              _selectedSubstituteForMember = emp.name;
              _selectedSubstituteForMemberId = emp.id;
              _showSubstituteForSuggestions = false;
            });
            final notifier = ref.read(checkInFormProvider.notifier);
            notifier.setSubstituteForMember(emp.name, memberId: emp.id);
            notifier.setAdminId(emp.adminId ?? widget.adminId);
            _substituteForFocusNode.unfocus();
            _validateFormNextFrame();
          },
        ),

        const SizedBox(height: 20),

        // Face Verification Photo Card
        SubstitutePhotoCard(
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
          validator: (val) => (val == null || val.trim().isEmpty)
              ? 'Please enter company name'
              : null,
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

        _buildMemberTypeaheadField(
          label: 'Invited By (Select Member)',
          hint: 'Type to search inviting member',
          controller: _invitedByController,
          focusNode: _invitedByFocusNode,
          fieldKey: _invitedByFieldKey,
          showSuggestions: _showInvitedBySuggestions,
          onCloseSuggestions: _closeInvitedBySuggestions,
          setShowSuggestions: (v) => _showInvitedBySuggestions = v,
          setPointerActive: (v) => _invitedByPointerActive = v,
          hasValidSelection:
              _selectedInvitedByMember?.trim().isNotEmpty ?? false,
          excludeSessionCheckedIn: false,
          prefixIcon: Icons.person_add_alt_1_rounded,
          onClearSelection: () {
            setState(() => _selectedInvitedByMember = null);
            ref.read(checkInFormProvider.notifier).setInvitedByMember(null);
            _validateFormNextFrame();
          },
          onQueryChanged: (val) {
            final selected = _selectedInvitedByMember;
            final stillMatches =
                selected != null &&
                selected.trim().toLowerCase() == val.trim().toLowerCase();
            if (!stillMatches) {
              setState(() => _selectedInvitedByMember = null);
              ref.read(checkInFormProvider.notifier).setInvitedByMember(null);
              _validateFormNextFrame();
            }
          },
          onSelectEmployee: (emp) {
            _invitedByController.text = emp.name;
            setState(() {
              _selectedInvitedByMember = emp.name;
              _showInvitedBySuggestions = false;
            });
            final notifier = ref.read(checkInFormProvider.notifier);
            notifier.setInvitedByMember(emp.name);
            notifier.setAdminId(emp.adminId ?? widget.adminId);
            _invitedByFocusNode.unfocus();
            _validateFormNextFrame();
          },
        ),
      ],
    );
  }
}
